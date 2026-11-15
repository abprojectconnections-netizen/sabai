package tag

import (
	"errors"
	"testing"
)

func TestNormalize(t *testing.T) {
	cases := []struct {
		in, slug, label string
		bad             bool
	}{
		{"Cafe Hop", "cafe-hop", "Cafe Hop", false},
		{"  ธรรมชาติ  ", "ธรรมชาติ", "ธรรมชาติ", false}, // Thai vowel/tone marks must survive
		{"อาหาร   ท้องถิ่น", "อาหาร-ท้องถิ่น", "อาหาร ท้องถิ่น", false},
		{"Chiang-Mai 2026", "chiang-mai-2026", "Chiang-Mai 2026", false},
		{"", "", "", true},
		{"   ", "", "", true},
		{"---", "", "", true},
		{"a/b", "", "", true},
		{"<script>", "", "", true},
		{"#hash", "", "", true},
		{"123456789012345678901234567890x", "", "", true}, // 31 characters
	}
	for _, c := range cases {
		slug, label, err := Normalize(c.in)
		if c.bad {
			if !errors.Is(err, ErrValidation) {
				t.Errorf("%q: want validation error, got %v", c.in, err)
			}
			continue
		}
		if err != nil || slug != c.slug || label != c.label {
			t.Errorf("%q: got (%q, %q, %v), want (%q, %q)", c.in, slug, label, err, c.slug, c.label)
		}
	}
}

func TestEscapeLike(t *testing.T) {
	if got := escapeLike(`50%_off\`); got != `50\%\_off\\` {
		t.Fatalf("got %q", got)
	}
}
