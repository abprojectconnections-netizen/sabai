// Package reconcile compares a payment provider's statement with our payment_transactions for a period (design 0002, 8.12).
// It only records findings; it never changes money state. Findings other than MATCHED need a human to resolve them.
package reconcile

import (
	"context"
	"database/sql"
	"errors"
	"sort"
	"time"

	"github.com/google/uuid"
	"github.com/travel-super-app/backend/internal/finance/faudit"
	"github.com/travel-super-app/backend/internal/finance/money"
	"github.com/travel-super-app/backend/internal/finance/txopt"
)

// Line is one row of the provider's statement.
type Line struct {
	ExternalID string
	EventType  string // CHARGE | REFUND | VOID | CHARGEBACK
	Amount     money.Amount
}

type Summary struct {
	ID                                              string
	Matched, Mismatch, MissingProvider, MissingOurs int
}

// Unresolved is the number of findings that need a person.
func (s Summary) Unresolved() int { return s.Mismatch + s.MissingProvider + s.MissingOurs }

var ErrPeriod = errors.New("period_to must be after period_from")

type Service struct {
	db  *sql.DB
	now func() time.Time
}

func NewService(db *sql.DB) *Service { return &Service{db: db, now: time.Now} }

type key struct{ ext, typ string }

func subjectType(eventType string) string {
	if eventType == "REFUND" {
		return "REFUND"
	}
	return "PAYMENT"
}

// Run reconciles [from, to) for one provider. statementRef names the source file (kept for audit). runBy may be empty (scheduled run).
func (s *Service) Run(ctx context.Context, provider, statementRef, runBy string, from, to time.Time, statement []Line) (Summary, error) {
	if !to.After(from) {
		return Summary{}, ErrPeriod
	}
	tx, err := s.db.BeginTx(ctx, txopt.Financial)
	if err != nil {
		return Summary{}, err
	}
	defer tx.Rollback()

	ours := map[key]struct {
		amount money.Amount
		pay    string
	}{}
	rows, err := tx.QueryContext(ctx, "SELECT external_id, event_type, amount, payment_id FROM payment_transactions WHERE provider = ? AND created_at >= ? AND created_at < ?", provider, from.UTC(), to.UTC())
	if err != nil {
		return Summary{}, err
	}
	for rows.Next() {
		var ext, typ, amt, pay string
		if err := rows.Scan(&ext, &typ, &amt, &pay); err != nil {
			rows.Close()
			return Summary{}, err
		}
		a, err := money.Parse(amt)
		if err != nil {
			rows.Close()
			return Summary{}, err
		}
		ours[key{ext, typ}] = struct {
			amount money.Amount
			pay    string
		}{a, pay}
	}
	rows.Close()

	rid := uuid.NewString()
	now := s.now().UTC()
	var nullRunBy any
	if runBy != "" {
		nullRunBy = runBy
	}
	if _, err := tx.ExecContext(ctx, "INSERT INTO payment_reconciliations (id, created_at, provider, period_from, period_to, source_file_ref, status, run_by) VALUES (?,?,?,?,?,?, 'RUNNING', ?)",
		rid, now, provider, from.UTC(), to.UTC(), statementRef, nullRunBy); err != nil {
		return Summary{}, err
	}
	sum := Summary{ID: rid}
	rec := func(subType string, subjectID any, provAmt, ourAmt any, result string) error {
		_, err := tx.ExecContext(ctx, "INSERT INTO financial_reconciliation_records (id, created_at, reconciliation_id, subject_type, subject_id, provider_amount, our_amount, result) VALUES (?,?,?,?,?,?,?,?)",
			uuid.NewString(), now, rid, subType, subjectID, provAmt, ourAmt, result)
		return err
	}
	seen := map[key]bool{}
	for _, l := range statement {
		k := key{l.ExternalID, l.EventType}
		if seen[k] {
			continue // a duplicated statement line is not a second payment
		}
		seen[k] = true
		o, ok := ours[k]
		switch {
		case !ok:
			sum.MissingOurs++
			err = rec(subjectType(l.EventType), nil, l.Amount.String(), nil, "MISSING_OURS")
		case o.amount != l.Amount:
			sum.Mismatch++
			err = rec(subjectType(l.EventType), o.pay, l.Amount.String(), o.amount.String(), "AMOUNT_MISMATCH")
		default:
			sum.Matched++
			err = rec(subjectType(l.EventType), o.pay, l.Amount.String(), o.amount.String(), "MATCHED")
		}
		if err != nil {
			return Summary{}, err
		}
	}
	var missing []key
	for k := range ours {
		if !seen[k] {
			missing = append(missing, k)
		}
	}
	sort.Slice(missing, func(i, j int) bool { return missing[i].ext < missing[j].ext })
	for _, k := range missing {
		o := ours[k]
		sum.MissingProvider++
		if err := rec(subjectType(k.typ), o.pay, nil, o.amount.String(), "MISSING_PROVIDER"); err != nil {
			return Summary{}, err
		}
	}
	if _, err := tx.ExecContext(ctx, "UPDATE payment_reconciliations SET status = 'COMPLETED', matched_count = ?, unmatched_count = ? WHERE id = ?", sum.Matched, sum.Unresolved(), rid); err != nil {
		return Summary{}, err
	}
	actorType := "SYSTEM"
	if runBy != "" {
		actorType = "STAFF"
	}
	if err := faudit.Append(ctx, tx, faudit.Entry{ActorUserID: runBy, ActorType: actorType, EntityType: "payment_reconciliation", EntityID: rid, Action: "reconciliation.completed",
		Changes: map[string]any{"provider": provider, "matched": sum.Matched, "unresolved": sum.Unresolved()}}); err != nil {
		return Summary{}, err
	}
	return sum, tx.Commit()
}
