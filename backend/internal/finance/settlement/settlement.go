// Package settlement builds partner settlement batches (commission calculation, weekly Tuesday cycle with a reconciliation window),
// enforces maker/checker approval, and pays out through the provider exactly once.
package settlement

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"github.com/travel-super-app/backend/internal/finance/txopt"
	"time"

	"github.com/google/uuid"
	"github.com/travel-super-app/backend/internal/finance/faudit"
	"github.com/travel-super-app/backend/internal/finance/money"
	"github.com/travel-super-app/backend/internal/finance/payment"
	"github.com/travel-super-app/backend/internal/finance/safety"
	"github.com/travel-super-app/backend/internal/platform/dberr"
)

var (
	ErrNotFound  = errors.New("batch not found")
	ErrExists    = errors.New("a batch already exists for this partner and period")
	ErrNothing   = errors.New("no eligible bookings for this period")
	ErrState     = errors.New("batch is not in a state that allows this")
	ErrSoD       = errors.New("the person who created or reviewed a batch cannot approve it")
	ErrNoAccount = errors.New("partner has no verified bank account")
	ErrNoPolicy  = errors.New("no active commission policy")
)

type Service struct {
	db       *sql.DB
	provider payment.Provider
	cfg      safety.Config
}

func NewService(db *sql.DB, p payment.Provider, cfg safety.Config) *Service {
	return &Service{db: db, provider: p, cfg: cfg}
}

type Batch struct {
	ID                     string
	Items                  int
	Gross, Commission, Net money.Amount
	Status                 string
}

// Build calculates commission for every booking of the partner whose last service date plus the reconciliation window is on or before asOf.
// A booking is settled at most once (unique commission_calculation per item). Partially refunded bookings are held back for manual review.
func (s *Service) Build(ctx context.Context, actorID, partnerID string, from, to, asOf time.Time) (Batch, error) {
	tx, err := s.db.BeginTx(ctx, txopt.Financial)
	if err != nil {
		return Batch{}, err
	}
	defer tx.Rollback()
	var recon int
	if err := tx.QueryRowContext(ctx, `SELECT COALESCE((SELECT reconciliation_days FROM partner_contracts WHERE partner_id = ? AND status = 'ACTIVE' ORDER BY version DESC LIMIT 1), 7)`, partnerID).Scan(&recon); err != nil {
		return Batch{}, err
	}
	rows, err := tx.QueryContext(ctx, `SELECT b.id, s.base_total, p.id FROM bookings b
		JOIN booking_price_snapshots s ON s.id = b.price_snapshot_id
		JOIN payments p ON p.booking_id = b.id AND p.status = 'SUCCEEDED'
		WHERE b.partner_id = ? AND b.status IN ('PAID','CONFIRMED','COMPLETED') AND p.refunded_amount = 0
		  AND NOT EXISTS (SELECT 1 FROM partner_settlement_items i WHERE i.booking_id = b.id AND i.kind = 'ORIGINAL')
		  AND (SELECT MAX(service_date) FROM booking_items WHERE booking_id = b.id) BETWEEN ? AND ?
		  AND DATE_ADD((SELECT MAX(service_date) FROM booking_items WHERE booking_id = b.id), INTERVAL ? DAY) <= ?
		ORDER BY b.created_at FOR UPDATE`, partnerID, from.Format("2006-01-02"), to.Format("2006-01-02"), recon, asOf.Format("2006-01-02"))
	if err != nil {
		return Batch{}, err
	}
	type cand struct{ booking, base string }
	var cands []cand
	for rows.Next() {
		var c cand
		var pay string
		if err := rows.Scan(&c.booking, &c.base, &pay); err != nil {
			rows.Close()
			return Batch{}, err
		}
		cands = append(cands, c)
	}
	rows.Close()
	if len(cands) == 0 {
		return Batch{}, ErrNothing
	}
	now := time.Now().UTC()
	batchID := uuid.NewString()
	var policyID, ptype string
	var version int
	var rate, fixed sql.NullString
	err = tx.QueryRowContext(ctx, `SELECT id, policy_version, commission_type, rate, fixed_amount FROM commission_policies
		WHERE status = 'ACTIVE' AND effective_from <= ? AND (effective_to IS NULL OR effective_to > ?) AND (scope = 'DEFAULT' OR (scope = 'PARTNER' AND partner_id = ?))
		ORDER BY FIELD(scope, 'PARTNER', 'DEFAULT') LIMIT 1`, now, now, partnerID).Scan(&policyID, &version, &ptype, &rate, &fixed)
	if err == sql.ErrNoRows {
		return Batch{}, ErrNoPolicy
	} else if err != nil {
		return Batch{}, err
	}
	var createdBy any
	if actorID != "" {
		createdBy = actorID
	}
	// totals are written after the items exist so the batch CHECK (net = gross - commission) can be satisfied
	if _, err := tx.ExecContext(ctx, `INSERT INTO partner_settlement_batches (id, created_at, updated_at, partner_id, period_from, period_to, currency_code, status, created_by) VALUES (?, ?, ?, ?, ?, ?, 'THB', 'CALCULATED', ?)`,
		batchID, now, now, partnerID, from.Format("2006-01-02"), to.Format("2006-01-02"), createdBy); err != nil {
		if dberr.IsDuplicate(err) {
			return Batch{}, ErrExists
		}
		return Batch{}, err
	}
	var gross, comm money.Amount
	for _, c := range cands {
		eligible, _ := money.Parse(c.base)
		var pf string
		if err := tx.QueryRowContext(ctx, "SELECT COALESCE(SUM(amount), 0) FROM discount_allocations WHERE booking_id = ? AND funded_by = 'PARTNER'", c.booking).Scan(&pf); err != nil {
			return Batch{}, err
		}
		partnerDisc, _ := money.Parse(pf)
		base := eligible - partnerDisc
		var amount money.Amount
		var rateArg any
		if ptype == "PERCENT" {
			r, _ := money.ParseRate(rate.String)
			amount = money.Percent(base, r)
			rateArg = rate.String
		} else {
			amount, _ = money.Parse(fixed.String)
		}
		calcID := uuid.NewString()
		if _, err := tx.ExecContext(ctx, `INSERT INTO commission_calculations (id, created_at, booking_id, partner_id, kind, commission_policy_id, policy_version, commission_type, commission_rate,
			eligible_service_amount, partner_funded_discount, excluded_pass_through, commission_base_amount, commission_amount, currency_code, calculation_timestamp)
			VALUES (?, ?, ?, ?, 'ORIGINAL', ?, ?, ?, ?, ?, ?, 0, ?, ?, 'THB', ?)`, calcID, now, c.booking, partnerID, policyID, version, ptype, rateArg, eligible.String(), partnerDisc.String(), base.String(), amount.String(), now); err != nil {
			return Batch{}, err
		}
		if _, err := tx.ExecContext(ctx, `INSERT INTO partner_settlement_items (id, created_at, batch_id, booking_id, commission_calculation_id, kind, eligible_on, gross_amount, commission_amount, net_amount)
			VALUES (?, ?, ?, ?, ?, 'ORIGINAL', ?, ?, ?, ?)`, uuid.NewString(), now, batchID, c.booking, calcID, asOf, base.String(), amount.String(), (base - amount).String()); err != nil {
			return Batch{}, err
		}
		gross += base
		comm += amount
	}
	if _, err := tx.ExecContext(ctx, "UPDATE partner_settlement_batches SET gross_sales = ?, commission_total = ?, net_amount = ?, updated_at = ? WHERE id = ?", gross.String(), comm.String(), (gross - comm).String(), now, batchID); err != nil {
		return Batch{}, err
	}
	actorType := "SYSTEM"
	if actorID != "" {
		actorType = "STAFF"
	}
	if err := faudit.Append(ctx, tx, faudit.Entry{ActorUserID: actorID, ActorType: actorType, EntityType: "settlement_batch", EntityID: batchID, Action: "settlement.calculated",
		Changes: map[string]any{"gross": gross.String(), "commission": comm.String(), "net": (gross - comm).String(), "items": len(cands), "policy_version": version}}); err != nil {
		return Batch{}, err
	}
	return Batch{ID: batchID, Items: len(cands), Gross: gross, Commission: comm, Net: gross - comm, Status: "CALCULATED"}, tx.Commit()
}

func (s *Service) move(ctx context.Context, actorID, batchID, from, to, col, action string) error {
	tx, err := s.db.BeginTx(ctx, txopt.Financial)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var st string
	if err := tx.QueryRowContext(ctx, "SELECT status FROM partner_settlement_batches WHERE id = ? FOR UPDATE", batchID).Scan(&st); err != nil {
		return ErrNotFound
	}
	if st != from {
		return ErrState
	}
	q := "UPDATE partner_settlement_batches SET status = ?, " + col + " = ?, updated_at = ? WHERE id = ?"
	args := []any{to, actorID, time.Now().UTC(), batchID}
	if col == "approved_by" {
		q = "UPDATE partner_settlement_batches SET status = ?, approved_by = ?, approved_at = ?, updated_at = ? WHERE id = ?"
		args = []any{to, actorID, time.Now().UTC(), time.Now().UTC(), batchID}
	}
	if _, err := tx.ExecContext(ctx, q, args...); err != nil {
		if isCheck(err) {
			return ErrSoD
		}
		return err
	}
	if err := faudit.Append(ctx, tx, faudit.Entry{ActorUserID: actorID, ActorType: "STAFF", EntityType: "settlement_batch", EntityID: batchID, Action: action, Changes: map[string]any{"from": from, "to": to}}); err != nil {
		return err
	}
	return tx.Commit()
}

func isCheck(err error) bool { return err != nil && (contains(err.Error(), "Error 3819")) }
func contains(s, sub string) bool {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return true
		}
	}
	return false
}

// Review marks the batch as checked by a finance reviewer (the "maker/checker" first step).
func (s *Service) Review(ctx context.Context, actorID, batchID string) error {
	return s.move(ctx, actorID, batchID, "CALCULATED", "UNDER_REVIEW", "reviewed_by", "settlement.reviewed")
}

// Approve needs a different person than the creator and the reviewer; the database CHECK enforces it as well.
func (s *Service) Approve(ctx context.Context, actorID, batchID string) error {
	return s.move(ctx, actorID, batchID, "UNDER_REVIEW", "APPROVED", "approved_by", "settlement.approved")
}

// Payout sends the net amount to the partner's verified bank account. At most one live payout per batch exists (unique key);
// a failed attempt is recorded and a retry creates a new attempt with a new idempotency key.
func (s *Service) Payout(ctx context.Context, actorID, batchID string) error {
	if err := s.cfg.Check(ctx, s.db); err != nil {
		return err
	}
	tx, err := s.db.BeginTx(ctx, txopt.Financial)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var st, partnerID, net string
	if err := tx.QueryRowContext(ctx, "SELECT status, partner_id, net_amount FROM partner_settlement_batches WHERE id = ? FOR UPDATE", batchID).Scan(&st, &partnerID, &net); err != nil {
		return ErrNotFound
	}
	if st != "APPROVED" && st != "FAILED" {
		return ErrState
	}
	var acct string
	if err := tx.QueryRowContext(ctx, "SELECT id FROM partner_bank_accounts WHERE partner_id = ? AND verified_at IS NOT NULL AND valid_from <= ? AND (valid_to IS NULL OR valid_to > ?) ORDER BY valid_from DESC LIMIT 1", partnerID, time.Now().UTC(), time.Now().UTC()).Scan(&acct); err != nil {
		return ErrNoAccount
	}
	amount, _ := money.Parse(net)
	var attempts int
	if err := tx.QueryRowContext(ctx, "SELECT COUNT(*) FROM partner_payouts WHERE batch_id = ?", batchID).Scan(&attempts); err != nil {
		return err
	}
	attempt := attempts + 1
	key := fmt.Sprintf("payout:%s:%d", batchID, attempt)
	now := time.Now().UTC()
	ref, perr := s.provider.Payout(ctx, acct, amount, key)
	pid := uuid.NewString()
	status, failed := "PAID", any(nil)
	if perr != nil {
		status, failed = "FAILED", perr.Error()
	}
	if _, err := tx.ExecContext(ctx, `INSERT INTO partner_payouts (id, created_at, updated_at, batch_id, attempt_no, partner_bank_account_id, amount, currency_code, status, payout_reference, idempotency_key, initiated_by, failed_reason)
		VALUES (?, ?, ?, ?, ?, ?, ?, 'THB', ?, NULLIF(?, ''), ?, ?, ?)`, pid, now, now, batchID, attempt, acct, amount.String(), status, ref, key, actorID, failed); err != nil {
		return err
	}
	batchStatus := "PAID"
	if status == "FAILED" {
		batchStatus = "FAILED"
	}
	if _, err := tx.ExecContext(ctx, "UPDATE partner_settlement_batches SET status = ?, updated_at = ? WHERE id = ?", batchStatus, now, batchID); err != nil {
		return err
	}
	if err := faudit.Append(ctx, tx, faudit.Entry{ActorUserID: actorID, ActorType: "STAFF", EntityType: "settlement_batch", EntityID: batchID, Action: "settlement.payout." + status,
		Changes: map[string]any{"amount": amount.String(), "attempt": attempt}, ReferenceID: key}); err != nil {
		return err
	}
	return tx.Commit()
}
