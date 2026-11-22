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
	"github.com/travel-super-app/backend/internal/platform/dbtime"
)

// userStatuses are the account states an administrator may move between. Authentication only accepts ACTIVE accounts and checks
// it on every request, so a suspension takes effect immediately.
var userStatuses = map[string]bool{"ACTIVE": true, "SUSPENDED": true}

var errBadState = errors.New("account is in a state that cannot be changed here")

const (
	maxSearchLen = 100
	maxReasonLen = 500
)

type userRow struct {
	ID          string   `json:"id"`
	Email       string   `json:"email"`
	Status      string   `json:"status"`
	Roles       []string `json:"roles"`
	CreatedAt   string   `json:"created_at"`
	LastLoginAt *string  `json:"last_login_at"`
}

// likeEscape makes user input literal inside a LIKE pattern that uses ESCAPE '\'.
func likeEscape(s string) string {
	return strings.NewReplacer(`\`, `\\`, `%`, `\%`, `_`, `\_`).Replace(s)
}

func splitCSV(s string) []string {
	if s == "" {
		return []string{}
	}
	return strings.Split(s, ",")
}

// listUsers supports ?q (email contains), ?status, ?role, ?limit and ?offset.
func listUsers(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		limit, offset, ok := apiresponse.Page(c)
		if !ok {
			return
		}
		where := []string{"u.deleted_at IS NULL"}
		args := []any{}
		if q := strings.TrimSpace(c.Query("q")); q != "" {
			if len(q) > maxSearchLen {
				apiresponse.BadRequest(c, "q is too long")
				return
			}
			where = append(where, `u.email LIKE ? ESCAPE '\\'`)
			args = append(args, "%"+likeEscape(q)+"%")
		}
		if st := strings.ToUpper(strings.TrimSpace(c.Query("status"))); st != "" {
			if !userStatuses[st] {
				apiresponse.BadRequest(c, "status must be ACTIVE or SUSPENDED")
				return
			}
			where = append(where, "u.status = ?")
			args = append(args, st)
		}
		if role := strings.ToUpper(strings.TrimSpace(c.Query("role"))); role != "" {
			if len(role) > 50 {
				apiresponse.BadRequest(c, "role is too long")
				return
			}
			where = append(where, `EXISTS (SELECT 1 FROM user_roles fx JOIN roles fr ON fr.id = fx.role_id AND fr.deleted_at IS NULL
				WHERE fx.user_id = u.id AND fx.deleted_at IS NULL AND fr.code = ?)`)
			args = append(args, role)
		}
		cond := strings.Join(where, " AND ")

		var total int
		if err := db.QueryRowContext(c.Request.Context(), "SELECT COUNT(*) FROM users u WHERE "+cond, args...).Scan(&total); err != nil {
			apiresponse.Internal(c)
			return
		}
		rows, err := db.QueryContext(c.Request.Context(), `SELECT u.id, u.email, u.status, DATE_FORMAT(u.created_at, `+dbtime.SQLDateTime+`),
			DATE_FORMAT(u.last_login_at, `+dbtime.SQLDateTime+`),
			COALESCE(GROUP_CONCAT(DISTINCT r.code ORDER BY r.code SEPARATOR ','), '')
			FROM users u
			LEFT JOIN user_roles ur ON ur.user_id = u.id AND ur.deleted_at IS NULL
			LEFT JOIN roles r ON r.id = ur.role_id AND r.deleted_at IS NULL
			WHERE `+cond+`
			GROUP BY u.id ORDER BY u.created_at DESC, u.id DESC LIMIT ? OFFSET ?`, append(append([]any{}, args...), limit, offset)...)
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		defer rows.Close()
		items := []userRow{}
		for rows.Next() {
			var u userRow
			var last sql.NullString
			var roles string
			if err := rows.Scan(&u.ID, &u.Email, &u.Status, &u.CreatedAt, &last, &roles); err != nil {
				apiresponse.Internal(c)
				return
			}
			if last.Valid {
				u.LastLoginAt = &last.String
			}
			u.Roles = splitCSV(roles)
			items = append(items, u)
		}
		if rows.Err() != nil {
			apiresponse.Internal(c)
			return
		}
		apiresponse.OK(c, gin.H{"items": items, "total": total, "limit": limit, "offset": offset})
	}
}

type pendingRole struct {
	Role      string `json:"role"`
	RequestID string `json:"request_id"`
	CreatedAt string `json:"created_at"`
}

// getUser returns one account with its profile name, active roles and pending role requests. Password hash and phone are never returned.
func getUser(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()
		id := c.Param("id")
		var u userRow
		var last sql.NullString
		err := db.QueryRowContext(ctx, `SELECT u.id, u.email, u.status, DATE_FORMAT(u.created_at, `+dbtime.SQLDateTime+`),
			DATE_FORMAT(u.last_login_at, `+dbtime.SQLDateTime+`) FROM users u WHERE u.id = ? AND u.deleted_at IS NULL`, id).
			Scan(&u.ID, &u.Email, &u.Status, &u.CreatedAt, &last)
		if errors.Is(err, sql.ErrNoRows) {
			apiresponse.NotFound(c, "user not found")
			return
		}
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		if last.Valid {
			u.LastLoginAt = &last.String
		}
		var roles string
		var name sql.NullString
		if err := db.QueryRowContext(ctx, `SELECT COALESCE(GROUP_CONCAT(DISTINCT r.code ORDER BY r.code SEPARATOR ','), '')
			FROM user_roles ur JOIN roles r ON r.id = ur.role_id AND r.deleted_at IS NULL
			WHERE ur.user_id = ? AND ur.deleted_at IS NULL`, id).Scan(&roles); err != nil {
			apiresponse.Internal(c)
			return
		}
		u.Roles = splitCSV(roles)
		err = db.QueryRowContext(ctx, `SELECT NULLIF(TRIM(CONCAT_WS(' ', first_name, last_name)), '') FROM user_profiles
			WHERE user_id = ? AND deleted_at IS NULL LIMIT 1`, id).Scan(&name)
		if err != nil && !errors.Is(err, sql.ErrNoRows) {
			apiresponse.Internal(c)
			return
		}
		pending := []pendingRole{}
		rows, err := db.QueryContext(ctx, `SELECT r.code, rc.id, DATE_FORMAT(rc.created_at, `+dbtime.SQLDateTime+`)
			FROM role_change_requests rc JOIN roles r ON r.id = rc.role_id
			WHERE rc.target_user_id = ? AND rc.status = 'PENDING' ORDER BY rc.created_at`, id)
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		defer rows.Close()
		for rows.Next() {
			var p pendingRole
			if err := rows.Scan(&p.Role, &p.RequestID, &p.CreatedAt); err != nil {
				apiresponse.Internal(c)
				return
			}
			pending = append(pending, p)
		}
		if rows.Err() != nil {
			apiresponse.Internal(c)
			return
		}
		out := gin.H{"id": u.ID, "email": u.Email, "status": u.Status, "roles": u.Roles, "created_at": u.CreatedAt,
			"last_login_at": u.LastLoginAt, "display_name": nil, "pending_role_requests": pending}
		if name.Valid {
			out["display_name"] = name.String
		}
		apiresponse.OK(c, out)
	}
}

type statusChange struct {
	Status string `json:"status"`
	Reason string `json:"reason"`
}

// setUserStatus suspends or reactivates an account. Rules: a person cannot change their own status, a reason is required to suspend,
// repeating the current status is a no-op (nothing is written or audited), and every real change is audited in the same transaction.
func setUserStatus(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var in statusChange
		if err := c.ShouldBindJSON(&in); err != nil {
			apiresponse.BadRequest(c, "status is required")
			return
		}
		in.Status = strings.ToUpper(strings.TrimSpace(in.Status))
		in.Reason = strings.TrimSpace(in.Reason)
		if !userStatuses[in.Status] {
			apiresponse.BadRequest(c, "status must be ACTIVE or SUSPENDED")
			return
		}
		if len(in.Reason) > maxReasonLen {
			apiresponse.BadRequest(c, "reason is too long")
			return
		}
		if in.Status == "SUSPENDED" && len(in.Reason) < 3 {
			apiresponse.BadRequest(c, "a reason is required to suspend an account")
			return
		}
		p, _ := auth.CurrentPrincipal(c)
		id := c.Param("id")
		if p.UserID == id {
			apiresponse.ForbiddenWith(c, "you cannot change your own account status")
			return
		}
		err := inTx(c, db, func(tx *sql.Tx) error {
			var before string
			if err := tx.QueryRowContext(c.Request.Context(), "SELECT status FROM users WHERE id = ? AND deleted_at IS NULL FOR UPDATE", id).Scan(&before); err != nil {
				return err
			}
			if !userStatuses[before] {
				return errBadState
			}
			if before == in.Status {
				return nil
			}
			if _, err := tx.ExecContext(c.Request.Context(), "UPDATE users SET status = ?, updated_at = ? WHERE id = ?", in.Status, time.Now().UTC(), id); err != nil {
				return err
			}
			return audit.Log(c.Request.Context(), tx, audit.Entry{ActorUserID: p.UserID, Action: "user.status.changed", SubjectType: "user", SubjectID: id,
				Before: gin.H{"status": before}, After: gin.H{"status": in.Status, "reason": in.Reason}, IPAddress: c.ClientIP(), RequestID: c.GetString("request_id")})
		})
		switch {
		case errors.Is(err, sql.ErrNoRows):
			apiresponse.NotFound(c, "user not found")
		case errors.Is(err, errBadState):
			apiresponse.Conflict(c, err.Error())
		case err != nil:
			apiresponse.Internal(c)
		default:
			apiresponse.OK(c, gin.H{"id": id, "status": in.Status})
		}
	}
}
