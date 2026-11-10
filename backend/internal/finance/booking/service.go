// Package booking creates bookings for the platform's INTERNAL inventory. The server computes every amount:
// unit prices come from inventory_availability, discounts from the discounts/coupons tables, and the immutable
// price snapshot is what the customer is charged and what refunds/commission later refer to.
package booking

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/base32"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/travel-super-app/backend/internal/finance/faudit"
	"github.com/travel-super-app/backend/internal/finance/money"
)

const HoldMinutes = 15

var (
	ErrUnavailable = errors.New("not enough availability")
	ErrCoupon      = errors.New("coupon is not valid for this booking")
)

type ValidationError struct{ Msg string }

func (e ValidationError) Error() string { return e.Msg }

type ItemInput struct {
	InventoryItemID string `json:"inventory_item_id"`
	ServiceDate     string `json:"service_date"`
	Quantity        int    `json:"quantity"`
}

type Input struct {
	UserID, IdempotencyKey, CouponCode, RequestID, IP string
	Items                                             []ItemInput
}

type Result struct {
	ID, Code, Status, Currency string
	PayableTotal               money.Amount
	BaseTotal, DiscountTotal   money.Amount
	ExpiresAt                  time.Time
	Replayed                   bool
}

type Service struct {
	db  *sql.DB
	now func() time.Time
}

func NewService(db *sql.DB) *Service { return &Service{db: db, now: time.Now} }

func code() string {
	b := make([]byte, 7)
	_, _ = rand.Read(b)
	return "SB" + base32.StdEncoding.WithPadding(base32.NoPadding).EncodeToString(b)[:10]
}

func (s *Service) Create(ctx context.Context, in Input) (Result, error) {
	if in.IdempotencyKey == "" || len(in.IdempotencyKey) > 100 {
		return Result{}, ValidationError{"Idempotency-Key header is required (max 100 characters)"}
	}
	if len(in.Items) == 0 || len(in.Items) > 20 {
		return Result{}, ValidationError{"items must contain 1 to 20 entries"}
	}
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Result{}, err
	}
	defer tx.Rollback()

	// Idempotent replay: same key from the same user returns the original booking and creates nothing.
	var prev Result
	var payable string
	err = tx.QueryRowContext(ctx, "SELECT id, booking_code, status, currency_code, total_amount, expires_at FROM bookings WHERE user_id = ? AND idempotency_key = ?", in.UserID, in.IdempotencyKey).
		Scan(&prev.ID, &prev.Code, &prev.Status, &prev.Currency, &payable, &prev.ExpiresAt)
	if err == nil {
		prev.PayableTotal, _ = money.Parse(payable)
		prev.Replayed = true
		return prev, nil
	} else if err != sql.ErrNoRows {
		return Result{}, err
	}

	now := s.now().UTC()
	expires := now.Add(HoldMinutes * time.Minute)
	bookingID := uuid.NewString()
	type line struct {
		item         ItemInput
		unit         money.Amount
		partner, tit string
		avail        string
	}
	var lines []line
	var partner sql.NullString
	var base money.Amount
	for _, it := range in.Items {
		d, perr := time.Parse("2006-01-02", it.ServiceDate)
		if perr != nil || it.Quantity < 1 || it.Quantity > 20 || it.InventoryItemID == "" {
			return Result{}, ValidationError{"each item needs inventory_item_id, a service_date (YYYY-MM-DD) and quantity 1-20"}
		}
		if d.Before(now.Truncate(24 * time.Hour)) {
			return Result{}, ValidationError{"service_date is in the past"}
		}
		var availID, price, st string
		var pid sql.NullString
		var title string
		err := tx.QueryRowContext(ctx, `SELECT a.id, a.base_price, i.status, sp.partner_id, i.sku
			FROM inventory_availability a JOIN inventory_items i ON i.id = a.inventory_item_id JOIN supplier_products sp ON sp.id = i.supplier_product_id
			WHERE a.inventory_item_id = ? AND a.service_date = ? FOR UPDATE`, it.InventoryItemID, it.ServiceDate).Scan(&availID, &price, &st, &pid, &title)
		if err == sql.ErrNoRows || (err == nil && st != "ACTIVE") {
			return Result{}, ErrUnavailable
		} else if err != nil {
			return Result{}, err
		}
		if !pid.Valid {
			return Result{}, ValidationError{"item has no approved partner"}
		}
		if partner.Valid && partner.String != pid.String {
			return Result{}, ValidationError{"one booking can only contain items from one partner"}
		}
		partner = pid
		res, err := tx.ExecContext(ctx, "UPDATE inventory_availability SET quantity_sold = quantity_sold + ?, updated_at = ? WHERE id = ? AND quantity_sold + ? <= quantity_total", it.Quantity, now, availID, it.Quantity)
		if err != nil {
			return Result{}, err
		}
		if n, _ := res.RowsAffected(); n != 1 {
			return Result{}, ErrUnavailable
		}
		unit, perr := money.Parse(price)
		if perr != nil {
			return Result{}, perr
		}
		base += unit * money.Amount(it.Quantity)
		lines = append(lines, line{item: it, unit: unit, partner: pid.String, tit: title, avail: availID})
	}
	var partnerStatus string
	var entity sql.NullString
	if err := tx.QueryRowContext(ctx, "SELECT status, legal_entity_id FROM partners WHERE id = ? AND deleted_at IS NULL", partner.String).Scan(&partnerStatus, &entity); err != nil || partnerStatus != "APPROVED" {
		return Result{}, ValidationError{"partner is not approved"}
	}

	// Coupon (one per booking). Counter increment is a conditional UPDATE: race-safe.
	var discount money.Amount
	var discountID, couponID, fundedBy sql.NullString
	if in.CouponCode != "" {
		var dType, dValue, minAmt, maxDisc, cats sql.NullString
		var perUser sql.NullInt64
		err := tx.QueryRowContext(ctx, `SELECT c.id, d.id, d.discount_type, d.value, d.min_booking_amount, d.max_discount, d.usage_limit_per_user, d.funded_by
			FROM coupons c JOIN discounts d ON d.id = c.discount_id
			WHERE c.code = ? AND c.deleted_at IS NULL AND d.status = 'ACTIVE' AND d.valid_from <= ? AND (d.valid_to IS NULL OR d.valid_to > ?) AND (c.expires_at IS NULL OR c.expires_at > ?)
			  AND (d.owner_type = 'PLATFORM' OR d.owner_partner_id = ?)`, in.CouponCode, now, now, now, partner.String).
			Scan(&couponID, &discountID, &dType, &dValue, &minAmt, &maxDisc, &perUser, &fundedBy)
		_ = cats
		if err == sql.ErrNoRows {
			return Result{}, ErrCoupon
		} else if err != nil {
			return Result{}, err
		}
		if minAmt.Valid {
			if m, _ := money.Parse(minAmt.String); base < m {
				return Result{}, ErrCoupon
			}
		}
		if perUser.Valid {
			var used int64
			if err := tx.QueryRowContext(ctx, "SELECT COUNT(*) FROM discount_allocations da JOIN bookings b ON b.id = da.booking_id WHERE da.discount_id = ? AND b.user_id = ?", discountID.String, in.UserID).Scan(&used); err != nil {
				return Result{}, err
			}
			if used >= perUser.Int64 {
				return Result{}, ErrCoupon
			}
		}
		if dType.String == "FIXED" {
			discount, _ = money.Parse(dValue.String)
		} else {
			pct, _ := money.ParseRate(dValue.String)
			discount = money.Percent(base, pct/100)
		}
		if maxDisc.Valid {
			if m, _ := money.Parse(maxDisc.String); discount > m {
				discount = m
			}
		}
		if discount > base {
			discount = base
		}
		res, err := tx.ExecContext(ctx, "UPDATE coupons SET redeemed_count = redeemed_count + 1, updated_at = ? WHERE id = ? AND (max_redemptions IS NULL OR redeemed_count < max_redemptions)", now, couponID.String)
		if err != nil {
			return Result{}, err
		}
		if n, _ := res.RowsAffected(); n != 1 {
			return Result{}, ErrCoupon
		}
	}
	payableAmt := base - discount
	if payableAmt <= 0 {
		return Result{}, ValidationError{"payable total must be greater than zero"}
	}

	// Immutable price snapshot: what was shown and charged. VAT treatment is UNVERIFIED until accounting confirms (DEC-08-14).
	terms, _ := json.Marshal(map[string]any{"policy_source": "platform_default_proposal", "free_cancellation_hours_before_service": 48, "refund_percent_after_deadline": 0})
	snapID := uuid.NewString()
	if _, err := tx.ExecContext(ctx, `INSERT INTO booking_price_snapshots (id, created_at, base_total, discount_total, tax_total, mandatory_fee_total, optional_fee_total, service_fee_total, payable_total, currency_code, terms_json, captured_at)
		VALUES (?, ?, ?, ?, 0, 0, 0, 0, ?, 'THB', ?, ?)`, snapID, now, base.String(), discount.String(), payableAmt.String(), string(terms), now); err != nil {
		return Result{}, err
	}
	for _, l := range lines {
		if _, err := tx.ExecContext(ctx, "INSERT INTO booking_price_snapshot_lines (id, created_at, snapshot_id, line_type, label, amount, vat_included) VALUES (?, ?, ?, 'BASE', ?, ?, 'UNVERIFIED')",
			uuid.NewString(), now, snapID, fmt.Sprintf("%s x%d (%s)", l.tit, l.item.Quantity, l.item.ServiceDate), (l.unit * money.Amount(l.item.Quantity)).String()); err != nil {
			return Result{}, err
		}
	}
	if discount > 0 {
		if _, err := tx.ExecContext(ctx, "INSERT INTO booking_price_snapshot_lines (id, created_at, snapshot_id, line_type, label, amount, vat_included) VALUES (?, ?, ?, 'DISCOUNT', 'coupon', ?, 'UNVERIFIED')", uuid.NewString(), now, snapID, discount.String()); err != nil {
			return Result{}, err
		}
	}
	bcode := code()
	if _, err := tx.ExecContext(ctx, `INSERT INTO bookings (id, created_at, updated_at, user_id, booking_code, currency_code, total_amount, status, partner_id, seller_entity_id, price_snapshot_id, idempotency_key, expires_at)
		VALUES (?, ?, ?, ?, ?, 'THB', ?, 'PENDING_PAYMENT', ?, ?, ?, ?, ?)`, bookingID, now, now, in.UserID, bcode, payableAmt.String(), partner.String, entity, snapID, in.IdempotencyKey, expires); err != nil {
		return Result{}, err
	}
	for _, l := range lines {
		if _, err := tx.ExecContext(ctx, `INSERT INTO booking_items (id, created_at, updated_at, booking_id, item_type, reference_id, quantity, unit_amount, partner_id, service_date, title_snapshot)
			VALUES (?, ?, ?, ?, 'INTERNAL_INVENTORY', ?, ?, ?, ?, ?, ?)`, uuid.NewString(), now, now, bookingID, l.item.InventoryItemID, l.item.Quantity, l.unit.String(), l.partner, l.item.ServiceDate, l.tit); err != nil {
			return Result{}, err
		}
		if _, err := tx.ExecContext(ctx, `INSERT INTO inventory_holds (id, created_at, updated_at, booking_id, inventory_item_id, service_date, quantity, expires_at)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?)`, uuid.NewString(), now, now, bookingID, l.item.InventoryItemID, l.item.ServiceDate, l.item.Quantity, expires); err != nil {
			return Result{}, err
		}
	}
	if discount > 0 {
		if _, err := tx.ExecContext(ctx, "INSERT INTO discount_allocations (id, created_at, booking_id, discount_id, coupon_id, funded_by, amount, currency_code) VALUES (?, ?, ?, ?, ?, ?, ?, 'THB')",
			uuid.NewString(), now, bookingID, discountID.String, couponID.String, fundedBy.String, discount.String()); err != nil {
			return Result{}, err
		}
	}
	if _, err := tx.ExecContext(ctx, "INSERT INTO booking_status_histories (id, created_at, booking_id, from_status, to_status, actor_type, actor_id, request_id) VALUES (?, ?, ?, NULL, 'PENDING_PAYMENT', 'USER', ?, NULLIF(?, ''))",
		uuid.NewString(), now, bookingID, in.UserID, in.RequestID); err != nil {
		return Result{}, err
	}
	if err := faudit.Append(ctx, tx, faudit.Entry{ActorUserID: in.UserID, ActorType: "USER", EntityType: "booking", EntityID: bookingID, Action: "booking.created",
		Changes: map[string]any{"payable_total": payableAmt.String(), "base_total": base.String(), "discount_total": discount.String(), "price_snapshot_id": snapID}, IP: in.IP, RequestID: in.RequestID}); err != nil {
		return Result{}, err
	}
	if err := tx.Commit(); err != nil {
		return Result{}, err
	}
	return Result{ID: bookingID, Code: bcode, Status: "PENDING_PAYMENT", Currency: "THB", PayableTotal: payableAmt, BaseTotal: base, DiscountTotal: discount, ExpiresAt: expires}, nil
}

// ExpireHolds releases inventory for bookings whose payment window passed (run by a scheduled job).
// It only touches bookings still in PENDING_PAYMENT, and is safe to run concurrently with payment webhooks because it locks the booking row.
func (s *Service) ExpireHolds(ctx context.Context) (int, error) {
	rows, err := s.db.QueryContext(ctx, "SELECT id FROM bookings WHERE status = 'PENDING_PAYMENT' AND expires_at < ? LIMIT 200", s.now().UTC())
	if err != nil {
		return 0, err
	}
	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			rows.Close()
			return 0, err
		}
		ids = append(ids, id)
	}
	rows.Close()
	n := 0
	for _, id := range ids {
		ok, err := s.expireOne(ctx, id)
		if err != nil {
			return n, err
		}
		if ok {
			n++
		}
	}
	return n, nil
}

func (s *Service) expireOne(ctx context.Context, id string) (bool, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return false, err
	}
	defer tx.Rollback()
	var st string
	if err := tx.QueryRowContext(ctx, "SELECT status FROM bookings WHERE id = ? FOR UPDATE", id).Scan(&st); err != nil {
		return false, err
	}
	if st != "PENDING_PAYMENT" {
		return false, nil
	}
	now := s.now().UTC()
	if _, err := tx.ExecContext(ctx, `UPDATE inventory_availability a JOIN inventory_holds h ON h.inventory_item_id = a.inventory_item_id AND h.service_date = a.service_date
		SET a.quantity_sold = a.quantity_sold - h.quantity, a.updated_at = ? WHERE h.booking_id = ? AND h.status = 'HELD'`, now, id); err != nil {
		return false, err
	}
	if _, err := tx.ExecContext(ctx, "UPDATE inventory_holds SET status = 'RELEASED', updated_at = ? WHERE booking_id = ? AND status = 'HELD'", now, id); err != nil {
		return false, err
	}
	// give the coupon back
	if _, err := tx.ExecContext(ctx, "UPDATE coupons c JOIN discount_allocations da ON da.coupon_id = c.id SET c.redeemed_count = c.redeemed_count - 1 WHERE da.booking_id = ? AND c.redeemed_count > 0", id); err != nil {
		return false, err
	}
	if _, err := tx.ExecContext(ctx, "UPDATE bookings SET status = 'CANCELLED', updated_at = ? WHERE id = ?", now, id); err != nil {
		return false, err
	}
	if _, err := tx.ExecContext(ctx, "INSERT INTO booking_status_histories (id, created_at, booking_id, from_status, to_status, actor_type, reason) VALUES (?, ?, ?, 'PENDING_PAYMENT', 'CANCELLED', 'SYSTEM', 'payment window expired')", uuid.NewString(), now, id); err != nil {
		return false, err
	}
	if err := faudit.Append(ctx, tx, faudit.Entry{ActorType: "SYSTEM", EntityType: "booking", EntityID: id, Action: "booking.expired", Reason: "payment window expired"}); err != nil {
		return false, err
	}
	return true, tx.Commit()
}
