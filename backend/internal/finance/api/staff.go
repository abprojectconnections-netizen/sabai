package api

import (
	"errors"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/travel-super-app/backend/internal/auth"
	"github.com/travel-super-app/backend/internal/finance/refund"
	"github.com/travel-super-app/backend/internal/finance/safety"
	"github.com/travel-super-app/backend/internal/finance/settlement"
	"github.com/travel-super-app/backend/internal/platform/apiresponse"
)

// RegisterRefunds mounts the customer refund endpoints on the authenticated group.
func RegisterRefunds(secured *gin.RouterGroup, d Deps) {
	rs := refund.NewService(d.DB, d.Provider, d.Cfg)
	user := auth.RequirePermission("booking.create")
	secured.POST("/refunds", user, func(c *gin.Context) {
		var b struct {
			BookingID string `json:"booking_id"`
			Reason    string `json:"reason_code"`
			Method    string `json:"method"`
		}
		if err := c.ShouldBindJSON(&b); err != nil || b.BookingID == "" {
			apiresponse.BadRequest(c, "booking_id and method are required")
			return
		}
		if b.Reason == "" {
			b.Reason = "CUSTOMER_CANCELLATION"
		}
		p, _ := auth.CurrentPrincipal(c)
		r, err := rs.Create(c.Request.Context(), p.UserID, b.BookingID, b.Reason, b.Method, c.GetHeader("Idempotency-Key"), c.GetString("request_id"))
		if err == nil && r.Status == "APPROVED" && b.Method == "ORIGINAL_METHOD" {
			if xerr := rs.Execute(c.Request.Context(), r.ID); xerr == nil {
				r.Status = "COMPLETED"
			}
		}
		refundErr(c, err, func() {
			apiresponse.Created(c, gin.H{"id": r.ID, "status": r.Status, "calculated_amount": r.Calculated.String(), "auto_approved": r.Auto})
		})
	})
	secured.POST("/refunds/:id/consent", user, func(c *gin.Context) {
		var b struct {
			VersionID string `json:"consent_version_id"`
			Hash      string `json:"text_sha256"`
		}
		if err := c.ShouldBindJSON(&b); err != nil || b.VersionID == "" || b.Hash == "" {
			apiresponse.BadRequest(c, "consent_version_id and text_sha256 are required")
			return
		}
		p, _ := auth.CurrentPrincipal(c)
		err := rs.RecordConsent(c.Request.Context(), p.UserID, c.Param("id"), b.VersionID, b.Hash, c.ClientIP(), c.GetHeader("User-Agent"))
		if err == nil {
			// the refund may already be approved: now it can be paid out
			_ = rs.Execute(c.Request.Context(), c.Param("id"))
		}
		refundErr(c, err, func() { apiresponse.OK(c, gin.H{"recorded": true}) })
	})
}

func refundErr(c *gin.Context, err error, ok func()) {
	switch {
	case err == nil:
		ok()
	case errors.Is(err, safety.ErrDisabled), errors.Is(err, safety.ErrNotAllowed):
		disabled(c)
	case errors.Is(err, refund.ErrNotFound):
		apiresponse.NotFound(c, "not found")
	case errors.Is(err, refund.ErrNothingDue), errors.Is(err, refund.ErrBadMethod), errors.Is(err, refund.ErrConsentWording):
		apiresponse.BadRequest(c, err.Error())
	case errors.Is(err, refund.ErrSelfApproval), errors.Is(err, refund.ErrLimit):
		apiresponse.ForbiddenWith(c, err.Error())
	case errors.Is(err, refund.ErrNotRefundable), errors.Is(err, refund.ErrWrongState), errors.Is(err, refund.ErrAlreadyDecided), errors.Is(err, refund.ErrConsentRequired):
		apiresponse.Conflict(c, err.Error())
	default:
		apiresponse.Internal(c)
	}
}

// RegisterStaff mounts refund approval and settlement endpoints on the portal group (portal.read already required).
func RegisterStaff(portal *gin.RouterGroup, d Deps) {
	rs := refund.NewService(d.DB, d.Provider, d.Cfg)
	ss := settlement.NewService(d.DB, d.Provider, d.Cfg)
	decide := func(approve bool) gin.HandlerFunc {
		return func(c *gin.Context) {
			var b struct {
				Reason string `json:"reason"`
			}
			_ = c.ShouldBindJSON(&b)
			p, _ := auth.CurrentPrincipal(c)
			status, err := rs.Decide(c.Request.Context(), refund.Approver{UserID: p.UserID, Roles: p.Roles}, c.Param("id"), approve, b.Reason, c.GetString("request_id"))
			if err == nil && status == "APPROVED" {
				if xerr := rs.Execute(c.Request.Context(), c.Param("id")); xerr == nil {
					status = "COMPLETED"
				}
			}
			refundErr(c, err, func() { apiresponse.OK(c, gin.H{"id": c.Param("id"), "status": status}) })
		}
	}
	perm := auth.RequirePermission("refund.approve")
	portal.POST("/refunds/:id/approve", perm, decide(true))
	portal.POST("/refunds/:id/reject", perm, decide(false))

	settleErr := func(c *gin.Context, err error, ok func()) {
		switch {
		case err == nil:
			ok()
		case errors.Is(err, safety.ErrDisabled), errors.Is(err, safety.ErrNotAllowed):
			disabled(c)
		case errors.Is(err, settlement.ErrNotFound):
			apiresponse.NotFound(c, "batch not found")
		case errors.Is(err, settlement.ErrSoD):
			apiresponse.ForbiddenWith(c, err.Error())
		case errors.Is(err, settlement.ErrExists), errors.Is(err, settlement.ErrState), errors.Is(err, settlement.ErrNothing), errors.Is(err, settlement.ErrNoAccount), errors.Is(err, settlement.ErrNoPolicy), errors.Is(err, settlement.ErrNegative):
			apiresponse.Conflict(c, err.Error())
		default:
			apiresponse.Internal(c)
		}
	}
	portal.POST("/settlements/build", auth.RequirePermission("settlement.review"), func(c *gin.Context) {
		var raw struct {
			PartnerID string `json:"partner_id"`
			From      string `json:"period_from"`
			To        string `json:"period_to"`
			AsOf      string `json:"as_of"`
		}
		if err := c.ShouldBindJSON(&raw); err != nil || raw.PartnerID == "" {
			apiresponse.BadRequest(c, "partner_id, period_from, period_to are required")
			return
		}
		from, e1 := time.Parse("2006-01-02", raw.From)
		to, e2 := time.Parse("2006-01-02", raw.To)
		asOf := time.Now().UTC()
		if raw.AsOf != "" {
			var e3 error
			if asOf, e3 = time.Parse("2006-01-02", raw.AsOf); e3 != nil {
				apiresponse.BadRequest(c, "as_of must be YYYY-MM-DD")
				return
			}
		}
		if e1 != nil || e2 != nil || to.Before(from) {
			apiresponse.BadRequest(c, "period_from/period_to must be valid dates")
			return
		}
		p, _ := auth.CurrentPrincipal(c)
		bt, err := ss.Build(c.Request.Context(), p.UserID, raw.PartnerID, from, to, asOf)
		settleErr(c, err, func() {
			apiresponse.Created(c, gin.H{"id": bt.ID, "status": bt.Status, "items": bt.Items, "gross": bt.Gross.String(), "commission": bt.Commission.String(), "net": bt.Net.String()})
		})
	})
	portal.POST("/settlements/:id/review", auth.RequirePermission("settlement.review"), func(c *gin.Context) {
		p, _ := auth.CurrentPrincipal(c)
		settleErr(c, ss.Review(c.Request.Context(), p.UserID, c.Param("id")), func() { apiresponse.OK(c, gin.H{"status": "UNDER_REVIEW"}) })
	})
	portal.POST("/settlements/:id/approve", auth.RequirePermission("settlement.approve"), func(c *gin.Context) {
		p, _ := auth.CurrentPrincipal(c)
		settleErr(c, ss.Approve(c.Request.Context(), p.UserID, c.Param("id")), func() { apiresponse.OK(c, gin.H{"status": "APPROVED"}) })
	})
	portal.POST("/settlements/:id/payout", auth.RequirePermission("settlement.approve"), func(c *gin.Context) {
		p, _ := auth.CurrentPrincipal(c)
		settleErr(c, ss.Payout(c.Request.Context(), p.UserID, c.Param("id")), func() { apiresponse.OK(c, gin.H{"status": "PAID"}) })
	})
}
