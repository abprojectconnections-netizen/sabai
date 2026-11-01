// Package dbtime centralises the date/time formats exchanged with MySQL and the API.
// Values are formatted by MySQL (DATE_FORMAT) so reads do not depend on the driver's parseTime setting.
package dbtime

import "time"

const (
	// DateLayout is an ISO calendar date, e.g. 2026-10-28.
	DateLayout = "2006-01-02"
	// SQLDate formats a DATE column as an ISO string.
	SQLDate = "'%Y-%m-%d'"
	// SQLDateTime formats a DATETIME(6) column as an RFC 3339 UTC string.
	SQLDateTime = "'%Y-%m-%dT%H:%i:%s.%fZ'"
)

// ParseDate parses an ISO date and rejects anything else (including timestamps).
func ParseDate(s string) (time.Time, error) { return time.ParseInLocation(DateLayout, s, time.UTC) }

// Now returns the current UTC time; a variable so tests can pin it.
var Now = func() time.Time { return time.Now().UTC() }
