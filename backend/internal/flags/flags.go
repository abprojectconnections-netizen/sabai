// Package flags reads runtime feature flags (table feature_flags) so a feature can be switched off without a deploy.
// A flag that does not exist, or a database error while reading it, counts as ENABLED: a broken flag lookup must never
// take a working feature down. Flags are switched by staff with config.manage through /admin/feature-flags.
package flags

import (
	"context"
	"database/sql"
	"errors"

	"github.com/gin-gonic/gin"
	"github.com/travel-super-app/backend/internal/platform/apiresponse"
)

// Enabled reports whether the flag is on. Unknown flags and read errors fail open.
func Enabled(ctx context.Context, db *sql.DB, key string) bool {
	var on bool
	err := db.QueryRowContext(ctx, "SELECT enabled FROM feature_flags WHERE flag_key = ? AND deleted_at IS NULL", key).Scan(&on)
	if errors.Is(err, sql.ErrNoRows) || err != nil {
		return true
	}
	return on
}

// Require is a middleware that answers 503 FEATURE_DISABLED while the flag is off.
func Require(db *sql.DB, key, message string) gin.HandlerFunc {
	return func(c *gin.Context) {
		if !Enabled(c.Request.Context(), db, key) {
			apiresponse.FeatureDisabled(c, message)
			c.Abort()
			return
		}
		c.Next()
	}
}

// RequireWhen is like Require but only guards requests for which match returns true, so one feature can be switched off
// on a single route (for example POST /posts) while the rest of its group keeps working.
func RequireWhen(db *sql.DB, key, message string, match func(*gin.Context) bool) gin.HandlerFunc {
	guard := Require(db, key, message)
	return func(c *gin.Context) {
		if match(c) {
			guard(c)
			return
		}
		c.Next()
	}
}

// All returns every flag as key -> enabled, for clients that want to hide controls of a disabled feature.
func All(ctx context.Context, db *sql.DB) (map[string]bool, error) {
	rows, err := db.QueryContext(ctx, "SELECT flag_key, enabled FROM feature_flags WHERE deleted_at IS NULL")
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[string]bool{}
	for rows.Next() {
		var k string
		var on bool
		if err := rows.Scan(&k, &on); err != nil {
			return nil, err
		}
		out[k] = on
	}
	return out, rows.Err()
}
