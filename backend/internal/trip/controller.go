package trip

import (
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/travel-super-app/backend/internal/platform/apiresponse"
)

type createRequest struct {
	Name          string `json:"name"`
	DestinationID string `json:"destination_id"`
	StartDate     string `json:"start_date"`
	EndDate       string `json:"end_date"`
}

func RegisterRoutes(group *gin.RouterGroup) { group.GET("", list); group.POST("", create) }
func list(c *gin.Context)                   { apiresponse.OK(c, []gin.H{}) }
func create(c *gin.Context) {
	var req createRequest
	if err := c.ShouldBindJSON(&req); err != nil || req.Name == "" {
		apiresponse.BadRequest(c, "trip name is required")
		return
	}
	apiresponse.Created(c, gin.H{"id": uuid.NewString(), "name": req.Name, "destination_id": req.DestinationID, "start_date": req.StartDate, "end_date": req.EndDate, "status": "DRAFT", "created_at": time.Now().UTC()})
}
