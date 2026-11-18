package httpapi

import (
	"database/sql"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/travel-super-app/backend/internal/admin"
	"github.com/travel-super-app/backend/internal/auth"
	"github.com/travel-super-app/backend/internal/community"
	"github.com/travel-super-app/backend/internal/coupon"
	financeapi "github.com/travel-super-app/backend/internal/finance/api"
	"github.com/travel-super-app/backend/internal/finance/payment"
	"github.com/travel-super-app/backend/internal/finance/safety"
	"github.com/travel-super-app/backend/internal/notification"
	"github.com/travel-super-app/backend/internal/portal"
	"github.com/travel-super-app/backend/internal/review"
	"github.com/travel-super-app/backend/internal/tag"
	"github.com/travel-super-app/backend/internal/trip"
)

// RegisterRoutes wires the API with financial settings read from the environment (safe defaults: disabled, mock provider).
func RegisterRoutes(router *gin.Engine, db *sql.DB, jwtSecret string) {
	RegisterRoutesWith(router, db, jwtSecret, safety.FromEnv(), payment.Mock{Secret: os.Getenv("MOCK_PSP_SECRET")})
}

func RegisterRoutesWith(router *gin.Engine, db *sql.DB, jwtSecret string, cfg safety.Config, provider payment.Provider) {
	router.GET("/health", func(c *gin.Context) {
		OK(c, gin.H{"status": "ok", "service": "travel-api", "timestamp": time.Now().UTC()})
	})
	v1 := router.Group("/api/v1")
	auth.RegisterRoutes(v1.Group("/auth"), auth.NewService(db, jwtSecret))
	secured := v1.Group("")
	secured.Use(auth.Authenticate(db, jwtSecret))
	financeapi.Register(v1, secured, financeapi.Deps{DB: db, Cfg: cfg, Provider: provider})
	trips := secured.Group("/trips")
	trips.Use(auth.RequireRoles("CUSTOMER", "PARTNER", "STAFF", "ADMIN"))
	trip.RegisterRoutes(trips, trip.NewService(db))
	userRoles := auth.RequireRoles("CUSTOMER", "PARTNER", "STAFF", "ADMIN")
	notifications := secured.Group("/notifications")
	notifications.Use(userRoles)
	notification.RegisterRoutes(notifications, notification.NewService(db))
	reviews := secured.Group("/reviews")
	reviews.Use(userRoles)
	review.RegisterRoutes(reviews, review.NewService(db))
	communityRoutes := secured.Group("/community")
	communityRoutes.Use(userRoles)
	community.RegisterRoutes(communityRoutes, community.NewService(db))
	couponRoutes := secured.Group("/coupons")
	couponRoutes.Use(userRoles)
	coupon.RegisterRoutes(couponRoutes, coupon.NewService(db))
	tagRoutes := secured.Group("")
	tagRoutes.Use(userRoles)
	tag.RegisterRoutes(tagRoutes, tag.NewService(db))
	portalRoutes := secured.Group("/portal")
	portalRoutes.Use(auth.RequirePermission("portal.read"))
	portal.RegisterRoutes(portalRoutes, db)
	community.RegisterStaffRoutes(portalRoutes, community.NewService(db))
	financeapi.RegisterStaff(portalRoutes, financeapi.Deps{DB: db, Cfg: cfg, Provider: provider})
	adminRoutes := secured.Group("/admin")
	adminRoutes.Use(auth.RequirePermission("role.request", "role.approve", "role.approve.financial"))
	admin.RegisterRoutes(adminRoutes, db)
}
