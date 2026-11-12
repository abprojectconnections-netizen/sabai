// Package api exposes the financial endpoints. Handlers never accept an amount from the client.
package api

import (
	"database/sql"
	"errors"
	"io"

	"github.com/gin-gonic/gin"
	"github.com/travel-super-app/backend/internal/auth"
	"github.com/travel-super-app/backend/internal/finance/booking"
	"github.com/travel-super-app/backend/internal/finance/payment"
	"github.com/travel-super-app/backend/internal/finance/safety"
	"github.com/travel-super-app/backend/internal/platform/apiresponse"
)

type Deps struct {
	DB       *sql.DB
	Cfg      safety.Config
	Provider payment.Provider
}

// Register mounts customer endpoints on `secured` (already authenticated) and the provider webhook on `public`.
func Register(public, secured *gin.RouterGroup, d Deps) {
	bs := booking.NewService(d.DB)
	ps := payment.NewService(d.DB, d.Provider, d.Cfg)
	user := auth.RequirePermission("booking.create")
	secured.POST("/bookings", user, createBooking(bs, d))
	secured.POST("/payments/intents", user, createIntent(ps))
	public.POST("/webhooks/payments", webhook(ps))
	RegisterRefunds(secured, d)
	RegisterReads(public, secured, d)
}

type bookingBody struct {
	Items      []booking.ItemInput `json:"items"`
	CouponCode string              `json:"coupon_code"`
}

func disabled(c *gin.Context) {
	c.JSON(503, gin.H{"error": gin.H{"code": "FINANCIAL_TRANSACTIONS_DISABLED", "message": "financial transactions are not enabled in this environment"}, "request_id": c.GetString("request_id")})
}

func createBooking(s *booking.Service, d Deps) gin.HandlerFunc {
	return func(c *gin.Context) {
		if err := d.Cfg.Check(c.Request.Context(), d.DB); err != nil {
			disabled(c)
			return
		}
		var b bookingBody
		if err := c.ShouldBindJSON(&b); err != nil {
			apiresponse.BadRequest(c, "invalid body")
			return
		}
		p, _ := auth.CurrentPrincipal(c)
		r, err := s.Create(c.Request.Context(), booking.Input{UserID: p.UserID, IdempotencyKey: c.GetHeader("Idempotency-Key"), CouponCode: b.CouponCode, Items: b.Items, RequestID: c.GetString("request_id"), IP: c.ClientIP()})
		var ve booking.ValidationError
		switch {
		case errors.As(err, &ve):
			apiresponse.BadRequest(c, ve.Msg)
		case errors.Is(err, booking.ErrUnavailable):
			apiresponse.Conflict(c, "not enough availability")
		case errors.Is(err, booking.ErrCoupon):
			apiresponse.BadRequest(c, "coupon is not valid for this booking")
		case err != nil:
			apiresponse.Internal(c)
		default:
			out := gin.H{"id": r.ID, "booking_code": r.Code, "status": r.Status, "currency": r.Currency, "base_total": r.BaseTotal.String(), "discount_total": r.DiscountTotal.String(), "payable_total": r.PayableTotal.String(), "expires_at": r.ExpiresAt, "replayed": r.Replayed}
			if r.Replayed {
				apiresponse.OK(c, out)
			} else {
				apiresponse.Created(c, out)
			}
		}
	}
}

func createIntent(s *payment.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		var b struct {
			BookingID string `json:"booking_id"`
			Method    string `json:"method"`
		}
		if err := c.ShouldBindJSON(&b); err != nil || b.BookingID == "" {
			apiresponse.BadRequest(c, "booking_id and method are required")
			return
		}
		p, _ := auth.CurrentPrincipal(c)
		in, err := s.CreateIntent(c.Request.Context(), p.UserID, b.BookingID, b.Method, c.GetHeader("Idempotency-Key"), c.GetString("request_id"), c.ClientIP())
		switch {
		case errors.Is(err, safety.ErrDisabled), errors.Is(err, safety.ErrNotAllowed):
			disabled(c)
		case errors.Is(err, payment.ErrNotFound):
			apiresponse.NotFound(c, "booking not found")
		case errors.Is(err, payment.ErrNotPayable), errors.Is(err, payment.ErrBookingGone):
			apiresponse.Conflict(c, err.Error())
		case errors.Is(err, payment.ErrBadMethod):
			apiresponse.BadRequest(c, err.Error())
		case err != nil && err.Error() == "Idempotency-Key header is required":
			apiresponse.BadRequest(c, err.Error())
		case err != nil:
			apiresponse.Internal(c)
		default:
			out := gin.H{"id": in.ID, "payment_reference": in.Reference, "status": in.Status, "method": in.Method, "amount": in.Amount.String(), "currency": in.Currency, "qr_payload": in.QR, "expires_at": in.ExpiresAt, "replayed": in.Replayed}
			if in.Replayed {
				apiresponse.OK(c, out)
			} else {
				apiresponse.Created(c, out)
			}
		}
	}
}

func webhook(s *payment.Service) gin.HandlerFunc {
	return func(c *gin.Context) {
		body, err := io.ReadAll(io.LimitReader(c.Request.Body, 1<<20))
		if err != nil {
			apiresponse.BadRequest(c, "unreadable body")
			return
		}
		res, err := s.HandleWebhook(c.Request.Context(), c.GetHeader("X-Signature"), body)
		switch {
		case res == payment.RejectedSignature:
			apiresponse.Unauthorized(c)
		case res == payment.RejectedReplay:
			apiresponse.BadRequest(c, "event timestamp outside the accepted window")
		case err != nil:
			apiresponse.Internal(c) // 5xx makes the provider retry
		default:
			apiresponse.OK(c, gin.H{"result": string(res)})
		}
	}
}
