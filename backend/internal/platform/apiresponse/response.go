package apiresponse

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

type envelope struct {
	Data      any        `json:"data,omitempty"`
	Error     *errorBody `json:"error,omitempty"`
	RequestID string     `json:"request_id"`
}
type errorBody struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func OK(c *gin.Context, data any) {
	c.JSON(http.StatusOK, envelope{Data: data, RequestID: c.GetString("request_id")})
}
func Created(c *gin.Context, data any) {
	c.JSON(http.StatusCreated, envelope{Data: data, RequestID: c.GetString("request_id")})
}
func BadRequest(c *gin.Context, message string) {
	c.JSON(http.StatusBadRequest, envelope{Error: &errorBody{Code: "VALIDATION_ERROR", Message: message}, RequestID: c.GetString("request_id")})
}
func Unauthorized(c *gin.Context) {
	c.JSON(http.StatusUnauthorized, envelope{Error: &errorBody{Code: "UNAUTHORIZED", Message: "invalid credentials"}, RequestID: c.GetString("request_id")})
}
func Forbidden(c *gin.Context) {
	c.JSON(http.StatusForbidden, envelope{Error: &errorBody{Code: "FORBIDDEN", Message: "insufficient permissions"}, RequestID: c.GetString("request_id")})
}
func ForbiddenWith(c *gin.Context, message string) {
	c.JSON(http.StatusForbidden, envelope{Error: &errorBody{Code: "FORBIDDEN", Message: message}, RequestID: c.GetString("request_id")})
}
func NotFound(c *gin.Context, message string) {
	c.JSON(http.StatusNotFound, envelope{Error: &errorBody{Code: "NOT_FOUND", Message: message}, RequestID: c.GetString("request_id")})
}
func Internal(c *gin.Context) {
	c.JSON(http.StatusInternalServerError, envelope{Error: &errorBody{Code: "INTERNAL_ERROR", Message: "an unexpected error occurred"}, RequestID: c.GetString("request_id")})
}
func Conflict(c *gin.Context, message string) {
	c.JSON(http.StatusConflict, envelope{Error: &errorBody{Code: "CONFLICT", Message: message}, RequestID: c.GetString("request_id")})
}
func TooManyRequests(c *gin.Context, message string) {
	c.JSON(http.StatusTooManyRequests, envelope{Error: &errorBody{Code: "RATE_LIMITED", Message: message}, RequestID: c.GetString("request_id")})
}
func FeatureDisabled(c *gin.Context, message string) {
	c.JSON(http.StatusServiceUnavailable, envelope{Error: &errorBody{Code: "FEATURE_DISABLED", Message: message}, RequestID: c.GetString("request_id")})
}
func NoContent(c *gin.Context) { c.Status(http.StatusNoContent) }

// Page reads ?limit (1..100, default 50) and ?offset (>=0, default 0); on invalid input it writes a 400 and returns ok=false.
func Page(c *gin.Context) (limit, offset int, ok bool) {
	limit, offset = 50, 0
	if v := c.Query("limit"); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n < 1 || n > 100 {
			BadRequest(c, "limit must be between 1 and 100")
			return 0, 0, false
		}
		limit = n
	}
	if v := c.Query("offset"); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n < 0 {
			BadRequest(c, "offset must be 0 or greater")
			return 0, 0, false
		}
		offset = n
	}
	return limit, offset, true
}
