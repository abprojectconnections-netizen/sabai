package admin

import (
	"database/sql"

	"github.com/gin-gonic/gin"
	"github.com/travel-super-app/backend/internal/platform/apiresponse"
)

type roleRow struct {
	Code        string   `json:"code"`
	Name        string   `json:"name"`
	Financial   bool     `json:"financial"`
	UserCount   int      `json:"user_count"`
	Permissions []string `json:"permissions"`
}

// listRoles returns every role with the permission codes it bundles and how many live accounts hold it. Read-only: roles are
// assigned only through the request/approve flow (separation of duties).
func listRoles(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()
		rows, err := db.QueryContext(ctx, `SELECT r.id, r.code, r.name,
			(SELECT COUNT(DISTINCT ur.user_id) FROM user_roles ur JOIN users u ON u.id = ur.user_id AND u.deleted_at IS NULL
			 WHERE ur.role_id = r.id AND ur.deleted_at IS NULL)
			FROM roles r WHERE r.deleted_at IS NULL ORDER BY r.code`)
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		defer rows.Close()
		items := []*roleRow{}
		byID := map[string]*roleRow{}
		for rows.Next() {
			var id string
			r := &roleRow{Permissions: []string{}}
			if err := rows.Scan(&id, &r.Code, &r.Name, &r.UserCount); err != nil {
				apiresponse.Internal(c)
				return
			}
			r.Financial = financialRoles[r.Code]
			items = append(items, r)
			byID[id] = r
		}
		if rows.Err() != nil {
			apiresponse.Internal(c)
			return
		}
		prows, err := db.QueryContext(ctx, `SELECT rp.role_id, p.code FROM role_permissions rp
			JOIN permissions p ON p.id = rp.permission_id AND p.deleted_at IS NULL
			WHERE rp.deleted_at IS NULL ORDER BY p.code`)
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		defer prows.Close()
		for prows.Next() {
			var roleID, code string
			if err := prows.Scan(&roleID, &code); err != nil {
				apiresponse.Internal(c)
				return
			}
			if r := byID[roleID]; r != nil {
				r.Permissions = append(r.Permissions, code)
			}
		}
		if prows.Err() != nil {
			apiresponse.Internal(c)
			return
		}
		apiresponse.OK(c, gin.H{"items": items})
	}
}
