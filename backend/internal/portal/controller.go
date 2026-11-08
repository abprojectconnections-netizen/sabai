package portal

import (
	"context"
	"database/sql"
	"errors"
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

// transitions lists the permitted status changes per subject. Every status change is validated against it,
// so a request can never jump to an arbitrary state. Payment status is deliberately absent: it may only be
// changed by a verified payment-provider callback or a server-side provider query, never by a person.
type transitions map[string][]string

var (
	bookingTransitions = transitions{"PENDING": {"CONFIRMED", "CANCELLED"}, "CONFIRMED": {"CANCELLED"}}
	partnerTransitions = transitions{"PENDING": {"APPROVED", "REJECTED"}, "APPROVED": {"SUSPENDED"}, "SUSPENDED": {"APPROVED"}}
	ticketTransitions  = transitions{"OPEN": {"IN_PROGRESS", "CLOSED"}, "IN_PROGRESS": {"RESOLVED", "CLOSED"}, "RESOLVED": {"IN_PROGRESS", "CLOSED"}}
	disputeTransitions = transitions{"OPEN": {"IN_REVIEW"}, "IN_REVIEW": {"RESOLVED", "REJECTED"}}
)

func RegisterRoutes(group *gin.RouterGroup, db *sql.DB) {
	group.GET("/queue", queue(db))
	group.PATCH("/bookings/:id/status", statusChange(db, "bookings", "booking", "booking.status.changed", bookingTransitions))
	group.PATCH("/partners/:id/approval", statusChange(db, "partners", "partner", "partner.approval.changed", partnerTransitions))
	group.PATCH("/tickets/:id/assign", ticketAssign(db))
	group.PATCH("/tickets/:id/status", statusChange(db, "support_tickets", "support_ticket", "support.ticket.status.changed", ticketTransitions))
	group.POST("/disputes", createDispute(db))
	group.PATCH("/disputes/:id/status", statusChange(db, "disputes", "dispute", "dispute.status.changed", disputeTransitions))
}

func queue(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		result := gin.H{}
		queries := map[string]string{"pending_bookings": "SELECT COUNT(*) FROM bookings WHERE status='PENDING' AND deleted_at IS NULL", "pending_payments": "SELECT COUNT(*) FROM payments WHERE status='PENDING' AND deleted_at IS NULL", "pending_partners": "SELECT COUNT(*) FROM partners WHERE status='PENDING' AND deleted_at IS NULL", "open_tickets": "SELECT COUNT(*) FROM support_tickets WHERE status IN ('OPEN','IN_PROGRESS') AND deleted_at IS NULL", "open_disputes": "SELECT COUNT(*) FROM disputes WHERE status IN ('OPEN','IN_REVIEW') AND deleted_at IS NULL"}
		for key, q := range queries {
			var count int
			if err := db.QueryRowContext(c.Request.Context(), q).Scan(&count); err != nil {
				apiresponse.Internal(c)
				return
			}
			result[key] = count
		}
		apiresponse.OK(c, result)
	}
}

var errNotFound = errors.New("not found")
var errConflict = errors.New("conflict")

// inTx runs fn in a transaction; any error (including a failed audit write) rolls everything back.
func inTx(ctx context.Context, db *sql.DB, fn func(tx *sql.Tx) error) error {
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if err := fn(tx); err != nil {
		return err
	}
	return tx.Commit()
}

func allowed(t transitions, from, to string) bool {
	for _, s := range t[from] {
		if s == to {
			return true
		}
	}
	return false
}

func isTarget(t transitions, status string) bool {
	for _, tos := range t {
		for _, s := range tos {
			if s == status {
				return true
			}
		}
	}
	return false
}

func statusChange(db *sql.DB, table, subject, action string, t transitions) gin.HandlerFunc {
	return func(c *gin.Context) {
		var r statusRequest
		if err := c.ShouldBindJSON(&r); err != nil || r.Status == "" {
			apiresponse.BadRequest(c, "status is required")
			return
		}
		if !isTarget(t, r.Status) {
			apiresponse.BadRequest(c, "invalid status")
			return
		}
		id := c.Param("id")
		err := inTx(c.Request.Context(), db, func(tx *sql.Tx) error {
			var old string
			// table comes from this package's own constants, never from the request.
			if err := tx.QueryRowContext(c.Request.Context(), "SELECT status FROM "+table+" WHERE id=? AND deleted_at IS NULL FOR UPDATE", id).Scan(&old); errors.Is(err, sql.ErrNoRows) {
				return errNotFound
			} else if err != nil {
				return err
			}
			if !allowed(t, old, r.Status) {
				return errConflict
			}
			if _, err := tx.ExecContext(c.Request.Context(), "UPDATE "+table+" SET status=?,updated_at=? WHERE id=? AND status=?", r.Status, time.Now().UTC(), id, old); err != nil {
				return err
			}
			return auditChange(c, tx, action, subject, id, gin.H{"status": old}, gin.H{"status": r.Status, "note": r.Note})
		})
		switch {
		case errors.Is(err, errNotFound):
			apiresponse.NotFound(c, subject+" not found")
		case errors.Is(err, errConflict):
			apiresponse.Conflict(c, "status change is not allowed from the current status")
		case err != nil:
			apiresponse.Internal(c)
		default:
			apiresponse.OK(c, gin.H{"id": id, "status": r.Status})
		}
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
		err := inTx(c.Request.Context(), db, func(tx *sql.Tx) error {
			var old sql.NullString
			if err := tx.QueryRowContext(c.Request.Context(), "SELECT assigned_staff_id FROM support_tickets WHERE id=? AND deleted_at IS NULL FOR UPDATE", id).Scan(&old); errors.Is(err, sql.ErrNoRows) {
				return errNotFound
			} else if err != nil {
				return err
			}
			if _, err := tx.ExecContext(c.Request.Context(), "UPDATE support_tickets SET assigned_staff_id=?,status='IN_PROGRESS',updated_at=? WHERE id=?", r.StaffUserID, time.Now().UTC(), id); err != nil {
				return err
			}
			return auditChange(c, tx, "support.ticket.assigned", "support_ticket", id, gin.H{"assigned_staff_id": old.String}, gin.H{"assigned_staff_id": r.StaffUserID, "status": "IN_PROGRESS"})
		})
		switch {
		case errors.Is(err, errNotFound):
			apiresponse.NotFound(c, "ticket not found")
		case err != nil:
			apiresponse.Internal(c)
		default:
			apiresponse.OK(c, gin.H{"id": id, "assigned_staff_id": r.StaffUserID, "status": "IN_PROGRESS"})
		}
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
		err := inTx(c.Request.Context(), db, func(tx *sql.Tx) error {
			var exists string
			if err := tx.QueryRowContext(c.Request.Context(), "SELECT id FROM bookings WHERE id=? AND deleted_at IS NULL", r.BookingID).Scan(&exists); errors.Is(err, sql.ErrNoRows) {
				return errNotFound
			} else if err != nil {
				return err
			}
			if _, err := tx.ExecContext(c.Request.Context(), "INSERT INTO disputes (id,created_at,updated_at,booking_id,opened_by_user_id,reason,description,status) VALUES (?,?,?,?,?,?,?,'OPEN')", id, now, now, r.BookingID, p.UserID, r.Reason, r.Description); err != nil {
				return err
			}
			return auditChange(c, tx, "dispute.opened", "dispute", id, gin.H{}, gin.H{"booking_id": r.BookingID, "reason": r.Reason, "status": "OPEN"})
		})
		switch {
		case errors.Is(err, errNotFound):
			apiresponse.NotFound(c, "booking not found")
		case err != nil:
			apiresponse.Internal(c)
		default:
			apiresponse.Created(c, gin.H{"id": id, "status": "OPEN"})
		}
	}
}

// auditChange writes the audit row on the caller's transaction and returns the error: if the audit cannot be
// recorded, the change it describes must not be committed either.
func auditChange(c *gin.Context, tx audit.Execer, action, subject, id string, before, after any) error {
	p, _ := auth.CurrentPrincipal(c)
	return audit.Log(c.Request.Context(), tx, audit.Entry{ActorUserID: p.UserID, Action: action, SubjectType: subject, SubjectID: id, Before: before, After: after, IPAddress: c.ClientIP(), RequestID: c.GetString("request_id")})
}
