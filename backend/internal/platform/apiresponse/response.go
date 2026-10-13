package apiresponse

import (
	"net/http"

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
func NotFound(c *gin.Context, message string) {
	c.JSON(http.StatusNotFound, envelope{Error: &errorBody{Code: "NOT_FOUND", Message: message}, RequestID: c.GetString("request_id")})
}
func Internal(c *gin.Context) {
	c.JSON(http.StatusInternalServerError, envelope{Error: &errorBody{Code: "INTERNAL_ERROR", Message: "an unexpected error occurred"}, RequestID: c.GetString("request_id")})
}
