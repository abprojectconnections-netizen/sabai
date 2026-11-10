package payment

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"time"

	"github.com/travel-super-app/backend/internal/finance/money"
)

// Event is a provider notification after signature verification. The provider is never trusted for the amount:
// the service compares it with what the database says was charged.
type Event struct {
	ID               string
	Type             string // CHARGE_SUCCEEDED | CHARGE_FAILED | REFUND_COMPLETED
	PaymentReference string
	Amount           money.Amount
	Currency         string
	Timestamp        time.Time
}

type ChargeRequest struct {
	Reference string
	Amount    money.Amount
	Currency  string
	Method    string
}

type ChargeResponse struct{ ProviderIntentID, QRPayload string }

var ErrBadSignature = errors.New("invalid webhook signature")

// Provider hides the PSP. The real one is chosen only after the PSP evaluation and go-live approvals (Section 8.8);
// until then only the mock exists and it moves no money.
type Provider interface {
	Code() string
	CreateCharge(ctx context.Context, r ChargeRequest) (ChargeResponse, error)
	// VerifyAndParse checks the signature over the raw body and parses it; it must not accept unsigned input.
	VerifyAndParse(signature string, body []byte) (Event, error)
	// Refund returns the provider's refund reference. The key makes a retry safe: the same key must never refund twice.
	Refund(ctx context.Context, paymentReference string, amount money.Amount, key string) (string, error)
	// Payout sends money to a partner bank account. Same idempotency rule.
	Payout(ctx context.Context, reference string, amount money.Amount, key string) (string, error)
}

// Mock is the development/test provider. Its webhook signature is HMAC-SHA256 over the raw body with a shared secret,
// the same shape most PSPs use, so the verification code path is exercised for real.
type Mock struct{ Secret string }

func (Mock) Code() string { return "mock" }

func (m Mock) CreateCharge(_ context.Context, r ChargeRequest) (ChargeResponse, error) {
	return ChargeResponse{ProviderIntentID: "mock_" + r.Reference, QRPayload: "MOCK-QR:" + r.Reference + ":" + r.Amount.String()}, nil
}

func (m Mock) Sign(body []byte) string {
	h := hmac.New(sha256.New, []byte(m.Secret))
	h.Write(body)
	return hex.EncodeToString(h.Sum(nil))
}

type mockBody struct {
	EventID   string `json:"event_id"`
	Type      string `json:"type"`
	Reference string `json:"payment_reference"`
	Amount    string `json:"amount"`
	Currency  string `json:"currency"`
	Timestamp int64  `json:"timestamp"`
}

func (m Mock) VerifyAndParse(signature string, body []byte) (Event, error) {
	if m.Secret == "" || !hmac.Equal([]byte(signature), []byte(m.Sign(body))) {
		return Event{}, ErrBadSignature
	}
	var b mockBody
	if err := json.Unmarshal(body, &b); err != nil || b.EventID == "" {
		return Event{}, errors.New("malformed webhook body")
	}
	amt, err := money.Parse(b.Amount)
	if err != nil {
		return Event{}, err
	}
	return Event{ID: b.EventID, Type: b.Type, PaymentReference: b.Reference, Amount: amt, Currency: b.Currency, Timestamp: time.Unix(b.Timestamp, 0).UTC()}, nil
}

func (Mock) Refund(_ context.Context, paymentReference string, _ money.Amount, key string) (string, error) {
	return "mock_refund_" + key, nil
}

func (Mock) Payout(_ context.Context, _ string, _ money.Amount, key string) (string, error) {
	return "mock_payout_" + key, nil
}
