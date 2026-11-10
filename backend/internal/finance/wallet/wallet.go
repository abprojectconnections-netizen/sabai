// Package wallet is the Sabai Wallet ledger. In this phase it is a REFUND-CREDIT balance only: no top-up, transfer or withdrawal exists
// (DEC-08-09). Every change is an append-only ledger entry; the wallet row's balance is a cache of the latest entry.
package wallet

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/travel-super-app/backend/internal/finance/money"
)

var ErrInsufficient = errors.New("insufficient wallet balance")

type Entry struct {
	ID           string
	BalanceAfter money.Amount
	Replayed     bool
}

type Tx interface {
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
}

// Post appends a credit (amount > 0) or debit (amount < 0) in the caller's transaction. The wallet row is locked, so entries form
// one chain per wallet; the idempotency key makes a retry a no-op that returns the original entry.
func Post(ctx context.Context, tx Tx, userID string, txType, refType, refID string, amount money.Amount, idemKey, createdBy string) (Entry, error) {
	if amount == 0 {
		return Entry{}, errors.New("wallet: zero amount")
	}
	now := time.Now().UTC()
	if _, err := tx.ExecContext(ctx, "INSERT IGNORE INTO wallets (id, created_at, updated_at, user_id, currency_code, available_balance, pending_balance) VALUES (?, ?, ?, ?, 'THB', 0, 0)", uuid.NewString(), now, now, userID); err != nil {
		return Entry{}, err
	}
	var walletID, status string
	if err := tx.QueryRowContext(ctx, "SELECT id, status FROM wallets WHERE user_id = ? AND currency_code = 'THB' FOR UPDATE", userID).Scan(&walletID, &status); err != nil {
		return Entry{}, err
	}
	if status != "ACTIVE" {
		return Entry{}, errors.New("wallet is not active")
	}
	var prevID sql.NullString
	var bal string
	err := tx.QueryRowContext(ctx, "SELECT id, balance_after FROM wallet_ledger_entries WHERE wallet_id = ? AND idempotency_key = ?", walletID, idemKey).Scan(&prevID, &bal)
	if err == nil {
		b, _ := money.Parse(bal)
		return Entry{ID: prevID.String, BalanceAfter: b, Replayed: true}, nil
	} else if err != sql.ErrNoRows {
		return Entry{}, err
	}
	prevID, bal = sql.NullString{}, "0.00"
	err = tx.QueryRowContext(ctx, "SELECT id, balance_after FROM wallet_ledger_entries WHERE wallet_id = ? ORDER BY seq DESC LIMIT 1", walletID).Scan(&prevID, &bal)
	if err != nil && err != sql.ErrNoRows {
		return Entry{}, err
	}
	cur, _ := money.Parse(bal)
	next := cur + amount
	if next < 0 {
		return Entry{}, ErrInsufficient
	}
	credit, debit := amount, money.Amount(0)
	if amount < 0 {
		credit, debit = 0, -amount
	}
	id := uuid.NewString()
	var prev any
	if prevID.Valid {
		prev = prevID.String
	}
	if _, err := tx.ExecContext(ctx, `INSERT INTO wallet_ledger_entries (id, created_at, wallet_id, user_id, transaction_type, reference_type, reference_id, credit_amount, debit_amount, balance_after, currency_code, created_by, idempotency_key, prev_entry_id)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'THB', NULLIF(?, ''), ?, ?)`, id, now, walletID, userID, txType, refType, refID, credit.String(), debit.String(), next.String(), createdBy, idemKey, prev); err != nil {
		return Entry{}, err
	}
	if _, err := tx.ExecContext(ctx, "UPDATE wallets SET available_balance = ?, updated_at = ? WHERE id = ?", next.String(), now, walletID); err != nil {
		return Entry{}, err
	}
	return Entry{ID: id, BalanceAfter: next}, nil
}
