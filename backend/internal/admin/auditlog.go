package admin

import (
	"database/sql"
	"encoding/json"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/travel-super-app/backend/internal/platform/apiresponse"
	"github.com/travel-super-app/backend/internal/platform/dbtime"
)

type auditRow struct {
	ID          string          `json:"id"`
	CreatedAt   string          `json:"created_at"`
	ActorUserID string          `json:"actor_user_id"`
	ActorEmail  string          `json:"actor_email"`
	Action      string          `json:"action"`
	SubjectType string          `json:"subject_type"`
	SubjectID   string          `json:"subject_id"`
	Before      json.RawMessage `json:"before"`
	After       json.RawMessage `json:"after"`
	IPAddress   string          `json:"ip_address"`
	RequestID   string          `json:"request_id"`
}

// listAuditLogs is the read-only audit trail viewer. Filters: ?action, ?subject_type, ?subject_id, ?actor (user id),
// ?from and ?to (RFC 3339), plus ?limit/?offset. Newest first. Audit rows can only be read here, never changed.
func listAuditLogs(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		limit, offset, ok := apiresponse.Page(c)
		if !ok {
			return
		}
		where := []string{"a.deleted_at IS NULL"}
		args := []any{}
		for _, f := range []struct {
			param, column string
			max           int
		}{{"action", "a.action", 100}, {"subject_type", "a.subject_type", 50}, {"subject_id", "a.subject_id", 36}, {"actor", "a.actor_user_id", 36}} {
			if v := strings.TrimSpace(c.Query(f.param)); v != "" {
				if len(v) > f.max {
					apiresponse.BadRequest(c, f.param+" is too long")
					return
				}
				where = append(where, f.column+" = ?")
				args = append(args, v)
			}
		}
		for _, f := range []struct{ param, op string }{{"from", ">="}, {"to", "<="}} {
			if v := strings.TrimSpace(c.Query(f.param)); v != "" {
				t, err := time.Parse(time.RFC3339, v)
				if err != nil {
					apiresponse.BadRequest(c, f.param+" must be an RFC 3339 timestamp")
					return
				}
				where = append(where, "a.created_at "+f.op+" ?")
				args = append(args, t.UTC())
			}
		}
		cond := strings.Join(where, " AND ")

		var total int
		if err := db.QueryRowContext(c.Request.Context(), "SELECT COUNT(*) FROM audit_logs a WHERE "+cond, args...).Scan(&total); err != nil {
			apiresponse.Internal(c)
			return
		}
		rows, err := db.QueryContext(c.Request.Context(), `SELECT a.id, DATE_FORMAT(a.created_at, `+dbtime.SQLDateTime+`),
			COALESCE(a.actor_user_id, ''), COALESCE(u.email, ''), a.action, a.subject_type, COALESCE(a.subject_id, ''),
			a.before_json, a.after_json, COALESCE(a.ip_address, ''), COALESCE(a.request_id, '')
			FROM audit_logs a LEFT JOIN users u ON u.id = a.actor_user_id
			WHERE `+cond+` ORDER BY a.created_at DESC, a.id DESC LIMIT ? OFFSET ?`, append(append([]any{}, args...), limit, offset)...)
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		defer rows.Close()
		items := []auditRow{}
		for rows.Next() {
			var r auditRow
			var before, after []byte
			if err := rows.Scan(&r.ID, &r.CreatedAt, &r.ActorUserID, &r.ActorEmail, &r.Action, &r.SubjectType, &r.SubjectID, &before, &after, &r.IPAddress, &r.RequestID); err != nil {
				apiresponse.Internal(c)
				return
			}
			if len(before) > 0 {
				r.Before = json.RawMessage(before)
			}
			if len(after) > 0 {
				r.After = json.RawMessage(after)
			}
			items = append(items, r)
		}
		if rows.Err() != nil {
			apiresponse.Internal(c)
			return
		}
		apiresponse.OK(c, gin.H{"items": items, "total": total, "limit": limit, "offset": offset})
	}
}
