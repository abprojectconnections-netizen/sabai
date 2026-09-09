package auth

import (
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/travel-super-app/backend/internal/platform/apiresponse"
)

type registerRequest struct {
	Email       string `json:"email"`
	Password    string `json:"password"`
	DisplayName string `json:"display_name"`
}
type loginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func RegisterRoutes(group *gin.RouterGroup, service *Service) {
	group.POST("/register", register(service))
	group.POST("/login", login(service))
}

func register(service *Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req registerRequest
		if err := c.ShouldBindJSON(&req); err != nil || !strings.Contains(req.Email, "@") || len(req.Password) < 8 {
			apiresponse.BadRequest(c, "email and a password of at least 8 characters are required")
			return
		}
		account, token, err := service.Register(c.Request.Context(), req.Email, req.Password, req.DisplayName)
		if err == ErrEmailTaken {
			apiresponse.BadRequest(c, err.Error())
			return
		}
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		apiresponse.Created(c, gin.H{"user": gin.H{"id": account.ID, "email": account.Email, "display_name": account.DisplayName}, "access_token": token, "token_type": "Bearer"})
	}
}
func login(service *Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req loginRequest
		if err := c.ShouldBindJSON(&req); err != nil || req.Email == "" || req.Password == "" {
			apiresponse.BadRequest(c, "email and password are required")
			return
		}
		token, err := service.Login(c.Request.Context(), req.Email, req.Password)
		if err == ErrInvalidCredentials {
			apiresponse.Unauthorized(c)
			return
		}
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		apiresponse.OK(c, gin.H{"access_token": token, "token_type": "Bearer"})
	}
}
