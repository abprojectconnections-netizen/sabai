package httpapi

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
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

func RequestID() gin.HandlerFunc {
	return func(c *gin.Context) {
		requestID := c.GetHeader("X-Request-ID")
		if requestID == "" {
			requestID = uuid.NewString()
		}
		c.Set("request_id", requestID)
		c.Header("X-Request-ID", requestID)
		c.Next()
	}
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
