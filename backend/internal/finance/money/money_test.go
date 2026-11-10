package money

import "testing"

func TestSpecificationExampleCommissionIs500On10000(t *testing.T) {
	base, _ := Parse("10000")
	rate, _ := ParseRate("0.050000")
	c := Percent(base, rate)
	if c.String() != "500.00" || (base-c).String() != "9500.00" {
		t.Fatalf("commission %s, partner net %s; the specification example is 500 and 9,500", c, base-c)
	}
}

func TestParseAndFormat(t *testing.T) {
	for in, want := range map[string]string{"0": "0.00", "1234.5": "1234.50", "1234.56": "1234.56", "-5": "-5.00", "0.07": "0.07"} {
		a, err := Parse(in)
		if err != nil || a.String() != want {
			t.Errorf("%q -> %v %v, want %s", in, a, err, want)
		}
	}
	for _, bad := range []string{"", "abc", "1.234", "1,000", "--1", ".5", "1e3", "1.2.3"} {
		if _, err := Parse(bad); err == nil {
			t.Errorf("%q must be rejected", bad)
		}
	}
}

func TestPercentRoundsHalfAwayFromZero(t *testing.T) {
	r, _ := ParseRate("0.05")
	for in, want := range map[string]string{"0.10": "0.01", "0.09": "0.00", "100.10": "5.01", "-0.10": "-0.01", "333.33": "16.67"} {
		a, _ := Parse(in)
		if got := Percent(a, r); got.String() != want {
			t.Errorf("5%% of %s = %s, want %s", in, got, want)
		}
	}
}
