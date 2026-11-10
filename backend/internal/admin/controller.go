package admin

import (
	"database/sql"
	"errors"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/travel-super-app/backend/internal/audit"
	"github.com/travel-super-app/backend/internal/auth"
	"github.com/travel-super-app/backend/internal/platform/apiresponse"
	"github.com/travel-super-app/backend/internal/platform/dberr"
)

// Roles that carry financial authority. Granting one needs an approver holding role.approve.financial.
var financialRoles = map[string]bool{"REFUND_OFFICER": true, "FINANCE_MANAGER": true, "CFO_CEO": true}

// Roles that may be requested at all (CUSTOMER is automatic at registration).
var grantableRoles = map[string]bool{
	"PARTNER": true, "PARTNER_ADMIN": true, "PARTNER_FINANCE": true, "STAFF": true, "BOOKING_OFFICER": true,
	"REFUND_OFFICER": true, "FINANCE_MANAGER": true, "CFO_CEO": true, "SYSTEM_ADMIN": true, "AUDITOR": true, "ADMIN": true,
}

type roleRequest struct {
	UserID string `json:"user_id"`
	Role   string `json:"role"`
	Reason string `json:"reason"`
}

// RegisterRoutes: roles are never assigned directly. One person requests, a different person approves
// (Section 8 separation of duties). There is deliberately no PUT /users/:id/roles.
func RegisterRoutes(group *gin.RouterGroup, db *sql.DB) {
	group.POST("/role-requests", auth.RequirePermission("role.request"), createRequest(db))
	group.POST("/role-requests/:id/approve", auth.RequirePermission("role.approve", "role.approve.financial"), decide(db, true))
	group.POST("/role-requests/:id/reject", auth.RequirePermission("role.approve", "role.approve.financial"), decide(db, false))
}

func createRequest(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var in roleRequest
		if err := c.ShouldBindJSON(&in); err != nil || in.UserID == "" {
			apiresponse.BadRequest(c, "user_id and role are required")
			return
		}
		role := strings.ToUpper(strings.TrimSpace(in.Role))
		if !grantableRoles[role] {
			apiresponse.BadRequest(c, "unknown or non-grantable role")
			return
		}
		p, _ := auth.CurrentPrincipal(c)
		if p.UserID == in.UserID {
			apiresponse.ForbiddenWith(c, "you cannot request roles for yourself")
			return
		}
		id := uuid.NewString()
		err := inTx(c, db, func(tx *sql.Tx) error {
			var roleID, target string
			if err := tx.QueryRowContext(c.Request.Context(), "SELECT id FROM roles WHERE code = ? AND deleted_at IS NULL", role).Scan(&roleID); err != nil {
				return err
			}
			if err := tx.QueryRowContext(c.Request.Context(), "SELECT id FROM users WHERE id = ? AND deleted_at IS NULL", in.UserID).Scan(&target); err != nil {
				return err
			}
			if _, err := tx.ExecContext(c.Request.Context(), "INSERT INTO role_change_requests (id, created_at, target_user_id, role_id, requested_by, reason) VALUES (?, ?, ?, ?, ?, ?)",
				id, time.Now().UTC(), in.UserID, roleID, p.UserID, nullable(in.Reason)); err != nil {
				return err
			}
			return audit.Log(c.Request.Context(), tx, audit.Entry{ActorUserID: p.UserID, Action: "user.role.requested", SubjectType: "user", SubjectID: in.UserID,
				Before: gin.H{}, After: gin.H{"role": role, "request_id": id}, IPAddress: c.ClientIP(), RequestID: c.GetString("request_id")})
		})
		switch {
		case errors.Is(err, sql.ErrNoRows):
			apiresponse.NotFound(c, "user not found")
		case dberr.IsDuplicate(err):
			apiresponse.Conflict(c, "a request for this role is already pending")
		case err != nil:
			apiresponse.Internal(c)
		default:
			apiresponse.Created(c, gin.H{"id": id, "status": "PENDING", "user_id": in.UserID, "role": role})
		}
	}
}

func decide(db *sql.DB, approve bool) gin.HandlerFunc {
	return func(c *gin.Context) {
		p, _ := auth.CurrentPrincipal(c)
		reqID := c.Param("id")
		var role, target, status string
		var requester string
		var granted bool
		err := inTx(c, db, func(tx *sql.Tx) error {
			var roleID string
			if err := tx.QueryRowContext(c.Request.Context(), `SELECT r.code, r.id, q.target_user_id, q.requested_by, q.status
				FROM role_change_requests q JOIN roles r ON r.id = q.role_id WHERE q.id = ? FOR UPDATE`, reqID).Scan(&role, &roleID, &target, &requester, &status); err != nil {
				return err
			}
			if status != "PENDING" {
				return errNotPending
			}
			if p.UserID == requester || p.UserID == target {
				return errSelfDecide
			}
			if financialRoles[role] && !p.Permissions["role.approve.financial"] {
				return errNeedFinancial
			}
			next := "REJECTED"
			if approve {
				next = "APPROVED"
				res, err := tx.ExecContext(c.Request.Context(), "INSERT IGNORE INTO user_roles (id, created_at, updated_at, user_id, role_id) VALUES (?, ?, ?, ?, ?)",
					uuid.NewString(), time.Now().UTC(), time.Now().UTC(), target, roleID)
				if err != nil {
					return err
				}
				n, _ := res.RowsAffected()
				granted = n == 1
			}
			if _, err := tx.ExecContext(c.Request.Context(), "UPDATE role_change_requests SET status = ?, decided_by = ?, decided_at = ? WHERE id = ? AND status = 'PENDING'", next, p.UserID, time.Now().UTC(), reqID); err != nil {
				return err
			}
			action := "user.role.rejected"
			if approve {
				action = "user.role.assigned"
			}
			return audit.Log(c.Request.Context(), tx, audit.Entry{ActorUserID: p.UserID, Action: action, SubjectType: "user", SubjectID: target,
				Before: gin.H{}, After: gin.H{"role": role, "request_id": reqID, "requested_by": requester, "new_assignment": granted}, IPAddress: c.ClientIP(), RequestID: c.GetString("request_id")})
		})
		switch {
		case errors.Is(err, sql.ErrNoRows):
			apiresponse.NotFound(c, "request not found")
		case errors.Is(err, errNotPending):
			apiresponse.Conflict(c, "request is not pending")
		case errors.Is(err, errSelfDecide):
			apiresponse.ForbiddenWith(c, "the requester and the target user cannot decide this request")
		case errors.Is(err, errNeedFinancial):
			apiresponse.ForbiddenWith(c, "a financial role must be approved by a holder of role.approve.financial")
		case err != nil:
			apiresponse.Internal(c)
		default:
			status := "REJECTED"
			if approve {
				status = "APPROVED"
			}
			apiresponse.OK(c, gin.H{"id": reqID, "status": status, "user_id": target, "role": role, "new_assignment": granted})
		}
	}
}

var (
	errNotPending    = errors.New("request is not pending")
	errSelfDecide    = errors.New("requester or target cannot decide")
	errNeedFinancial = errors.New("financial approver required")
)

func inTx(c *gin.Context, db *sql.DB, fn func(tx *sql.Tx) error) error {
	tx, err := db.BeginTx(c.Request.Context(), nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if err := fn(tx); err != nil {
		return err
	}
	return tx.Commit()
}

func nullable(s string) any {
	if strings.TrimSpace(s) == "" {
		return nil
	}
	return s
}
