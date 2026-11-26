package portal

import (
	"database/sql"
	"errors"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/travel-super-app/backend/internal/auth"
	"github.com/travel-super-app/backend/internal/platform/apiresponse"
	"github.com/travel-super-app/backend/internal/platform/dbtime"
)

// registerTickets adds the staff side of customer support tickets (customers open and follow them through /support/tickets).
// All three routes need support.manage, the permission that already guards ticket assignment and status changes.
func registerTickets(group *gin.RouterGroup, db *sql.DB) {
	group.GET("/tickets", auth.RequirePermission("support.manage"), listTickets(db))
	group.GET("/tickets/:id", auth.RequirePermission("support.manage"), getTicket(db))
	group.POST("/tickets/:id/messages", auth.RequirePermission("support.manage"), replyToTicket(db))
}

type ticketRow struct {
	ID            string   `json:"id"`
	Subject       string   `json:"subject"`
	Category      string   `json:"category"`
	Priority      string   `json:"priority"`
	Status        string   `json:"status"`
	CustomerEmail string   `json:"customer_email"`
	BookingCode   string   `json:"booking_code"`
	AssignedTo    string   `json:"assigned_staff_id"`
	CreatedAt     string   `json:"created_at"`
	Messages      int      `json:"message_count"`
	NextStatuses  []string `json:"next_statuses"`
}

// listTickets supports ?status, ?limit and ?offset. Tickets that still need work come first, oldest first, so the longest
// waiting customer is on top; closed tickets follow.
func listTickets(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		limit, offset, ok := apiresponse.Page(c)
		if !ok {
			return
		}
		where := []string{"t.deleted_at IS NULL"}
		args := []any{}
		if !statusFilter(c, "t.status", &where, &args) {
			return
		}
		cond := strings.Join(where, " AND ")
		var total int
		if err := db.QueryRowContext(c.Request.Context(), "SELECT COUNT(*) FROM support_tickets t WHERE "+cond, args...).Scan(&total); err != nil {
			apiresponse.Internal(c)
			return
		}
		rows, err := db.QueryContext(c.Request.Context(), `SELECT t.id, COALESCE(t.subject, ''), t.category, t.priority, t.status, COALESCE(u.email, ''), COALESCE(b.booking_code, ''),
			COALESCE(t.assigned_staff_id, ''), DATE_FORMAT(t.created_at, `+dbtime.SQLDateTime+`),
			(SELECT COUNT(*) FROM support_ticket_messages m WHERE m.ticket_id = t.id AND m.deleted_at IS NULL)
			FROM support_tickets t LEFT JOIN users u ON u.id = t.user_id LEFT JOIN bookings b ON b.id = t.booking_id
			WHERE `+cond+` ORDER BY (t.status = 'CLOSED') ASC, t.created_at ASC, t.id ASC LIMIT ? OFFSET ?`, append(append([]any{}, args...), limit, offset)...)
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		defer rows.Close()
		items := []ticketRow{}
		for rows.Next() {
			var r ticketRow
			if err := rows.Scan(&r.ID, &r.Subject, &r.Category, &r.Priority, &r.Status, &r.CustomerEmail, &r.BookingCode, &r.AssignedTo, &r.CreatedAt, &r.Messages); err != nil {
				apiresponse.Internal(c)
				return
			}
			r.NextStatuses = nextStatuses(ticketTransitions, r.Status)
			items = append(items, r)
		}
		if rows.Err() != nil {
			apiresponse.Internal(c)
			return
		}
		apiresponse.OK(c, gin.H{"items": items, "total": total, "limit": limit, "offset": offset})
	}
}

func getTicket(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var r ticketRow
		var desc string
		err := db.QueryRowContext(c.Request.Context(), `SELECT t.id, COALESCE(t.subject, ''), t.category, t.priority, t.status, COALESCE(u.email, ''), COALESCE(b.booking_code, ''),
			COALESCE(t.assigned_staff_id, ''), DATE_FORMAT(t.created_at, `+dbtime.SQLDateTime+`), COALESCE(t.description, '')
			FROM support_tickets t LEFT JOIN users u ON u.id = t.user_id LEFT JOIN bookings b ON b.id = t.booking_id
			WHERE t.id = ? AND t.deleted_at IS NULL`, c.Param("id")).Scan(&r.ID, &r.Subject, &r.Category, &r.Priority, &r.Status, &r.CustomerEmail, &r.BookingCode, &r.AssignedTo, &r.CreatedAt, &desc)
		if errors.Is(err, sql.ErrNoRows) {
			apiresponse.NotFound(c, "ticket not found")
			return
		}
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		rows, err := db.QueryContext(c.Request.Context(), `SELECT id, author_kind, body, DATE_FORMAT(created_at, `+dbtime.SQLDateTime+`)
			FROM support_ticket_messages WHERE ticket_id = ? AND deleted_at IS NULL ORDER BY created_at ASC, id ASC`, r.ID)
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		defer rows.Close()
		msgs := []gin.H{}
		for rows.Next() {
			var id, kind, body, at string
			if err := rows.Scan(&id, &kind, &body, &at); err != nil {
				apiresponse.Internal(c)
				return
			}
			msgs = append(msgs, gin.H{"id": id, "author_kind": kind, "body": body, "created_at": at})
		}
		if rows.Err() != nil {
			apiresponse.Internal(c)
			return
		}
		apiresponse.OK(c, gin.H{"id": r.ID, "subject": r.Subject, "category": r.Category, "priority": r.Priority, "status": r.Status,
			"customer_email": r.CustomerEmail, "booking_code": r.BookingCode, "assigned_staff_id": r.AssignedTo, "description": desc,
			"created_at": r.CreatedAt, "messages": msgs, "next_statuses": nextStatuses(ticketTransitions, r.Status)})
	}
}

// replyToTicket adds a staff message. The first reply to an OPEN ticket moves it to IN_PROGRESS (a transition the status endpoint
// allows too) and assigns it to the replier when nobody owns it yet. A closed ticket cannot be answered.
func replyToTicket(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var in struct {
			Body string `json:"body"`
		}
		if err := c.ShouldBindJSON(&in); err != nil {
			apiresponse.BadRequest(c, "invalid JSON body")
			return
		}
		body := strings.TrimSpace(in.Body)
		if n := utf8.RuneCountInString(body); n < 1 || n > 2000 {
			apiresponse.BadRequest(c, "body must be 1 to 2000 characters")
			return
		}
		p, _ := auth.CurrentPrincipal(c)
		id, msgID, now := c.Param("id"), uuid.NewString(), time.Now().UTC()
		var newStatus string
		err := inTx(c.Request.Context(), db, func(tx *sql.Tx) error {
			var status string
			var owner sql.NullString
			if err := tx.QueryRowContext(c.Request.Context(), "SELECT status, assigned_staff_id FROM support_tickets WHERE id = ? AND deleted_at IS NULL FOR UPDATE", id).Scan(&status, &owner); errors.Is(err, sql.ErrNoRows) {
				return errNotFound
			} else if err != nil {
				return err
			}
			if status == "CLOSED" {
				return errConflict
			}
			if _, err := tx.ExecContext(c.Request.Context(), `INSERT INTO support_ticket_messages (id, created_at, updated_at, ticket_id, author_user_id, author_kind, body) VALUES (?, ?, ?, ?, ?, 'STAFF', ?)`, msgID, now, now, id, p.UserID, body); err != nil {
				return err
			}
			newStatus = status
			if status == "OPEN" {
				newStatus = "IN_PROGRESS"
			}
			assigned := owner.String
			if !owner.Valid || owner.String == "" {
				assigned = p.UserID
			}
			if _, err := tx.ExecContext(c.Request.Context(), "UPDATE support_tickets SET status = ?, assigned_staff_id = ?, updated_at = ? WHERE id = ?", newStatus, assigned, now, id); err != nil {
				return err
			}
			return auditChange(c, tx, "support.ticket.replied", "support_ticket", id, gin.H{"status": status, "assigned_staff_id": owner.String}, gin.H{"status": newStatus, "assigned_staff_id": assigned, "message_id": msgID})
		})
		switch {
		case errors.Is(err, errNotFound):
			apiresponse.NotFound(c, "ticket not found")
		case errors.Is(err, errConflict):
			apiresponse.Conflict(c, "this ticket is closed")
		case err != nil:
			apiresponse.Internal(c)
		default:
			apiresponse.Created(c, gin.H{"id": msgID, "status": newStatus})
		}
	}
}
