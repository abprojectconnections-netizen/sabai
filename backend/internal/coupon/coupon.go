// Package coupon lists and saves coupons for a user. The coupons and their discount rules live in the existing coupons/discounts
// tables (migration 000007) and are applied by the booking service when a booking request carries coupon_code.
// This package never changes a price: saving a coupon only adds it to the user's list.
package coupon

import (
	"context"
	"database/sql"
	"errors"
	"regexp"
	"strings"

	"github.com/google/uuid"
	"github.com/travel-super-app/backend/internal/platform/dberr"
	"github.com/travel-super-app/backend/internal/platform/dbtime"
)

var (
	ErrNotFound   = errors.New("coupon not found")
	ErrExpired    = errors.New("coupon has expired")
	ErrNotStarted = errors.New("coupon is not valid yet")
	ErrExhausted  = errors.New("coupon has been fully redeemed")
	ErrDuplicate  = errors.New("coupon already saved")
	ErrValidation = errors.New("validation error")
)

var codeRe = regexp.MustCompile(`^[A-Za-z0-9_-]{1,40}$`)

const (
	StateActive      = "ACTIVE"
	StateExpired     = "EXPIRED"
	StateNotStarted  = "NOT_STARTED"
	StateExhausted   = "EXHAUSTED"
	StateUnavailable = "UNAVAILABLE"
)

// Coupon is one saved coupon. Dates are UTC calendar dates (YYYY-MM-DD) or empty; value is a decimal string.
type Coupon struct {
	Code         string `json:"code"`
	Title        string `json:"title"`         // promotion name when the coupon has one
	DiscountType string `json:"discount_type"` // FIXED | PERCENT | "" when the coupon has no discount rule
	Value        string `json:"value"`
	ValidFrom    string `json:"valid_from"`
	ValidUntil   string `json:"valid_until"`
	State        string `json:"state"`
	SavedAt      string `json:"saved_at,omitempty"`
}

type row struct {
	id                       string
	c                        Coupon
	discountStatus           sql.NullString
	from, until, expires     sql.NullString // "YYYY-MM-DD HH:MM:SS" UTC
	maxRedemptions, redeemed sql.NullInt64
	couponDeleted            bool
}

const ts = "'%Y-%m-%d %H:%i:%s'"

const selectCols = `c.id, c.code, COALESCE(p.name, ''), COALESCE(d.discount_type, ''), COALESCE(CAST(d.value AS CHAR), ''),
	d.status, DATE_FORMAT(d.valid_from, ` + ts + `), DATE_FORMAT(d.valid_to, ` + ts + `), DATE_FORMAT(c.expires_at, ` + ts + `),
	c.max_redemptions, c.redeemed_count, c.deleted_at IS NOT NULL`

const fromJoin = ` FROM coupons c LEFT JOIN discounts d ON d.id = c.discount_id LEFT JOIN promotions p ON p.id = c.promotion_id AND p.deleted_at IS NULL`

func (r *row) scan(sc interface{ Scan(...any) error }, extra ...any) error {
	return sc.Scan(append([]any{&r.id, &r.c.Code, &r.c.Title, &r.c.DiscountType, &r.c.Value, &r.discountStatus, &r.from, &r.until, &r.expires, &r.maxRedemptions, &r.redeemed, &r.couponDeleted}, extra...)...)
}

func day(v sql.NullString) string {
	if v.Valid && len(v.String) >= 10 {
		return v.String[:10]
	}
	return ""
}

// finish fills the display dates and the state ("now" is a UTC "YYYY-MM-DD HH:MM:SS").
func (r *row) finish(now string) {
	r.c.ValidFrom = day(r.from)
	// The effective end is the earlier of the discount's end and the coupon's own expiry.
	until := r.until
	if r.expires.Valid && (!until.Valid || r.expires.String < until.String) {
		until = r.expires
	}
	r.c.ValidUntil = day(until)
	switch {
	case r.couponDeleted || !r.discountStatus.Valid || r.discountStatus.String != "ACTIVE":
		r.c.State = StateUnavailable
	case until.Valid && until.String < now:
		r.c.State = StateExpired
	case r.from.Valid && r.from.String > now:
		r.c.State = StateNotStarted
	case r.maxRedemptions.Valid && r.redeemed.Int64 >= r.maxRedemptions.Int64:
		r.c.State = StateExhausted
	default:
		r.c.State = StateActive
	}
}

func nowUTC() string { return dbtime.Now().Format("2006-01-02 15:04:05") }

type Service struct{ db *sql.DB }

func NewService(db *sql.DB) *Service { return &Service{db: db} }

// Claim saves a coupon code for the user. Codes match case-insensitively.
func (s *Service) Claim(ctx context.Context, userID, code string) error {
	code = strings.TrimSpace(code)
	if !codeRe.MatchString(code) {
		return errors.Join(ErrValidation, errors.New("code must be 1-40 characters: letters, digits, '-' or '_'"))
	}
	var r row
	if err := r.scan(s.db.QueryRowContext(ctx, "SELECT "+selectCols+fromJoin+" WHERE c.code = ?", code)); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return ErrNotFound
		}
		return err
	}
	r.finish(nowUTC())
	switch r.c.State {
	case StateUnavailable:
		return ErrNotFound // disabled or rule-less coupons look the same as unknown ones
	case StateExpired:
		return ErrExpired
	case StateNotStarted:
		return ErrNotStarted
	case StateExhausted:
		return ErrExhausted
	}
	if _, err := s.db.ExecContext(ctx, "INSERT INTO user_coupons (id, created_at, user_id, coupon_id) VALUES (?, ?, ?, ?)", uuid.NewString(), dbtime.Now(), userID, r.id); err != nil {
		if dberr.IsDuplicate(err) {
			return ErrDuplicate
		}
		return err
	}
	return nil
}

// Mine lists the user's saved coupons, newest first, each with its current state.
func (s *Service) Mine(ctx context.Context, userID string, limit, offset int) ([]Coupon, error) {
	rows, err := s.db.QueryContext(ctx, "SELECT "+selectCols+", DATE_FORMAT(uc.created_at, "+dbtime.SQLDateTime+")"+
		fromJoin+" JOIN user_coupons uc ON uc.coupon_id = c.id WHERE uc.user_id = ? ORDER BY uc.created_at DESC, uc.id LIMIT ? OFFSET ?", userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	now := nowUTC()
	out := []Coupon{}
	for rows.Next() {
		var r row
		var saved string
		if err := r.scan(rows, &saved); err != nil {
			return nil, err
		}
		r.c.SavedAt = saved
		r.finish(now)
		out = append(out, r.c)
	}
	return out, rows.Err()
}
