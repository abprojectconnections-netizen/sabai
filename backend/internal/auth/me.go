package auth

import (
	"sort"

	"github.com/gin-gonic/gin"
	"github.com/travel-super-app/backend/internal/platform/apiresponse"
)

func sortedKeys(m map[string]bool) []string {
	out := make([]string, 0, len(m))
	for k, v := range m {
		if v {
			out = append(out, k)
		}
	}
	sort.Strings(out)
	return out
}

// Me returns who the caller is and what they may do, read from the database on this request (the same data the
// permission checks use). Clients use it only to decide which screens to offer; the server still enforces every action.
func Me() gin.HandlerFunc {
	return func(c *gin.Context) {
		p, ok := CurrentPrincipal(c)
		if !ok {
			apiresponse.Unauthorized(c)
			return
		}
		apiresponse.OK(c, gin.H{"id": p.UserID, "email": p.Email, "roles": sortedKeys(p.Roles), "permissions": sortedKeys(p.Permissions)})
	}
}
