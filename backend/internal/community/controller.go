package community

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
		apiresponse.NotFound(c, "post not found")
	case errors.Is(err, ErrValidation):
		apiresponse.BadRequest(c, strings.TrimPrefix(strings.TrimPrefix(err.Error(), ErrValidation.Error()), "\n"))
	default:
		apiresponse.Internal(c)
	}
}

// RegisterRoutes mounts, on a signed-in group:
//
//	GET    /posts                feed (newest first; posts the caller reported are hidden)
//	POST   /posts                {"body": "..."} publish immediately
//	DELETE /posts/:id            delete own post
//	POST   /posts/:id/report     {"reason": "SPAM|ABUSE|MISLEADING|OTHER", "detail": "..."}
func RegisterRoutes(g *gin.RouterGroup, s *Service) {
	g.GET("/posts", func(c *gin.Context) {
		p, ok := auth.CurrentPrincipal(c)
		if !ok {
			apiresponse.Unauthorized(c)
			return
		}
		limit, offset, ok := apiresponse.Page(c)
		if !ok {
			return
		}
		posts, err := s.Feed(c.Request.Context(), p.UserID, limit, offset)
		if err != nil {
			fail(c, err)
			return
		}
		apiresponse.OK(c, gin.H{"items": posts})
	})
	g.POST("/posts", func(c *gin.Context) {
		p, ok := auth.CurrentPrincipal(c)
		if !ok {
			apiresponse.Unauthorized(c)
			return
		}
		var req struct {
			Body string `json:"body"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			apiresponse.BadRequest(c, "invalid JSON body")
			return
		}
		post, err := s.Create(c.Request.Context(), p.UserID, req.Body)
		if err != nil {
			fail(c, err)
			return
		}
		apiresponse.Created(c, post)
	})
	g.DELETE("/posts/:id", func(c *gin.Context) {
		p, ok := auth.CurrentPrincipal(c)
		if !ok {
			apiresponse.Unauthorized(c)
			return
		}
		if err := s.Delete(c.Request.Context(), p.UserID, c.Param("id")); err != nil {
			fail(c, err)
			return
		}
		apiresponse.NoContent(c)
	})
	g.POST("/posts/:id/report", func(c *gin.Context) {
		p, ok := auth.CurrentPrincipal(c)
		if !ok {
			apiresponse.Unauthorized(c)
			return
		}
		var req struct {
			Reason string `json:"reason"`
			Detail string `json:"detail"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			apiresponse.BadRequest(c, "invalid JSON body")
			return
		}
		if err := s.Report(c.Request.Context(), p.UserID, c.Param("id"), req.Reason, req.Detail); err != nil {
			fail(c, err)
			return
		}
		apiresponse.OK(c, gin.H{"reported": true})
	})
}
