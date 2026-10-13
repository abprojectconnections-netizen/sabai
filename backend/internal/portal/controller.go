package portal

import (
	"database/sql"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/travel-super-app/backend/internal/audit"
	"github.com/travel-super-app/backend/internal/auth"
	"github.com/travel-super-app/backend/internal/platform/apiresponse"
)

type statusRequest struct {
	Status string `json:"status"`
	Note   string `json:"note"`
}
type assignRequest struct {
	StaffUserID string `json:"staff_user_id"`
}
type disputeRequest struct {
	BookingID   string `json:"booking_id"`
	Reason      string `json:"reason"`
	Description string `json:"description"`
}

func RegisterRoutes(group *gin.RouterGroup, db *sql.DB) {
	group.GET("/queue", queue(db))
	group.PATCH("/bookings/:id/status", statusChange(db, "bookings", "booking", "booking.status.changed", []string{"PENDING", "CONFIRMED", "CANCELLED"}))
	group.PATCH("/payments/:id/verify", statusChange(db, "payments", "payment", "payment.status.verified", []string{"PAID", "FAILED", "REFUNDED"}))
	group.PATCH("/partners/:id/approval", statusChange(db, "partners", "partner", "partner.approval.changed", []string{"APPROVED", "REJECTED", "SUSPENDED"}))
	group.PATCH("/tickets/:id/assign", ticketAssign(db))
	group.PATCH("/tickets/:id/status", statusChange(db, "support_tickets", "support_ticket", "support.ticket.status.changed", []string{"OPEN", "IN_PROGRESS", "RESOLVED", "CLOSED"}))
	group.POST("/disputes", createDispute(db))
	group.PATCH("/disputes/:id/status", statusChange(db, "disputes", "dispute", "dispute.status.changed", []string{"IN_REVIEW", "RESOLVED", "REJECTED"}))
}
func queue(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		result := gin.H{}
		queries := map[string]string{"pending_bookings": "SELECT COUNT(*) FROM bookings WHERE status='PENDING' AND deleted_at IS NULL", "pending_payments": "SELECT COUNT(*) FROM payments WHERE status='PENDING' AND deleted_at IS NULL", "pending_partners": "SELECT COUNT(*) FROM partners WHERE status='PENDING' AND deleted_at IS NULL", "open_tickets": "SELECT COUNT(*) FROM support_tickets WHERE status IN ('OPEN','IN_PROGRESS') AND deleted_at IS NULL", "open_disputes": "SELECT COUNT(*) FROM disputes WHERE status IN ('OPEN','IN_REVIEW') AND deleted_at IS NULL"}
		for key, q := range queries {
			var count int
			if err := db.QueryRowContext(c, q).Scan(&count); err != nil {
				apiresponse.Internal(c)
				return
			}
			result[key] = count
		}
		apiresponse.OK(c, result)
	}
}
func statusChange(db *sql.DB, table, subject, action string, allowed []string) gin.HandlerFunc {
	return func(c *gin.Context) {
		var r statusRequest
		if err := c.ShouldBindJSON(&r); err != nil || !oneOf(r.Status, allowed) {
			apiresponse.BadRequest(c, "invalid status")
			return
		}
		id := c.Param("id")
		var old string
		if err := db.QueryRowContext(c, "SELECT status FROM "+table+" WHERE id=? AND deleted_at IS NULL", id).Scan(&old); err == sql.ErrNoRows {
			apiresponse.NotFound(c, subject+" not found")
			return
		} else if err != nil {
			apiresponse.Internal(c)
			return
		}
		if _, err := db.ExecContext(c, "UPDATE "+table+" SET status=?,updated_at=? WHERE id=?", r.Status, time.Now().UTC(), id); err != nil {
			apiresponse.Internal(c)
			return
		}
		auditChange(c, db, action, subject, id, gin.H{"status": old}, gin.H{"status": r.Status, "note": r.Note})
		apiresponse.OK(c, gin.H{"id": id, "status": r.Status})
	}
}
func ticketAssign(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var r assignRequest
		if err := c.ShouldBindJSON(&r); err != nil || r.StaffUserID == "" {
			apiresponse.BadRequest(c, "staff_user_id is required")
			return
		}
		id := c.Param("id")
		var old sql.NullString
		if err := db.QueryRowContext(c, "SELECT assigned_staff_id FROM support_tickets WHERE id=? AND deleted_at IS NULL", id).Scan(&old); err == sql.ErrNoRows {
			apiresponse.NotFound(c, "ticket not found")
			return
		} else if err != nil {
			apiresponse.Internal(c)
			return
		}
		if _, err := db.ExecContext(c, "UPDATE support_tickets SET assigned_staff_id=?,status='IN_PROGRESS',updated_at=? WHERE id=?", r.StaffUserID, time.Now().UTC(), id); err != nil {
			apiresponse.Internal(c)
			return
		}
		auditChange(c, db, "support.ticket.assigned", "support_ticket", id, gin.H{"assigned_staff_id": old.String}, gin.H{"assigned_staff_id": r.StaffUserID, "status": "IN_PROGRESS"})
		apiresponse.OK(c, gin.H{"id": id, "assigned_staff_id": r.StaffUserID, "status": "IN_PROGRESS"})
	}
}
func createDispute(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var r disputeRequest
		if err := c.ShouldBindJSON(&r); err != nil || r.BookingID == "" || r.Reason == "" {
			apiresponse.BadRequest(c, "booking_id and reason are required")
			return
		}
		p, _ := auth.CurrentPrincipal(c)
		id := uuid.NewString()
		now := time.Now().UTC()
		if _, err := db.ExecContext(c, "INSERT INTO disputes (id,created_at,updated_at,booking_id,opened_by_user_id,reason,description,status) VALUES (?,?,?,?,?,?,?,'OPEN')", id, now, now, r.BookingID, p.UserID, r.Reason, r.Description); err != nil {
			apiresponse.Internal(c)
			return
		}
		auditChange(c, db, "dispute.opened", "dispute", id, gin.H{}, gin.H{"booking_id": r.BookingID, "reason": r.Reason, "status": "OPEN"})
		apiresponse.Created(c, gin.H{"id": id, "status": "OPEN"})
	}
}
func auditChange(c *gin.Context, db *sql.DB, action, subject, id string, before, after any) {
	p, _ := auth.CurrentPrincipal(c)
	_ = audit.Log(c, db, audit.Entry{ActorUserID: p.UserID, Action: action, SubjectType: subject, SubjectID: id, Before: before, After: after, IPAddress: c.ClientIP(), RequestID: c.GetString("request_id")})
}
func oneOf(v string, a []string) bool {
	for _, x := range a {
		if v == x {
			return true
		}
	}
	return false
}
