package trip

import (
	"errors"

	"github.com/gin-gonic/gin"
	"github.com/travel-super-app/backend/internal/auth"
	"github.com/travel-super-app/backend/internal/platform/apiresponse"
)

type createRequest struct {
	Name          string `json:"name"`
	DestinationID string `json:"destination_id"`
	StartDate     string `json:"start_date"`
	EndDate       string `json:"end_date"`
}

type updateRequest struct {
	Name          *string `json:"name"`
	DestinationID *string `json:"destination_id"`
	StartDate     *string `json:"start_date"`
	EndDate       *string `json:"end_date"`
	Status        *string `json:"status"`
}

type activityRequest struct {
	Title         string `json:"title"`
	Date          string `json:"date"`
	StartTime     string `json:"start_time"`
	EndTime       string `json:"end_time"`
	DestinationID string `json:"destination_id"`
}

func RegisterRoutes(group *gin.RouterGroup, service *Service) {
	group.GET("", list(service))
	group.POST("", create(service))
	group.GET("/:id", get(service))
	group.PATCH("/:id", update(service))
	group.DELETE("/:id", remove(service))
	group.POST("/:id/activities", addActivity(service))
	group.DELETE("/:id/activities/:activityId", removeActivity(service))
}

// fail maps service errors to the API error envelope.
func fail(c *gin.Context, err error) {
	switch {
	case errors.Is(err, ErrNotFound):
		apiresponse.NotFound(c, "trip not found")
	case errors.Is(err, ErrValidation):
		apiresponse.BadRequest(c, trimPrefix(err))
	default:
		apiresponse.Internal(c)
	}
}

func trimPrefix(err error) string {
	msg := err.Error()
	const p = "validation error: "
	if len(msg) > len(p) && msg[:len(p)] == p {
		return msg[len(p):]
	}
	return msg
}

func userID(c *gin.Context) (string, bool) {
	p, ok := auth.CurrentPrincipal(c)
	if !ok {
		apiresponse.Unauthorized(c)
		return "", false
	}
	return p.UserID, true
}

func list(s *Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid, ok := userID(c)
		if !ok {
			return
		}
		limit, offset, ok := apiresponse.Page(c)
		if !ok {
			return
		}
		trips, err := s.List(c.Request.Context(), uid, limit, offset)
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		apiresponse.OK(c, trips)
	}
}

func create(s *Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid, ok := userID(c)
		if !ok {
			return
		}
		var req createRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			apiresponse.BadRequest(c, "invalid JSON body")
			return
		}
		t, err := s.Create(c.Request.Context(), uid, CreateInput(req))
		if err != nil {
			fail(c, err)
			return
		}
		apiresponse.Created(c, t)
	}
}

func get(s *Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid, ok := userID(c)
		if !ok {
			return
		}
		t, err := s.Get(c.Request.Context(), uid, c.Param("id"))
		if err != nil {
			fail(c, err)
			return
		}
		apiresponse.OK(c, t)
	}
}

func update(s *Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid, ok := userID(c)
		if !ok {
			return
		}
		var req updateRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			apiresponse.BadRequest(c, "invalid JSON body")
			return
		}
		t, err := s.Update(c.Request.Context(), uid, c.Param("id"), UpdateInput(req))
		if err != nil {
			fail(c, err)
			return
		}
		apiresponse.OK(c, t)
	}
}

func remove(s *Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid, ok := userID(c)
		if !ok {
			return
		}
		if err := s.Delete(c.Request.Context(), uid, c.Param("id")); err != nil {
			fail(c, err)
			return
		}
		apiresponse.NoContent(c)
	}
}

func addActivity(s *Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid, ok := userID(c)
		if !ok {
			return
		}
		var req activityRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			apiresponse.BadRequest(c, "invalid JSON body")
			return
		}
		a, err := s.AddActivity(c.Request.Context(), uid, c.Param("id"), ActivityInput(req))
		if err != nil {
			fail(c, err)
			return
		}
		apiresponse.Created(c, a)
	}
}

func removeActivity(s *Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid, ok := userID(c)
		if !ok {
			return
		}
		if err := s.DeleteActivity(c.Request.Context(), uid, c.Param("id"), c.Param("activityId")); err != nil {
			fail(c, err)
			return
		}
		apiresponse.NoContent(c)
	}
}
