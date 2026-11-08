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
)

type roleRequest struct {
	Role string `json:"role"`
}

func RegisterRoutes(group *gin.RouterGroup, db *sql.DB) {
	group.PUT("/users/:id/roles", assignRole(db))
}

func assignRole(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var request roleRequest
		if err := c.ShouldBindJSON(&request); err != nil {
			apiresponse.BadRequest(c, "role is required")
			return
		}
		role := strings.ToUpper(strings.TrimSpace(request.Role))
		if role != "CUSTOMER" && role != "PARTNER" && role != "STAFF" && role != "ADMIN" {
			apiresponse.BadRequest(c, "role must be CUSTOMER, PARTNER, STAFF, or ADMIN")
			return
		}
		userID := c.Param("id")
		var roleID string
		if err := db.QueryRowContext(c.Request.Context(), "SELECT id FROM roles WHERE code=? AND deleted_at IS NULL", role).Scan(&roleID); err != nil {
			apiresponse.Internal(c)
			return
		}
		principal, _ := auth.CurrentPrincipal(c)
		if principal.UserID == userID {
			// Separation of duties: nobody changes their own roles; a second administrator must do it.
			apiresponse.ForbiddenWith(c, "you cannot change your own roles")
			return
		}
		var newAssignment int64
		err := func() error {
			tx, err := db.BeginTx(c.Request.Context(), nil)
			if err != nil {
				return err
			}
			defer tx.Rollback()
			var exists string
			if err := tx.QueryRowContext(c.Request.Context(), "SELECT id FROM users WHERE id=? AND deleted_at IS NULL", userID).Scan(&exists); err != nil {
				return err
			}
			result, err := tx.ExecContext(c.Request.Context(), "INSERT IGNORE INTO user_roles (id,created_at,updated_at,user_id,role_id) VALUES (?,?,?,?,?)", uuid.NewString(), time.Now().UTC(), time.Now().UTC(), userID, roleID)
			if err != nil {
				return err
			}
			newAssignment, _ = result.RowsAffected()
			if err := audit.Log(c.Request.Context(), tx, audit.Entry{ActorUserID: principal.UserID, Action: "user.role.assigned", SubjectType: "user", SubjectID: userID, Before: gin.H{}, After: gin.H{"role": role, "new_assignment": newAssignment == 1}, IPAddress: c.ClientIP(), RequestID: c.GetString("request_id")}); err != nil {
				return err
			}
			return tx.Commit()
		}()
		if errors.Is(err, sql.ErrNoRows) {
			apiresponse.NotFound(c, "user not found")
			return
		} else if err != nil {
			apiresponse.Internal(c)
			return
		}
		apiresponse.OK(c, gin.H{"user_id": userID, "role": role, "new_assignment": newAssignment == 1})
	}
}
