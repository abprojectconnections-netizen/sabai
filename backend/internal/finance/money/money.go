// Package money holds all money arithmetic. Amounts are integer minor units (satang for THB), never floats.
// Money is computed on the server only; the client never supplies a price, total, discount or fee.
package money

import (
	"errors"
	"fmt"
	"strings"
)

// Amount is an amount in minor units (1 THB = 100). Negative values are allowed for reversals.
type Amount int64

var ErrFormat = errors.New("money: invalid decimal amount")

// Parse reads a decimal string with at most two fraction digits ("1234", "1234.5", "1234.50", "-5.00").
func Parse(s string) (Amount, error) {
	s = strings.TrimSpace(s)
	neg := strings.HasPrefix(s, "-")
	s = strings.TrimPrefix(s, "-")
	whole, frac, _ := strings.Cut(s, ".")
	if whole == "" || len(frac) > 2 {
		return 0, ErrFormat
	}
	for _, r := range whole + frac {
		if r < '0' || r > '9' {
			return 0, ErrFormat
		}
	}
	for len(frac) < 2 {
		frac += "0"
	}
	var w int64
	if _, err := fmt.Sscanf(whole, "%d", &w); err != nil || w > 9_000_000_000_000 {
		return 0, ErrFormat
	}
	var f int64
	fmt.Sscanf(frac, "%d", &f)
	a := Amount(w*100 + f)
	if neg {
		a = -a
	}
	return a, nil
}

// String formats as a DECIMAL(14,2) literal, e.g. "9500.00".
func (a Amount) String() string {
	sign := ""
	v := int64(a)
	if v < 0 {
		sign, v = "-", -v
	}
	return fmt.Sprintf("%s%d.%02d", sign, v/100, v%100)
}

// RateMicro is a rate scaled by 1,000,000 (0.05 = 50_000), matching DECIMAL(9,6).
type RateMicro int64

// ParseRate reads "0.050000" or "0.05" (at most six fraction digits).
func ParseRate(s string) (RateMicro, error) {
	whole, frac, _ := strings.Cut(strings.TrimSpace(s), ".")
	if whole == "" || len(frac) > 6 {
		return 0, ErrFormat
	}
	for len(frac) < 6 {
		frac += "0"
	}
	var w, f int64
	if _, err := fmt.Sscanf(whole, "%d", &w); err != nil {
		return 0, ErrFormat
	}
	if _, err := fmt.Sscanf(frac, "%d", &f); err != nil {
		return 0, ErrFormat
	}
	return RateMicro(w*1_000_000 + f), nil
}

// Percent returns amount*rate rounded half away from zero to the minor unit, identical to MySQL ROUND(base*rate, 2).
func Percent(a Amount, r RateMicro) Amount {
	n := int64(a) * int64(r)
	const d = 1_000_000
	if n >= 0 {
		return Amount((n + d/2) / d)
	}
	return Amount(-((-n + d/2) / d))
}
