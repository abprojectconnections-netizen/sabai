// Command seed loads a small DEVELOPMENT catalogue (one approved demo partner, a few bookable items with availability for the next
// 90 days) so the web app can be exercised end to end against a local backend. It is idempotent (re-running only extends the dates).
// It refuses to run when APP_ENV is prod/production, and it never creates a login or any payment data.
//
//	MYSQL_DSN='travel:travel@tcp(127.0.0.1:3308)/travel_super_app?parseTime=true' go run ./cmd/seed -yes
package main

import (
	"database/sql"
	"flag"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/travel-super-app/backend/internal/platform/database"
)

type product struct {
	key, category, title, sku string
	price                     string
	qty                       int
}

var products = []product{
	{"tour-islands", "TOUR", "ทัวร์เกาะ 4 เกาะ พร้อมอาหารกลางวัน", "TOUR-4ISL", "1200.00", 20},
	{"hotel-beach", "HOTEL", "ห้องดีลักซ์ วิวทะเล (ต่อคืน)", "HOTEL-DLX", "2400.00", 8},
	{"attraction-ticket", "ATTRACTION", "บัตรเข้าชมสวนน้ำ", "TICKET-WP", "450.00", 100},
	{"transport-transfer", "TRANSPORT", "รถรับส่งสนามบิน (ไม่เกิน 4 ที่นั่ง)", "TRF-APT", "650.00", 12},
	{"tour-sold-out", "TOUR", "ทัวร์ดำน้ำ (ตัวอย่างที่เต็มแล้ว)", "TOUR-SOLD", "1800.00", 0},
}

// id derives a stable UUID so a re-run finds the same rows.
func id(parts ...string) string {
	return uuid.NewSHA1(uuid.NameSpaceOID, []byte("sabai-dev-seed|"+strings.Join(parts, "|"))).String()
}

func main() {
	yes := flag.Bool("yes", false, "confirm this is a development database")
	days := flag.Int("days", 90, "days of availability to create")
	flag.Parse()
	if e := strings.ToLower(os.Getenv("APP_ENV")); e == "prod" || e == "production" {
		log.Fatal("refusing to seed a production environment")
	}
	if !*yes {
		log.Fatal("this writes demo data; re-run with -yes on a development database")
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
	if err := seed(db, *days); err != nil {
		log.Fatalf("seed: %v", err)
	}
}

func seed(db *sql.DB, days int) error {
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	now := time.Now().UTC()
	owner, partner, supplier := id("owner"), id("partner"), id("supplier")
	// the owner has no password: nobody can log in as the demo partner
	steps := []struct {
		q    string
		args []any
	}{
		{"INSERT IGNORE INTO users (id, created_at, updated_at, email, status) VALUES (?, ?, ?, 'demo-partner@sabai.example', 'ACTIVE')", []any{owner, now, now}},
		{"INSERT IGNORE INTO partners (id, created_at, updated_at, owner_user_id, legal_name, status) VALUES (?, ?, ?, ?, 'ตัวอย่างทัวร์แอนด์เทรเวล (ข้อมูลทดสอบ)', 'APPROVED')", []any{partner, now, now, owner}},
		{"INSERT IGNORE INTO suppliers (id, created_at, updated_at, supplier_type, adapter_code) VALUES (?, ?, ?, 'INTERNAL', 'dev-seed')", []any{supplier, now, now}},
	}
	for _, s := range steps {
		if _, err := tx.Exec(s.q, s.args...); err != nil {
			return err
		}
	}
	// a re-run must find the supplier/partner that already exist, whatever ids an earlier run gave them
	if err := tx.QueryRow("SELECT id FROM partners WHERE owner_user_id = (SELECT id FROM users WHERE email = 'demo-partner@sabai.example')").Scan(&partner); err != nil {
		return err
	}
	if err := tx.QueryRow("SELECT id FROM suppliers WHERE adapter_code = 'dev-seed'").Scan(&supplier); err != nil {
		return err
	}
	created := 0
	for _, p := range products {
		spID, itemID := id("product", p.key), id("item", p.key)
		if _, err := tx.Exec("INSERT IGNORE INTO supplier_products (id, created_at, updated_at, supplier_id, partner_id, category, title, external_ref) VALUES (?, ?, ?, ?, ?, ?, ?, ?)", spID, now, now, supplier, partner, p.category, p.title, p.key); err != nil {
			return err
		}
		if _, err := tx.Exec("INSERT IGNORE INTO inventory_items (id, created_at, supplier_product_id, sku) VALUES (?, ?, ?, ?)", itemID, now, spID, p.sku); err != nil {
			return err
		}
		if err := tx.QueryRow("SELECT i.id FROM inventory_items i JOIN supplier_products sp ON sp.id = i.supplier_product_id WHERE sp.external_ref = ? AND sp.supplier_id = ?", p.key, supplier).Scan(&itemID); err != nil {
			return err
		}
		for d := 1; d <= days; d++ {
			date := now.AddDate(0, 0, d).Format("2006-01-02")
			r, err := tx.Exec("INSERT IGNORE INTO inventory_availability (id, created_at, updated_at, inventory_item_id, service_date, quantity_total, base_price) VALUES (?, ?, ?, ?, ?, ?, ?)", id("avail", p.key, date), now, now, itemID, date, p.qty, p.price)
			if err != nil {
				return err
			}
			if n, _ := r.RowsAffected(); n > 0 {
				created++
			}
		}
	}
	if err := tx.Commit(); err != nil {
		return err
	}
	fmt.Printf("seeded demo partner %s: %d products, %d new availability rows\n", partner, len(products), created)
	return nil
}
