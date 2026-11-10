// Package refund implements the hybrid refund workflow: small, policy-clear, low-risk refunds are approved automatically;
// others need a human approver whose limit covers the amount and who is not the requester (Section 8.6; amounts are an internal PROPOSAL).
package refund

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/travel-super-app/backend/internal/finance/txopt"
	"time"

	"github.com/google/uuid"
	"github.com/travel-super-app/backend/internal/finance/faudit"
	"github.com/travel-super-app/backend/internal/finance/money"
	"github.com/travel-super-app/backend/internal/finance/payment"
	"github.com/travel-super-app/backend/internal/finance/safety"
	"github.com/travel-super-app/backend/internal/finance/wallet"
	"github.com/travel-super-app/backend/internal/platform/dberr"
)

var (
	ErrNotFound        = errors.New("not found")
	ErrNotRefundable   = errors.New("booking is not refundable")
	ErrNothingDue      = errors.New("no refund is due under the cancellation policy")
	ErrBadMethod       = errors.New("method must be ORIGINAL_METHOD or SABAI_WALLET")
	ErrLimit           = errors.New("amount exceeds the approver's limit")
	ErrSelfApproval    = errors.New("the requester cannot approve their own refund")
	ErrAlreadyDecided  = errors.New("you have already decided on this refund")
	ErrWrongState      = errors.New("refund is not in a state that allows this")
	ErrConsentRequired = errors.New("wallet refund requires the customer's recorded consent")
	ErrConsentWording  = errors.New("consent wording is not legally approved or does not match")
)

// AutoLimit is the refund size up to which a clear, low-risk customer cancellation is approved automatically (proposal, from approval_limits AUTO tier).
type Service struct {
	db       *sql.DB
	provider payment.Provider
	cfg      safety.Config
	now      func() time.Time
}

func NewService(db *sql.DB, p payment.Provider, cfg safety.Config) *Service {
	return &Service{db: db, provider: p, cfg: cfg, now: time.Now}
}

type Request struct {
	ID, Status string
	Calculated money.Amount
	Auto       bool
}

type terms struct {
	FreeHours int `json:"free_cancellation_hours_before_service"`
	AfterPct  int `json:"refund_percent_after_deadline"`
}

func limits(ctx context.Context, q interface {
	QueryContext(ctx context.Context, query string, args ...any) (*sql.Rows, error)
}) (map[string]*money.Amount, error) {
	rows, err := q.QueryContext(ctx, `SELECT l.role_code, l.max_amount FROM approval_limits l
		JOIN (SELECT role_code, MAX(version) v FROM approval_limits WHERE currency_code = 'THB' GROUP BY role_code) m ON m.role_code = l.role_code AND m.v = l.version WHERE l.currency_code = 'THB'`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[string]*money.Amount{}
	for rows.Next() {
		var role string
		var max sql.NullString
		if err := rows.Scan(&role, &max); err != nil {
			return nil, err
		}
		if max.Valid {
			a, _ := money.Parse(max.String)
			out[role] = &a
		} else {
			out[role] = nil
		}
	}
	return out, rows.Err()
}

// Create computes the refundable amount from the booking's own price snapshot (never from the client) and opens a request.
func (s *Service) Create(ctx context.Context, userID, bookingID, reason, method, idemKey, requestID string) (Request, error) {
	if err := s.cfg.Check(ctx, s.db); err != nil {
		return Request{}, err
	}
	if method != "ORIGINAL_METHOD" && method != "SABAI_WALLET" {
		return Request{}, ErrBadMethod
	}
	if idemKey == "" {
		return Request{}, errors.New("Idempotency-Key header is required")
	}
	tx, err := s.db.BeginTx(ctx, txopt.Financial)
	if err != nil {
		return Request{}, err
	}
	defer tx.Rollback()
	var prev Request
	var calc sql.NullString
	if err := tx.QueryRowContext(ctx, "SELECT id, status, calculated_amount, auto_eligible FROM refund_requests WHERE idempotency_key = ? AND requested_by = ?", idemKey, userID).Scan(&prev.ID, &prev.Status, &calc, &prev.Auto); err == nil {
		prev.Calculated, _ = money.Parse(calc.String)
		return prev, nil
	} else if err != sql.ErrNoRows {
		return Request{}, err
	}
	var owner, status, terms_ string
	var partnerRisk sql.NullString
	err = tx.QueryRowContext(ctx, `SELECT b.user_id, b.status, s.terms_json, p.risk_level FROM bookings b JOIN booking_price_snapshots s ON s.id = b.price_snapshot_id LEFT JOIN partners p ON p.id = b.partner_id WHERE b.id = ? FOR UPDATE`, bookingID).Scan(&owner, &status, &terms_, &partnerRisk)
	if err == sql.ErrNoRows || (err == nil && owner != userID) {
		return Request{}, ErrNotFound
	} else if err != nil {
		return Request{}, err
	}
	if status != "PAID" && status != "CONFIRMED" {
		return Request{}, ErrNotRefundable
	}
	var open int
	if err := tx.QueryRowContext(ctx, "SELECT COUNT(*) FROM refund_requests WHERE booking_id = ? AND status IN ('REQUESTED','UNDER_REVIEW','APPROVED','PROCESSING')", bookingID).Scan(&open); err != nil {
		return Request{}, err
	}
	if open > 0 {
		return Request{}, ErrWrongState
	}
	var paymentID, captured, refunded string
	if err := tx.QueryRowContext(ctx, "SELECT id, captured_amount, refunded_amount FROM payments WHERE booking_id = ? AND status = 'SUCCEEDED' ORDER BY leg_no LIMIT 1 FOR UPDATE", bookingID).Scan(&paymentID, &captured, &refunded); err != nil {
		return Request{}, ErrNotRefundable
	}
	var firstService time.Time
	if err := tx.QueryRowContext(ctx, "SELECT MIN(service_date) FROM booking_items WHERE booking_id = ?", bookingID).Scan(&firstService); err != nil {
		return Request{}, err
	}
	var t terms
	_ = json.Unmarshal([]byte(terms_), &t)
	cap, _ := money.Parse(captured)
	ref, _ := money.Parse(refunded)
	remaining := cap - ref
	now := s.now().UTC()
	pct := t.AfterPct
	inFreeWindow := now.Before(firstService.Add(-time.Duration(t.FreeHours) * time.Hour))
	if inFreeWindow {
		pct = 100
	}
	calculated := money.Percent(remaining, money.RateMicro(pct*10_000))
	if calculated <= 0 {
		return Request{}, ErrNothingDue
	}
	lim, err := limits(ctx, tx)
	if err != nil {
		return Request{}, err
	}
	autoMax := lim["AUTO"]
	auto := inFreeWindow && reason == "CUSTOMER_CANCELLATION" && partnerRisk.String != "HIGH" && autoMax != nil && calculated <= *autoMax
	st := "UNDER_REVIEW"
	if auto {
		st = "APPROVED"
	}
	id := uuid.NewString()
	var approved any
	if auto {
		approved = calculated.String()
	}
	if _, err := tx.ExecContext(ctx, `INSERT INTO refund_requests (id, created_at, updated_at, booking_id, payment_id, requested_by, reason_code, requested_amount, calculated_amount, approved_amount, currency_code, method, status, risk_flag, auto_eligible, idempotency_key)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'THB', ?, ?, ?, ?, ?)`, id, now, now, bookingID, paymentID, userID, reason, calculated.String(), calculated.String(), approved, method, st, partnerRisk.String == "HIGH", auto, idemKey); err != nil {
		return Request{}, err
	}
	if err := faudit.Append(ctx, tx, faudit.Entry{ActorUserID: userID, ActorType: "USER", EntityType: "refund_request", EntityID: id, Action: "refund.requested",
		Changes: map[string]any{"calculated": calculated.String(), "method": method, "auto_approved": auto, "free_window": inFreeWindow}, RequestID: requestID}); err != nil {
		return Request{}, err
	}
	return Request{ID: id, Status: st, Calculated: calculated, Auto: auto}, tx.Commit()
}

// RecordConsent stores the customer's acceptance of a wallet refund. It only works with wording that legal approved and made effective,
// and the hash the customer saw must match, so a refund can never be forced into the wallet.
func (s *Service) RecordConsent(ctx context.Context, userID, refundID, versionID, shownHash, ip, device string) error {
	tx, err := s.db.BeginTx(ctx, txopt.Financial)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var bookingID, method, status, owner string
	if err := tx.QueryRowContext(ctx, "SELECT booking_id, method, status, requested_by FROM refund_requests WHERE id = ? FOR UPDATE", refundID).Scan(&bookingID, &method, &status, &owner); err != nil || owner != userID {
		return ErrNotFound
	}
	if method != "SABAI_WALLET" || status == "COMPLETED" || status == "REJECTED" {
		return ErrWrongState
	}
	var hash string
	var legalAt, effective sql.NullTime
	if err := tx.QueryRowContext(ctx, "SELECT text_sha256, legal_approved_at, effective_from FROM consent_versions WHERE id = ? AND consent_type = 'WALLET_REFUND'", versionID).Scan(&hash, &legalAt, &effective); err != nil {
		return ErrConsentWording
	}
	now := s.now().UTC()
	if !legalAt.Valid || !effective.Valid || effective.Time.After(now) || hash != shownHash {
		return ErrConsentWording
	}
	if _, err := tx.ExecContext(ctx, `INSERT INTO wallet_consents (id, created_at, user_id, booking_id, refund_request_id, consent_version_id, text_sha256_shown, presented_at, accepted_at, ip_address, device_info)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULLIF(?, ''), NULLIF(?, ''))`, uuid.NewString(), now, userID, bookingID, refundID, versionID, shownHash, now, now, ip, device); err != nil {
		return err
	}
	if err := faudit.Append(ctx, tx, faudit.Entry{ActorUserID: userID, ActorType: "USER", EntityType: "refund_request", EntityID: refundID, Action: "refund.wallet_consent.recorded", Changes: map[string]any{"consent_version_id": versionID}, IP: ip}); err != nil {
		return err
	}
	return tx.Commit()
}

type Approver struct {
	UserID string
	Roles  map[string]bool
}

// bestLimit is the highest limit among the approver's roles (nil = unlimited).
func bestLimit(lim map[string]*money.Amount, roles map[string]bool) (limit *money.Amount, ok bool) {
	for _, r := range []string{"REFUND_OFFICER", "FINANCE_MANAGER", "CFO_CEO"} {
		if !roles[r] {
			continue
		}
		l, exists := lim[r]
		if !exists {
			continue
		}
		if l == nil {
			return nil, true
		}
		if limit == nil || *l > *limit {
			v := *l
			limit = &v
		}
		ok = true
	}
	return limit, ok
}

// TwoApproverThreshold: refunds above this need two distinct approvers (proposal; one must hold CFO_CEO).
const TwoApproverThreshold = money.Amount(5_000_000)

// Decide records one approver's decision. The decision is valid only if the approver's role limit covers the amount.
func (s *Service) Decide(ctx context.Context, a Approver, refundID string, approve bool, reason, requestID string) (string, error) {
	tx, err := s.db.BeginTx(ctx, txopt.Financial)
	if err != nil {
		return "", err
	}
	defer tx.Rollback()
	var status, requester, amt string
	if err := tx.QueryRowContext(ctx, "SELECT status, COALESCE(requested_by,''), calculated_amount FROM refund_requests WHERE id = ? FOR UPDATE", refundID).Scan(&status, &requester, &amt); err != nil {
		return "", ErrNotFound
	}
	if status != "UNDER_REVIEW" && status != "REQUESTED" {
		return "", ErrWrongState
	}
	if requester == a.UserID {
		return "", ErrSelfApproval
	}
	amount, _ := money.Parse(amt)
	lim, err := limits(ctx, tx)
	if err != nil {
		return "", err
	}
	limit, ok := bestLimit(lim, a.Roles)
	if !ok || (limit != nil && amount > *limit) {
		return "", ErrLimit
	}
	role := "REFUND_OFFICER"
	switch {
	case a.Roles["CFO_CEO"]:
		role = "CFO_CEO"
	case a.Roles["FINANCE_MANAGER"]:
		role = "FINANCE_MANAGER"
	}
	decision := "REJECT"
	if approve {
		decision = "APPROVE"
	}
	var limStr any
	if limit != nil {
		limStr = limit.String()
	}
	now := s.now().UTC()
	if _, err := tx.ExecContext(ctx, "INSERT INTO refund_approvals (id, created_at, refund_request_id, approver_user_id, approver_role, decision, limit_at_decision, reason, decided_at) VALUES (?, ?, ?, ?, ?, ?, ?, NULLIF(?, ''), ?)",
		uuid.NewString(), now, refundID, a.UserID, role, decision, limStr, reason, now); err != nil {
		if isDup(err) {
			return "", ErrAlreadyDecided
		}
		return "", err
	}
	next := status
	if !approve {
		next = "REJECTED"
	} else {
		var n, cfo int
		if err := tx.QueryRowContext(ctx, "SELECT COUNT(*), COALESCE(SUM(approver_role = 'CFO_CEO'), 0) FROM refund_approvals WHERE refund_request_id = ? AND decision = 'APPROVE'", refundID).Scan(&n, &cfo); err != nil {
			return "", err
		}
		if amount <= TwoApproverThreshold || (n >= 2 && cfo >= 1) {
			next = "APPROVED"
		}
	}
	if next != status {
		var approved any
		if next == "APPROVED" {
			approved = amount.String()
		}
		if _, err := tx.ExecContext(ctx, "UPDATE refund_requests SET status = ?, approved_amount = ?, updated_at = ? WHERE id = ?", next, approved, now, refundID); err != nil {
			return "", err
		}
	}
	if err := faudit.Append(ctx, tx, faudit.Entry{ActorUserID: a.UserID, ActorType: "STAFF", EntityType: "refund_request", EntityID: refundID, Action: "refund." + decision,
		Changes: map[string]any{"amount": amount.String(), "approver_role": role, "status": next}, Reason: reason, RequestID: requestID}); err != nil {
		return "", err
	}
	return next, tx.Commit()
}

// Execute disburses an APPROVED refund exactly once: one live refund_transaction per request (unique key), the payment's refunded_amount
// can never exceed what was captured (CHECK), a wallet refund needs recorded consent (trigger), and the provider call carries an idempotency key.
func (s *Service) Execute(ctx context.Context, refundID string) error {
	if err := s.cfg.Check(ctx, s.db); err != nil {
		return err
	}
	tx, err := s.db.BeginTx(ctx, txopt.Financial)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var status, method, paymentID, bookingID, userID, approved, ref string
	if err := tx.QueryRowContext(ctx, `SELECT r.status, r.method, r.payment_id, r.booking_id, b.user_id, r.approved_amount, p.provider_reference FROM refund_requests r JOIN bookings b ON b.id = r.booking_id JOIN payments p ON p.id = r.payment_id WHERE r.id = ? FOR UPDATE`, refundID).
		Scan(&status, &method, &paymentID, &bookingID, &userID, &approved, &ref); err != nil {
		return ErrNotFound
	}
	if status == "COMPLETED" {
		return nil // already done: idempotent
	}
	if status != "APPROVED" {
		return ErrWrongState
	}
	if method == "SABAI_WALLET" {
		var c int
		if err := tx.QueryRowContext(ctx, "SELECT COUNT(*) FROM wallet_consents WHERE refund_request_id = ?", refundID).Scan(&c); err != nil {
			return err
		}
		if c == 0 {
			return ErrConsentRequired
		}
	}
	amount, _ := money.Parse(approved)
	var attempts int
	if err := tx.QueryRowContext(ctx, "SELECT COUNT(*) FROM refund_transactions WHERE refund_request_id = ?", refundID).Scan(&attempts); err != nil {
		return err
	}
	attempt := attempts + 1
	key := fmt.Sprintf("refund:%s:%d", refundID, attempt)
	now := s.now().UTC()
	txID := uuid.NewString()
	var pspRef sql.NullString
	var ledgerID sql.NullString
	if method == "ORIGINAL_METHOD" {
		r, err := s.provider.Refund(ctx, ref, amount, key)
		if err != nil {
			return err
		}
		pspRef = sql.NullString{String: r, Valid: true}
	} else {
		e, err := wallet.Post(ctx, tx, userID, "REFUND_CREDIT", "REFUND", refundID, amount, key, "")
		if err != nil {
			return err
		}
		ledgerID = sql.NullString{String: e.ID, Valid: true}
	}
	if _, err := tx.ExecContext(ctx, `INSERT INTO refund_transactions (id, created_at, updated_at, refund_request_id, attempt_no, destination, amount, currency_code, status, psp_reference, wallet_ledger_entry_id, idempotency_key)
		VALUES (?, ?, ?, ?, ?, ?, ?, 'THB', 'COMPLETED', ?, ?, ?)`, txID, now, now, refundID, attempt, method, amount.String(), pspRef, ledgerID, key); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, "UPDATE payments SET refunded_amount = refunded_amount + ?, updated_at = ? WHERE id = ?", amount.String(), now, paymentID); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, "UPDATE refund_requests SET status = 'COMPLETED', psp_refund_status = 'DONE', updated_at = ? WHERE id = ?", now, refundID); err != nil {
		return err
	}
	var fully int
	if err := tx.QueryRowContext(ctx, "SELECT refunded_amount = captured_amount FROM payments WHERE id = ?", paymentID).Scan(&fully); err != nil {
		return err
	}
	if fully == 1 {
		var from string
		if err := tx.QueryRowContext(ctx, "SELECT status FROM bookings WHERE id = ? FOR UPDATE", bookingID).Scan(&from); err != nil {
			return err
		}
		if from == "PAID" || from == "CONFIRMED" {
			if _, err := tx.ExecContext(ctx, "UPDATE bookings SET status = 'CANCELLED', updated_at = ? WHERE id = ?", now, bookingID); err != nil {
				return err
			}
			if _, err := tx.ExecContext(ctx, "INSERT INTO booking_status_histories (id, created_at, booking_id, from_status, to_status, actor_type, reason) VALUES (?, ?, ?, ?, 'CANCELLED', 'SYSTEM', 'fully refunded')", uuid.NewString(), now, bookingID, from); err != nil {
				return err
			}
			// the seats go back on sale
			if _, err := tx.ExecContext(ctx, `UPDATE inventory_availability a JOIN inventory_holds h ON h.inventory_item_id = a.inventory_item_id AND h.service_date = a.service_date
				SET a.quantity_sold = a.quantity_sold - h.quantity, a.updated_at = ? WHERE h.booking_id = ? AND h.status = 'CONSUMED'`, now, bookingID); err != nil {
				return err
			}
			if _, err := tx.ExecContext(ctx, "UPDATE inventory_holds SET status = 'RELEASED', updated_at = ? WHERE booking_id = ? AND status = 'CONSUMED'", now, bookingID); err != nil {
				return err
			}
		}
	}
	if err := faudit.Append(ctx, tx, faudit.Entry{ActorType: "SYSTEM", EntityType: "refund_request", EntityID: refundID, Action: "refund.completed",
		Changes: map[string]any{"amount": amount.String(), "destination": method, "attempt": attempt}, ReferenceID: key}); err != nil {
		return err
	}
	return tx.Commit()
}

func isDup(err error) bool { return dberr.IsDuplicate(err) }
