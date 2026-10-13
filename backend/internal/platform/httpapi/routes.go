package httpapi

import (
	"database/sql"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/travel-super-app/backend/internal/admin"
	"github.com/travel-super-app/backend/internal/auth"
	"github.com/travel-super-app/backend/internal/portal"
	"github.com/travel-super-app/backend/internal/trip"
)

func RegisterRoutes(router *gin.Engine, db *sql.DB, jwtSecret string) {
	router.GET("/health", func(c *gin.Context) {
		OK(c, gin.H{"status": "ok", "service": "travel-api", "timestamp": time.Now().UTC()})
	})
	v1 := router.Group("/api/v1")
	auth.RegisterRoutes(v1.Group("/auth"), auth.NewService(db, jwtSecret))
	secured := v1.Group("")
	secured.Use(auth.Authenticate(db, jwtSecret))
	trips := secured.Group("/trips")
	trips.Use(auth.RequireRoles("CUSTOMER", "PARTNER", "STAFF", "ADMIN"))
	trip.RegisterRoutes(trips)
	portalRoutes := secured.Group("/portal")
	portalRoutes.Use(auth.RequireRoles("STAFF", "ADMIN"))
	portal.RegisterRoutes(portalRoutes, db)
	adminRoutes := secured.Group("/admin")
	adminRoutes.Use(auth.RequireRoles("ADMIN"))
	admin.RegisterRoutes(adminRoutes, db)
}
