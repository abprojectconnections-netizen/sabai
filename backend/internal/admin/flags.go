package admin

import (
	"database/sql"
	"errors"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/travel-super-app/backend/internal/audit"
	"github.com/travel-super-app/backend/internal/auth"
	"github.com/travel-super-app/backend/internal/platform/apiresponse"
)

// listFlags returns every feature flag with who last changed it. Requires config.manage.
func listFlags(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		rows, err := db.QueryContext(c.Request.Context(), `SELECT f.flag_key, f.description, f.enabled, f.updated_at, u.email
FROM feature_flags f LEFT JOIN users u ON u.id = f.updated_by WHERE f.deleted_at IS NULL ORDER BY f.flag_key`)
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		defer rows.Close()
		items := []gin.H{}
		for rows.Next() {
			var key, desc string
			var on bool
			var at time.Time
			var by sql.NullString
			if err := rows.Scan(&key, &desc, &on, &at, &by); err != nil {
				apiresponse.Internal(c)
				return
			}
			items = append(items, gin.H{"key": key, "description": desc, "enabled": on, "updated_at": at.UTC(), "updated_by": nullStr(by)})
		}
		if rows.Err() != nil {
			apiresponse.Internal(c)
			return
		}
		apiresponse.OK(c, gin.H{"items": items})
	}
}

func nullStr(s sql.NullString) any {
	if s.Valid {
		return s.String
	}
	return nil
}

// setFlag switches one flag. A reason is required when turning a feature OFF (it lands in the audit trail), repeating the
// current value is a no-op without an audit row, and the change and its audit row commit together.
func setFlag(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var in struct {
			Enabled *bool  `json:"enabled"`
			Reason  string `json:"reason"`
		}
		if err := c.ShouldBindJSON(&in); err != nil || in.Enabled == nil {
			apiresponse.BadRequest(c, "enabled (true|false) is required")
			return
		}
		if !*in.Enabled && strings.TrimSpace(in.Reason) == "" {
			apiresponse.BadRequest(c, "reason is required when turning a feature off")
			return
		}
		if len(in.Reason) > 500 {
			apiresponse.BadRequest(c, "reason must be at most 500 characters")
			return
		}
		p, _ := auth.CurrentPrincipal(c)
		key := c.Param("key")
		err := inTx(c, db, func(tx *sql.Tx) error {
			var id string
			var before bool
			if err := tx.QueryRowContext(c.Request.Context(), "SELECT id, enabled FROM feature_flags WHERE flag_key = ? AND deleted_at IS NULL FOR UPDATE", key).Scan(&id, &before); err != nil {
				return err
			}
			if before == *in.Enabled {
				return nil
			}
			if _, err := tx.ExecContext(c.Request.Context(), "UPDATE feature_flags SET enabled = ?, updated_by = ?, updated_at = ? WHERE id = ?", *in.Enabled, p.UserID, time.Now().UTC(), id); err != nil {
				return err
			}
			return audit.Log(c.Request.Context(), tx, audit.Entry{ActorUserID: p.UserID, Action: "feature_flag.changed", SubjectType: "feature_flag", SubjectID: id,
				Before: gin.H{"key": key, "enabled": before}, After: gin.H{"key": key, "enabled": *in.Enabled, "reason": in.Reason}, IPAddress: c.ClientIP(), RequestID: c.GetString("request_id")})
		})
		switch {
		case errors.Is(err, sql.ErrNoRows):
			apiresponse.NotFound(c, "feature flag not found")
		case err != nil:
			apiresponse.Internal(c)
		default:
			apiresponse.OK(c, gin.H{"key": key, "enabled": *in.Enabled})
		}
	}
}
