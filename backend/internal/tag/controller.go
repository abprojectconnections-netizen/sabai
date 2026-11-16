package tag

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
		apiresponse.NotFound(c, "content not found")
	case errors.Is(err, ErrValidation):
		apiresponse.BadRequest(c, strings.TrimPrefix(strings.TrimPrefix(err.Error(), ErrValidation.Error()), "\n"))
	default:
		apiresponse.Internal(c)
	}
}

// RegisterRoutes mounts the tag endpoints on a signed-in group:
//
//	GET /tags?q=prefix                      popular tags (public content only), for autocomplete
//	GET /tags/:slug/content?type=REVIEW     ids of content with a tag that the caller may see
//	GET /content/:type/:id/tags             tags of one item
//	PUT /content/:type/:id/tags             replace the tags of one item (owner only): {"tags": ["ธรรมชาติ", "cafe"]}
func RegisterRoutes(g *gin.RouterGroup, s *Service) {
	g.GET("/tags", func(c *gin.Context) {
		limit, offset, ok := apiresponse.Page(c)
		if !ok {
			return
		}
		out, err := s.Popular(c.Request.Context(), c.Query("q"), limit, offset)
		if err != nil {
			fail(c, err)
			return
		}
		apiresponse.OK(c, out)
	})
	g.GET("/tags/:slug/content", func(c *gin.Context) {
		p, ok := auth.CurrentPrincipal(c)
		if !ok {
			apiresponse.Unauthorized(c)
			return
		}
		limit, offset, ok := apiresponse.Page(c)
		if !ok {
			return
		}
		ids, err := s.ContentByTag(c.Request.Context(), p.UserID, c.Param("slug"), c.Query("type"), limit, offset)
		if err != nil {
			fail(c, err)
			return
		}
		apiresponse.OK(c, gin.H{"items": ids})
	})
	g.GET("/content/:type/:id/tags", func(c *gin.Context) {
		p, ok := auth.CurrentPrincipal(c)
		if !ok {
			apiresponse.Unauthorized(c)
			return
		}
		out, err := s.TagsOf(c.Request.Context(), p.UserID, c.Param("type"), c.Param("id"))
		if err != nil {
			fail(c, err)
			return
		}
		apiresponse.OK(c, out)
	})
	g.PUT("/content/:type/:id/tags", func(c *gin.Context) {
		p, ok := auth.CurrentPrincipal(c)
		if !ok {
			apiresponse.Unauthorized(c)
			return
		}
		var req struct {
			Tags []string `json:"tags"`
		}
		if err := c.ShouldBindJSON(&req); err != nil || req.Tags == nil {
			apiresponse.BadRequest(c, "body must be {\"tags\": [...]}")
			return
		}
		out, err := s.Set(c.Request.Context(), p.UserID, c.Param("type"), c.Param("id"), req.Tags)
		if err != nil {
			fail(c, err)
			return
		}
		apiresponse.OK(c, out)
	})
}
