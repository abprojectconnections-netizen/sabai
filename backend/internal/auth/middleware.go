package auth

import (
	"database/sql"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/travel-super-app/backend/internal/platform/apiresponse"
)

const principalKey = "principal"

type Principal struct {
	UserID, Email string
	Roles         map[string]bool
}

func Authenticate(db *sql.DB, secret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		parts := strings.Fields(c.GetHeader("Authorization"))
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
			apiresponse.Unauthorized(c)
			c.Abort()
			return
		}
		token, err := jwt.Parse(parts[1], func(token *jwt.Token) (any, error) {
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, jwt.ErrTokenSignatureInvalid
			}
			return []byte(secret), nil
		})
		if err != nil || !token.Valid {
			apiresponse.Unauthorized(c)
			c.Abort()
			return
		}
		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			apiresponse.Unauthorized(c)
			c.Abort()
			return
		}
		userID, ok := claims["sub"].(string)
		if !ok || userID == "" {
			apiresponse.Unauthorized(c)
			c.Abort()
			return
		}
		var email string
		if err := db.QueryRowContext(c.Request.Context(), "SELECT email FROM users WHERE id = ? AND status = 'ACTIVE' AND deleted_at IS NULL", userID).Scan(&email); err != nil {
			apiresponse.Unauthorized(c)
			c.Abort()
			return
		}
		rows, err := db.QueryContext(c.Request.Context(), `SELECT r.code FROM roles r JOIN user_roles ur ON ur.role_id=r.id WHERE ur.user_id=? AND r.deleted_at IS NULL AND ur.deleted_at IS NULL`, userID)
		if err != nil {
			apiresponse.Internal(c)
			c.Abort()
			return
		}
		defer rows.Close()
		roles := map[string]bool{}
		for rows.Next() {
			var role string
			if err := rows.Scan(&role); err != nil {
				apiresponse.Internal(c)
				c.Abort()
				return
			}
			roles[role] = true
		}
		if err := rows.Err(); err != nil {
			apiresponse.Internal(c)
			c.Abort()
			return
		}
		c.Set(principalKey, Principal{UserID: userID, Email: email, Roles: roles})
		c.Next()
	}
}

func RequireRoles(allowed ...string) gin.HandlerFunc {
	return func(c *gin.Context) {
		principal, ok := CurrentPrincipal(c)
		if !ok {
			apiresponse.Unauthorized(c)
			c.Abort()
			return
		}
		for _, role := range allowed {
			if principal.Roles[role] {
				c.Next()
				return
			}
		}
		apiresponse.Forbidden(c)
		c.Abort()
	}
}
func CurrentPrincipal(c *gin.Context) (Principal, bool) {
	raw, ok := c.Get(principalKey)
	principal, valid := raw.(Principal)
	return principal, ok && valid
}

// SetPrincipal stores an already-authenticated principal on the request context.
// Authenticate uses it; tests use it to exercise handlers without a database-backed login.
func SetPrincipal(c *gin.Context, p Principal) { c.Set(principalKey, p) }
