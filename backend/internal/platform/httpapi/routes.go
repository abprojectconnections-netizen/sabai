package httpapi

import (
	"database/sql"
	"os"
	"strconv"
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
	"github.com/travel-super-app/backend/internal/platform/ratelimit"
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
	authRoutes := v1.Group("/auth")
	// Sign-in and registration are limited per client IP. AUTH_RATE_LIMIT_PER_MIN overrides the default; 0 turns it off.
	authRoutes.Use(ratelimit.New(envInt("AUTH_RATE_LIMIT_PER_MIN", 30), time.Minute).PerIPWrites())
	auth.RegisterRoutes(authRoutes, auth.NewService(db, jwtSecret))
	secured := v1.Group("")
	secured.Use(auth.Authenticate(db, jwtSecret))
	secured.GET("/me", auth.Me())
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
	communityRoutes.Use(userRoles, ratelimit.New(10, time.Minute).PerUserWrites()) // posts, deletes and reports share one budget
	community.RegisterRoutes(communityRoutes, community.NewService(db))
	couponRoutes := secured.Group("/coupons")
	couponRoutes.Use(userRoles, ratelimit.New(10, time.Minute).PerUserWrites()) // slows down guessing coupon codes
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
	admin.RegisterConsoleRoutes(secured.Group("/admin"), db)
}

// envInt reads a non-negative integer from the environment, falling back to def when it is unset or invalid.
func envInt(name string, def int) int {
	if v := os.Getenv(name); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n >= 0 {
			return n
		}
	}
	return def
}
