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

// province lists the places the generated catalogue covers.
var provinces = []struct {
	name string
	tier float64 // price multiplier, so a beach resort costs more than a city guesthouse
}{{"เชียงใหม่", 1.0}, {"ภูเก็ต", 1.5}, {"กระบี่", 1.3}, {"เกาะสมุย", 1.6}, {"กรุงเทพฯ", 1.2}, {"พัทยา", 1.1}}

// flights are SIMULATED: fictional carriers and generated times/prices. They exist so the booking and sandbox payment flow can
// be exercised on a "flight" product; no airline or fare data is involved.
var carriers = []struct{ code, name string }{{"XA", "สายการบินตัวอย่าง A"}, {"XB", "สายการบินตัวอย่าง B"}, {"XC", "สายการบินตัวอย่าง C"}}

var airports = []struct {
	code, name string
	minutes    int
	base       float64
}{{"CNX", "เชียงใหม่", 75, 1700}, {"HKT", "ภูเก็ต", 90, 2300}, {"KBV", "กระบี่", 85, 2100}, {"USM", "เกาะสมุย", 80, 2700}}

var departures = []string{"07:00", "12:30", "18:15"}

func hash(s string) int {
	h := 7
	for _, c := range s {
		h = (h*31 + int(c)) & 0x7fffffff
	}
	return h
}

func money(v float64) string { return fmt.Sprintf("%.2f", float64(int(v/10+0.5))*10) }

func init() {
	for _, pv := range provinces {
		k := pv.name
		products = append(products,
			product{"hotel-eco-" + k, "HOTEL", "โรงแรมประหยัด " + k + " ห้องมาตรฐาน (ต่อคืน)", "HOTEL-ECO-" + k, money(900 * pv.tier), 15},
			product{"hotel-lux-" + k, "HOTEL", "รีสอร์ทหรู " + k + " ห้องสูท (ต่อคืน)", "HOTEL-LUX-" + k, money(3800 * pv.tier), 6},
			product{"tour-day-" + k, "TOUR", "ทัวร์หนึ่งวัน " + k + " พร้อมไกด์", "TOUR-DAY-" + k, money(1100 * pv.tier), 20},
			product{"ticket-" + k, "ATTRACTION", "บัตรเข้าชมแหล่งท่องเที่ยว " + k, "TICKET-" + k, money(300 * pv.tier), 80},
			product{"transfer-" + k, "TRANSPORT", "รถรับส่งสนามบิน " + k + " (ไม่เกิน 4 ที่นั่ง)", "TRF-" + k, money(600 * pv.tier), 12},
		)
	}
	for _, a := range airports {
		for _, dir := range []struct{ from, to string }{{"BKK", a.code}, {a.code, "BKK"}} {
			for i, c := range carriers {
				dep := departures[i]
				h := hash(c.code + dir.from + dir.to + dep)
				no := fmt.Sprintf("%s %d", c.code, 100+h%900)
				price := a.base * []float64{1.3, 1.0, 0.8}[i] * (1 + float64(h%15)/100)
				products = append(products, product{
					key: "flight-" + c.code + "-" + dir.from + dir.to, category: "FLIGHT",
					title: fmt.Sprintf("%s %s %s→%s ออก %s (เที่ยวบินจำลอง)", c.name, no, dir.from, dir.to, dep),
					sku:   "FLT-" + c.code + "-" + dir.from + dir.to, price: money(price), qty: 40,
				})
			}
		}
	}
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
	// demo coupon: promotion + platform-funded 10% discount + code SABAI10 (users can save it; the app does not apply it yet)
	promo, discount, coupon := id("promotion", "sabai10"), id("discount", "sabai10"), id("coupon", "sabai10")
	for _, s := range []struct {
		q    string
		args []any
	}{
		{"INSERT IGNORE INTO promotions (id, created_at, updated_at, name, status) VALUES (?, ?, ?, 'ส่วนลดต้อนรับ 10% (ข้อมูลทดสอบ)', 'ACTIVE')", []any{promo, now, now}},
		{"INSERT IGNORE INTO discounts (id, created_at, owner_type, discount_type, value, valid_from, valid_to, funded_by, status) VALUES (?, ?, 'PLATFORM', 'PERCENT', 10.00, ?, ?, 'PLATFORM', 'ACTIVE')", []any{discount, now, now.AddDate(0, 0, -1), now.AddDate(1, 0, 0)}},
		{"INSERT IGNORE INTO coupons (id, created_at, updated_at, promotion_id, code, discount_id) VALUES (?, ?, ?, ?, 'SABAI10', ?)", []any{coupon, now, now, promo, discount}},
	} {
		if _, err := tx.Exec(s.q, s.args...); err != nil {
			return err
		}
	}
	if err := seedExtras(tx, now); err != nil {
		return err
	}
	if err := tx.Commit(); err != nil {
		return err
	}
	fmt.Printf("seeded demo partner %s: %d products, %d new availability rows\n", partner, len(products), created)
	return nil
}

// seedExtras adds demo coupons in different states and a small community feed written by login-less demo members.
func seedExtras(tx *sql.Tx, now time.Time) error {
	coupons := []struct {
		code, name, typ, value string
		from, to               time.Time
	}{
		{"FLY200", "ลด 200 บาท (ข้อมูลทดสอบ)", "FIXED", "200.00", now.AddDate(0, 0, -1), now.AddDate(0, 6, 0)},
		{"OLD10", "คูปองหมดอายุ (ข้อมูลทดสอบ)", "PERCENT", "10.00", now.AddDate(-1, 0, 0), now.AddDate(0, 0, -30)},
		{"SOON5", "คูปองที่ยังไม่เริ่ม (ข้อมูลทดสอบ)", "PERCENT", "5.00", now.AddDate(0, 1, 0), now.AddDate(0, 3, 0)},
	}
	for _, c := range coupons {
		promo, discount, coupon := id("promotion", c.code), id("discount", c.code), id("coupon", c.code)
		for _, st := range []struct {
			q    string
			args []any
		}{
			{"INSERT IGNORE INTO promotions (id, created_at, updated_at, name, status) VALUES (?, ?, ?, ?, 'ACTIVE')", []any{promo, now, now, c.name}},
			{"INSERT IGNORE INTO discounts (id, created_at, owner_type, discount_type, value, valid_from, valid_to, funded_by, status) VALUES (?, ?, 'PLATFORM', ?, ?, ?, ?, 'PLATFORM', 'ACTIVE')", []any{discount, now, c.typ, c.value, c.from, c.to}},
			{"INSERT IGNORE INTO coupons (id, created_at, updated_at, promotion_id, code, discount_id) VALUES (?, ?, ?, ?, ?, ?)", []any{coupon, now, now, promo, c.code, discount}},
		} {
			if _, err := tx.Exec(st.q, st.args...); err != nil {
				return err
			}
		}
	}

	members := []struct{ key, first, last string }{{"m1", "สมหญิง", "ใจดี"}, {"m2", "ภูริช", "รักเที่ยว"}, {"m3", "ณัฐา", "ชอบทะเล"}}
	for _, m := range members {
		uid := id("member", m.key)
		if _, err := tx.Exec("INSERT IGNORE INTO users (id, created_at, updated_at, email, status) VALUES (?, ?, ?, ?, 'ACTIVE')", uid, now, now, m.key+"@members.sabai.example"); err != nil {
			return err
		}
		if _, err := tx.Exec("INSERT IGNORE INTO user_profiles (id, created_at, updated_at, user_id, first_name, last_name) VALUES (?, ?, ?, ?, ?, ?)", id("member-profile", m.key), now, now, uid, m.first, m.last); err != nil {
			return err
		}
	}
	posts := []struct {
		key, member, body string
		tags              []string
		hoursAgo          int
	}{
		{"p1", "m1", "เพิ่งไปเชียงใหม่มา คาเฟ่ย่านนิมมานเหมินท์บรรยากาศดีมาก แนะนำให้ไปช่วงเช้า คนยังไม่เยอะ (โพสต์ตัวอย่าง)", []string{"เชียงใหม่", "คาเฟ่"}, 30},
		{"p2", "m2", "ทัวร์เกาะวันเดียวที่ภูเก็ต น้ำใสมาก อย่าลืมครีมกันแดดและยากันเมา (โพสต์ตัวอย่าง)", []string{"ภูเก็ต", "ทะเล"}, 20},
		{"p3", "m3", "ใครเคยไปกระบี่หน้าฝนบ้าง ทะเลคลื่นแรงไหม อยากรู้ก่อนจองโรงแรม (โพสต์ตัวอย่าง)", []string{"กระบี่"}, 9},
		{"p4", "m1", "เทคนิคจองตั๋วเครื่องบิน: ดูหลายวันและเทียบเวลาออก บางวันถูกกว่าเกือบเท่าตัว (โพสต์ตัวอย่าง)", []string{"เคล็ดลับ"}, 3},
	}
	for _, p := range posts {
		pid := id("post", p.key)
		at := now.Add(-time.Duration(p.hoursAgo) * time.Hour)
		if _, err := tx.Exec("INSERT IGNORE INTO community_posts (id, created_at, updated_at, user_id, body) VALUES (?, ?, ?, ?, ?)", pid, at, at, id("member", p.member), p.body); err != nil {
			return err
		}
		for _, label := range p.tags {
			// slug equals the label for these Thai/lower-case words, matching what the tag API would store
			if _, err := tx.Exec("INSERT IGNORE INTO tags (id, created_at, updated_at, slug, label) VALUES (?, ?, ?, ?, ?)", id("tag", label), now, now, label, label); err != nil {
				return err
			}
			var tagID string
			if err := tx.QueryRow("SELECT id FROM tags WHERE slug = ?", label).Scan(&tagID); err != nil {
				return err
			}
			if _, err := tx.Exec("INSERT IGNORE INTO content_tags (id, created_at, tag_id, content_type, content_id, tagged_by) VALUES (?, ?, ?, 'COMMUNITY_POST', ?, ?)", id("ctag", p.key, label), now, tagID, pid, id("member", p.member)); err != nil {
				return err
			}
		}
	}
	return nil
}
