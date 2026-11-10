// Command reconcile compares a provider statement (CSV: external_id,event_type,amount) with our payment records.
// Usage: reconcile -provider mock -from 2026-11-01 -to 2026-11-08 -file statement.csv   (period is [from, to), UTC)
// It records findings only; exit status 2 means there are unresolved findings that need a person.
package main

import (
	"context"
	"encoding/csv"
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	"github.com/travel-super-app/backend/internal/finance/money"
	"github.com/travel-super-app/backend/internal/finance/reconcile"
	"github.com/travel-super-app/backend/internal/platform/database"
)

func main() {
	provider := flag.String("provider", "", "provider code")
	fromS := flag.String("from", "", "YYYY-MM-DD (inclusive)")
	toS := flag.String("to", "", "YYYY-MM-DD (exclusive)")
	file := flag.String("file", "", "statement CSV")
	flag.Parse()
	from, e1 := time.Parse("2006-01-02", *fromS)
	to, e2 := time.Parse("2006-01-02", *toS)
	if *provider == "" || *file == "" || e1 != nil || e2 != nil {
		log.Fatal("-provider, -file, -from and -to (YYYY-MM-DD) are required")
	}
	f, err := os.Open(*file)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()
	recs, err := csv.NewReader(f).ReadAll()
	if err != nil {
		log.Fatalf("read statement: %v", err)
	}
	var lines []reconcile.Line
	for i, r := range recs {
		if i == 0 && len(r) > 0 && r[0] == "external_id" {
			continue
		}
		if len(r) != 3 {
			log.Fatalf("line %d: expected external_id,event_type,amount", i+1)
		}
		a, err := money.Parse(r[2])
		if err != nil {
			log.Fatalf("line %d: %v", i+1, err)
		}
		lines = append(lines, reconcile.Line{ExternalID: r[0], EventType: r[1], Amount: a})
	}
	dsn := os.Getenv("MYSQL_DSN")
	if dsn == "" {
		log.Fatal("MYSQL_DSN is required")
	}
	db, err := database.Open(dsn)
	if err != nil {
		log.Fatalf("connect to MySQL: %v", err)
	}
	defer db.Close()
	s, err := reconcile.NewService(db).Run(context.Background(), *provider, filepath.Base(*file), "", from, to, lines)
	if err != nil {
		log.Fatalf("reconcile: %v", err)
	}
	fmt.Printf("reconciliation %s: matched=%d amount_mismatch=%d missing_ours=%d missing_provider=%d\n", s.ID, s.Matched, s.Mismatch, s.MissingOurs, s.MissingProvider)
	if s.Unresolved() > 0 {
		os.Exit(2)
	}
}
