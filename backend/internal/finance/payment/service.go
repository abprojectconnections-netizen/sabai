// Package payment creates payment intents from server-side booking totals and applies provider webhooks.
// Payment status changes ONLY through a verified webhook (or a PSP status query in the reconciler); no staff endpoint can set it.
package payment

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/travel-super-app/backend/internal/finance/faudit"
	"github.com/travel-super-app/backend/internal/finance/money"
	"github.com/travel-super-app/backend/internal/finance/safety"
	"github.com/travel-super-app/backend/internal/platform/dberr"
)

const ReplayWindow = 5 * time.Minute

var (
	ErrNotFound    = errors.New("booking not found")
	ErrNotPayable  = errors.New("booking is not awaiting payment")
	ErrBadMethod   = errors.New("unsupported payment method")
	ErrBookingGone = errors.New("booking payment window has expired")
)

type Service struct {
	db       *sql.DB
	provider Provider
	cfg      safety.Config
	now      func() time.Time
}

func NewService(db *sql.DB, p Provider, cfg safety.Config) *Service {
	return &Service{db: db, provider: p, cfg: cfg, now: time.Now}
}

type Intent struct {
	ID, PaymentID, Reference, Status, Method, Currency, QR string
	Amount                                                 money.Amount
	ExpiresAt                                              time.Time
	Replayed                                               bool
}

// CreateIntent charges exactly the booking's stored total. The client sends no amount.
func (s *Service) CreateIntent(ctx context.Context, userID, bookingID, method, idemKey, requestID, ip string) (Intent, error) {
	if err := s.cfg.Check(ctx, s.db); err != nil {
		return Intent{}, err
	}
	if method != "PROMPTPAY_QR" && method != "CARD" {
		return Intent{}, ErrBadMethod
	}
	if idemKey == "" || len(idemKey) > 100 {
		return Intent{}, errors.New("Idempotency-Key header is required")
	}
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Intent{}, err
	}
	defer tx.Rollback()

	var in Intent
	var amt string
	err = tx.QueryRowContext(ctx, `SELECT i.id, p.id, i.payment_reference, i.status, i.method, i.currency_code, i.amount, i.expires_at FROM payment_intents i JOIN payments p ON p.payment_intent_id = i.id AND p.leg_no = 1
		WHERE i.user_id = ? AND i.idempotency_key = ?`, userID, idemKey).Scan(&in.ID, &in.PaymentID, &in.Reference, &in.Status, &in.Method, &in.Currency, &amt, &in.ExpiresAt)
	if err == nil {
		in.Amount, _ = money.Parse(amt)
		in.Replayed = true
		in.QR = "MOCK-QR:" + in.Reference + ":" + in.Amount.String()
		return in, nil
	} else if err != sql.ErrNoRows {
		return Intent{}, err
	}

	var status, total, currency string
	var owner string
	var expires sql.NullTime
	err = tx.QueryRowContext(ctx, "SELECT user_id, status, total_amount, currency_code, expires_at FROM bookings WHERE id = ? FOR UPDATE", bookingID).Scan(&owner, &status, &total, &currency, &expires)
	if err == sql.ErrNoRows || (err == nil && owner != userID) {
		return Intent{}, ErrNotFound // never reveal another user's booking
	} else if err != nil {
		return Intent{}, err
	}
	if status != "PENDING_PAYMENT" {
		return Intent{}, ErrNotPayable
	}
	now := s.now().UTC()
	if expires.Valid && expires.Time.Before(now) {
		return Intent{}, ErrBookingGone
	}
	amount, _ := money.Parse(total)
	var live int
	if err := tx.QueryRowContext(ctx, "SELECT COUNT(*) FROM payment_intents WHERE booking_id = ? AND status IN ('PENDING','PROCESSING','SUCCEEDED')", bookingID).Scan(&live); err != nil {
		return Intent{}, err
	}
	if live > 0 {
		return Intent{}, ErrNotPayable // one live payment attempt per booking; a new one needs the previous to fail or expire
	}
	ref := "PAY-" + uuid.NewString()
	charge, err := s.provider.CreateCharge(ctx, ChargeRequest{Reference: ref, Amount: amount, Currency: currency, Method: method})
	if err != nil {
		return Intent{}, err
	}
	in = Intent{ID: uuid.NewString(), PaymentID: uuid.NewString(), Reference: ref, Status: "PENDING", Method: method, Currency: currency, Amount: amount, QR: charge.QRPayload, ExpiresAt: now.Add(15 * time.Minute)}
	if _, err := tx.ExecContext(ctx, `INSERT INTO payment_intents (id, created_at, updated_at, booking_id, user_id, provider, payment_reference, provider_intent_id, amount, currency_code, method, status, expires_at, idempotency_key)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'PENDING', ?, ?)`, in.ID, now, now, bookingID, userID, s.provider.Code(), ref, charge.ProviderIntentID, amount.String(), currency, method, in.ExpiresAt, idemKey); err != nil {
		return Intent{}, err
	}
	if _, err := tx.ExecContext(ctx, `INSERT INTO payments (id, created_at, updated_at, booking_id, user_id, provider, provider_reference, amount, currency_code, status, payment_intent_id, leg_no)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'PENDING', ?, 1)`, in.PaymentID, now, now, bookingID, userID, s.provider.Code(), ref, amount.String(), currency, in.ID); err != nil {
		return Intent{}, err
	}
	if err := faudit.Append(ctx, tx, faudit.Entry{ActorUserID: userID, ActorType: "USER", EntityType: "payment", EntityID: in.PaymentID, Action: "payment.intent.created",
		Changes: map[string]any{"amount": amount.String(), "method": method, "booking_id": bookingID}, RequestID: requestID, IP: ip}); err != nil {
		return Intent{}, err
	}
	return in, tx.Commit()
}

type WebhookResult string

const (
	Applied           WebhookResult = "APPLIED"
	IgnoredDuplicate  WebhookResult = "IGNORED_DUPLICATE"
	RejectedSignature WebhookResult = "REJECTED_SIGNATURE"
	RejectedReplay    WebhookResult = "REJECTED_REPLAY"
	RejectedUnknown   WebhookResult = "REJECTED_UNKNOWN"
	Failed            WebhookResult = "FAILED"
)

// HandleWebhook verifies, de-duplicates and applies a provider event. It is idempotent: the unique key on
// (provider, event_id) makes a duplicate delivery harmless, and the payment row is locked while it is applied.
func (s *Service) HandleWebhook(ctx context.Context, signature string, body []byte) (WebhookResult, error) {
	ev, err := s.provider.VerifyAndParse(signature, body)
	if err != nil {
		if errors.Is(err, ErrBadSignature) {
			return RejectedSignature, nil
		}
		return Failed, err
	}
	now := s.now().UTC()
	if d := now.Sub(ev.Timestamp); d > ReplayWindow || d < -ReplayWindow {
		_ = s.record(ctx, ev, body, true, RejectedReplay)
		return RejectedReplay, nil
	}
	sum := sha256.Sum256(body)
	evID := uuid.NewString()
	// The event row and its effects commit together. If applying fails, nothing is stored, so the provider's retry of the
	// same event is processed instead of being swallowed as a "duplicate".
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Failed, err
	}
	defer tx.Rollback()
	_, err = tx.ExecContext(ctx, `INSERT INTO payment_webhook_events (id, created_at, provider, event_id, signature_valid, event_timestamp, received_at, payload_hash) VALUES (?, ?, ?, ?, 1, ?, ?, ?)`,
		evID, now, s.provider.Code(), ev.ID, ev.Timestamp, now, hex.EncodeToString(sum[:]))
	if err != nil {
		if isDup(err) {
			return IgnoredDuplicate, nil
		}
		return Failed, err
	}
	res, err := s.apply(ctx, tx, ev)
	if err != nil {
		return Failed, err
	}
	if _, err := tx.ExecContext(ctx, "UPDATE payment_webhook_events SET processed_at = ?, processing_result = ? WHERE id = ?", s.now().UTC(), string(res), evID); err != nil {
		return Failed, err
	}
	if err := tx.Commit(); err != nil {
		return Failed, err
	}
	return res, nil
}

func (s *Service) record(ctx context.Context, ev Event, body []byte, sigOK bool, r WebhookResult) error {
	sum := sha256.Sum256(body)
	_, err := s.db.ExecContext(ctx, `INSERT IGNORE INTO payment_webhook_events (id, created_at, provider, event_id, signature_valid, event_timestamp, received_at, payload_hash, processed_at, processing_result)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`, uuid.NewString(), s.now().UTC(), s.provider.Code(), ev.ID, sigOK, ev.Timestamp, s.now().UTC(), hex.EncodeToString(sum[:]), s.now().UTC(), string(r))
	return err
}

func (s *Service) apply(ctx context.Context, tx *sql.Tx, ev Event) (WebhookResult, error) {
	var paymentID, intentID, bookingID, status, amt, currency string
	err := tx.QueryRowContext(ctx, `SELECT p.id, p.payment_intent_id, p.booking_id, p.status, p.amount, p.currency_code FROM payments p WHERE p.provider = ? AND p.provider_reference = ? FOR UPDATE`, s.provider.Code(), ev.PaymentReference).
		Scan(&paymentID, &intentID, &bookingID, &status, &amt, &currency)
	if err == sql.ErrNoRows {
		return RejectedUnknown, nil
	} else if err != nil {
		return Failed, err
	}
	expected, _ := money.Parse(amt)
	now := s.now().UTC()
	switch ev.Type {
	case "CHARGE_SUCCEEDED":
		if ev.Amount != expected || ev.Currency != currency {
			// A mismatch is never applied; it is recorded for staff and reconciliation.
			if err := faudit.Append(ctx, tx, faudit.Entry{ActorType: "WEBHOOK", EntityType: "payment", EntityID: paymentID, Action: "payment.webhook.amount_mismatch",
				Changes: map[string]any{"expected": expected.String(), "reported": ev.Amount.String(), "currency": ev.Currency}, ReferenceID: ev.ID}); err != nil {
				return Failed, err
			}
			return RejectedUnknown, nil
		}
		if status != "PENDING" && status != "PROCESSING" {
			return IgnoredDuplicate, nil // already final
		}
		var bstatus string
		if err := tx.QueryRowContext(ctx, "SELECT status FROM bookings WHERE id = ? FOR UPDATE", bookingID).Scan(&bstatus); err != nil {
			return Failed, err
		}
		if _, err := tx.ExecContext(ctx, "UPDATE payments SET status = 'SUCCEEDED', captured_amount = amount, succeeded_at = ?, updated_at = ? WHERE id = ?", now, now, paymentID); err != nil {
			return Failed, err
		}
		if _, err := tx.ExecContext(ctx, "UPDATE payment_intents SET status = 'SUCCEEDED', updated_at = ? WHERE id = ?", now, intentID); err != nil {
			return Failed, err
		}
		if _, err := tx.ExecContext(ctx, "INSERT INTO payment_transactions (id, created_at, payment_id, provider, external_id, event_type, amount, currency_code, status) VALUES (?, ?, ?, ?, ?, 'CHARGE', ?, ?, 'SUCCEEDED')",
			uuid.NewString(), now, paymentID, s.provider.Code(), ev.ID, ev.Amount.String(), currency); err != nil {
			return Failed, err
		}
		if bstatus == "PENDING_PAYMENT" {
			if err := s.moveBooking(ctx, tx, bookingID, "PENDING_PAYMENT", "PAID", "payment confirmed by provider", now); err != nil {
				return Failed, err
			}
			// inventory hold becomes a sale
			if _, err := tx.ExecContext(ctx, "UPDATE inventory_holds SET status = 'CONSUMED', updated_at = ? WHERE booking_id = ? AND status = 'HELD'", now, bookingID); err != nil {
				return Failed, err
			}
		} else {
			// Paid after the window closed (hold already released): money is in, booking is not. Flag for staff, do not resurrect.
			if err := faudit.Append(ctx, tx, faudit.Entry{ActorType: "WEBHOOK", EntityType: "payment", EntityID: paymentID, Action: "payment.late_success", Reason: "booking was " + bstatus, ReferenceID: ev.ID}); err != nil {
				return Failed, err
			}
		}
		if err := faudit.Append(ctx, tx, faudit.Entry{ActorType: "WEBHOOK", EntityType: "payment", EntityID: paymentID, Action: "payment.succeeded", Changes: map[string]any{"amount": expected.String()}, ReferenceID: ev.ID}); err != nil {
			return Failed, err
		}
	case "CHARGE_FAILED":
		if status != "PENDING" && status != "PROCESSING" {
			return IgnoredDuplicate, nil
		}
		if _, err := tx.ExecContext(ctx, "UPDATE payments SET status = 'FAILED', updated_at = ? WHERE id = ?", now, paymentID); err != nil {
			return Failed, err
		}
		if _, err := tx.ExecContext(ctx, "UPDATE payment_intents SET status = 'FAILED', updated_at = ? WHERE id = ?", now, intentID); err != nil {
			return Failed, err
		}
		if err := faudit.Append(ctx, tx, faudit.Entry{ActorType: "WEBHOOK", EntityType: "payment", EntityID: paymentID, Action: "payment.failed", ReferenceID: ev.ID}); err != nil {
			return Failed, err
		}
	default:
		return RejectedUnknown, nil
	}
	return Applied, nil
}

func (s *Service) moveBooking(ctx context.Context, tx *sql.Tx, id, from, to, reason string, now time.Time) error {
	if _, err := tx.ExecContext(ctx, "UPDATE bookings SET status = ?, updated_at = ? WHERE id = ? AND status = ?", to, now, id, from); err != nil {
		return err
	}
	_, err := tx.ExecContext(ctx, "INSERT INTO booking_status_histories (id, created_at, booking_id, from_status, to_status, actor_type, reason) VALUES (?, ?, ?, ?, ?, 'WEBHOOK', ?)", uuid.NewString(), now, id, from, to, reason)
	return err
}

func isDup(err error) bool { return dberr.IsDuplicate(err) }
