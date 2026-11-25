package admin

import (
	"database/sql"

	"github.com/gin-gonic/gin"
	"github.com/travel-super-app/backend/internal/auth"
)

// RegisterConsoleRoutes adds the admin console endpoints. Each route declares its own permission, so a role only sees what
// it was granted: user.manage (ADMIN, SYSTEM_ADMIN) for users and roles, audit.read (AUDITOR, CFO_CEO) for the audit trail,
// and portal.read or user.manage for the dashboard. Note that System Admin deliberately cannot read the audit trail.
func RegisterConsoleRoutes(group *gin.RouterGroup, db *sql.DB) {
	group.GET("/dashboard", auth.RequirePermission("user.manage", "portal.read", "audit.read"), dashboard(db))
	group.GET("/users", auth.RequirePermission("user.manage"), listUsers(db))
	group.GET("/users/:id", auth.RequirePermission("user.manage"), getUser(db))
	group.PATCH("/users/:id/status", auth.RequirePermission("user.manage"), setUserStatus(db))
	group.GET("/roles", auth.RequirePermission("user.manage", "audit.read"), listRoles(db))
	group.GET("/feature-flags", auth.RequirePermission("config.manage"), listFlags(db))
	group.PATCH("/feature-flags/:key", auth.RequirePermission("config.manage"), setFlag(db))
	group.GET("/audit-logs", auth.RequirePermission("audit.read"), listAuditLogs(db))
}
