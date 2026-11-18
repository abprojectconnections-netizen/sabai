package api

import (
	"database/sql"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/travel-super-app/backend/internal/auth"
	"github.com/travel-super-app/backend/internal/finance/money"
	"github.com/travel-super-app/backend/internal/finance/payment"
	"github.com/travel-super-app/backend/internal/platform/apiresponse"
)

// registerDev mounts the payment simulator. It exists ONLY while the provider is the mock and the environment is not production,
// so a deployment with a real PSP, or APP_ENV=prod, has no such route at all (404, not 403).
// It does not bypass anything: it signs a CHARGE_SUCCEEDED (or, with outcome FAILED, CHARGE_FAILED) event with the mock secret and delivers it through the same webhook
// handler a real provider would use, for the caller's own pending intent and its exact amount.
func registerDev(secured *gin.RouterGroup, d Deps, ps *payment.Service) {
	mock, ok := d.Provider.(payment.Mock)
	if !ok || d.Cfg.Environment == "prod" {
		return
	}
	secured.POST("/dev/payments/simulate", auth.RequirePermission("booking.create"), func(c *gin.Context) {
		if err := d.Cfg.Check(c.Request.Context(), d.DB); err != nil {
			disabled(c)
			return
		}
		var in struct {
			PaymentReference string `json:"payment_reference"`
			// Outcome picks the simulated provider result: SUCCEEDED (default) or FAILED. Nothing else is accepted.
			Outcome string `json:"outcome"`
		}
		if err := c.ShouldBindJSON(&in); err != nil || in.PaymentReference == "" {
			apiresponse.BadRequest(c, "payment_reference is required")
			return
		}
		eventType := "CHARGE_SUCCEEDED"
		switch in.Outcome {
		case "", "SUCCEEDED":
		case "FAILED":
			eventType = "CHARGE_FAILED"
		default:
			apiresponse.BadRequest(c, "outcome must be SUCCEEDED or FAILED")
			return
		}
		p, _ := auth.CurrentPrincipal(c)
		var amt, cur string
		err := d.DB.QueryRowContext(c.Request.Context(), "SELECT amount, currency_code FROM payment_intents WHERE payment_reference = ? AND user_id = ? AND status = 'PENDING'", in.PaymentReference, p.UserID).Scan(&amt, &cur)
		if err == sql.ErrNoRows {
			apiresponse.NotFound(c, "payment not found")
			return
		} else if err != nil {
			apiresponse.Internal(c)
			return
		}
		a, err := money.Parse(amt)
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		body, sig := mock.SignedEvent("sim_"+uuid.NewString(), eventType, in.PaymentReference, a, cur, time.Now())
		res, err := ps.HandleWebhook(c.Request.Context(), sig, body)
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		c.JSON(http.StatusOK, gin.H{"data": gin.H{"result": string(res), "sandbox": true, "outcome": eventType}, "request_id": c.GetString("request_id")})
	})
}
