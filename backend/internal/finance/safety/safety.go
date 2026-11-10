// Package safety holds the switches that keep real money from moving until every go-live gate is approved (design 0002 section 6).
package safety

import (
	"context"
	"database/sql"
	"errors"
	"os"
)

// Config is read once at start-up. Defaults are the SAFE values.
type Config struct {
	PaymentProvider string // "mock" (default) | a real PSP code once approved
	SupplierMode    string // "mock" (default) | "sandbox" | "live"
	Enabled         bool   // FINANCIAL_TRANSACTIONS_ENABLED, default false
	Environment     string // "dev" (default) | "beta" | "prod"
}

func FromEnv() Config {
	get := func(k, d string) string {
		if v := os.Getenv(k); v != "" {
			return v
		}
		return d
	}
	return Config{
		PaymentProvider: get("PAYMENT_PROVIDER", "mock"),
		SupplierMode:    get("SUPPLIER_MODE", "mock"),
		Enabled:         os.Getenv("FINANCIAL_TRANSACTIONS_ENABLED") == "true",
		Environment:     get("APP_ENV", "dev"),
	}
}

var (
	ErrDisabled   = errors.New("financial transactions are disabled")
	ErrNotAllowed = errors.New("a non-mock provider requires all go-live approvals")
)

// RequiredApprovals are the gates that must be recorded in go_live_approvals before a real provider may be used.
var RequiredApprovals = []string{"PSP", "LEGAL", "ACCOUNTING", "SECURITY"}

// Check refuses to proceed when financial transactions are off, and refuses any non-mock provider or live supplier
// unless every go-live approval exists. The mock provider is always allowed (it moves no money).
func (c Config) Check(ctx context.Context, db *sql.DB) error {
	if !c.Enabled {
		return ErrDisabled
	}
	if c.PaymentProvider == "mock" && c.SupplierMode != "live" {
		return nil
	}
	for _, t := range RequiredApprovals {
		var n int
		if err := db.QueryRowContext(ctx, "SELECT COUNT(*) FROM go_live_approvals WHERE approval_type = ?", t).Scan(&n); err != nil {
			return err
		}
		if n == 0 {
			return ErrNotAllowed
		}
	}
	return nil
}
