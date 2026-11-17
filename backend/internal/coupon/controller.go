package coupon

import (
	"errors"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/travel-super-app/backend/internal/auth"
	"github.com/travel-super-app/backend/internal/platform/apiresponse"
)

func fail(c *gin.Context, err error) {
	switch {
	case errors.Is(err, ErrNotFound):
		apiresponse.NotFound(c, "coupon not found")
	case errors.Is(err, ErrExpired), errors.Is(err, ErrNotStarted), errors.Is(err, ErrExhausted), errors.Is(err, ErrDuplicate):
		apiresponse.Conflict(c, err.Error())
	case errors.Is(err, ErrValidation):
		apiresponse.BadRequest(c, strings.TrimPrefix(strings.TrimPrefix(err.Error(), ErrValidation.Error()), "\n"))
	default:
		apiresponse.Internal(c)
	}
}

// RegisterRoutes mounts, on a signed-in group: POST /claim {"code": "..."} and GET /mine.
func RegisterRoutes(g *gin.RouterGroup, s *Service) {
	g.POST("/claim", func(c *gin.Context) {
		p, ok := auth.CurrentPrincipal(c)
		if !ok {
			apiresponse.Unauthorized(c)
			return
		}
		var req struct {
			Code string `json:"code"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			apiresponse.BadRequest(c, "invalid JSON body")
			return
		}
		if err := s.Claim(c.Request.Context(), p.UserID, req.Code); err != nil {
			fail(c, err)
			return
		}
		apiresponse.Created(c, gin.H{"saved": true})
	})
	g.GET("/mine", func(c *gin.Context) {
		p, ok := auth.CurrentPrincipal(c)
		if !ok {
			apiresponse.Unauthorized(c)
			return
		}
		limit, offset, ok := apiresponse.Page(c)
		if !ok {
			return
		}
		items, err := s.Mine(c.Request.Context(), p.UserID, limit, offset)
		if err != nil {
			fail(c, err)
			return
		}
		apiresponse.OK(c, gin.H{"items": items})
	})
}
