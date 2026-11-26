// Package support is the customer side of support tickets: open a ticket (optionally about one of your bookings), follow the
// conversation, reply and close it. Staff handle the same tickets through /portal/tickets (package portal).
package support

import (
	"context"
	"database/sql"
	"errors"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/travel-super-app/backend/internal/audit"
	"github.com/travel-super-app/backend/internal/auth"
	"github.com/travel-super-app/backend/internal/platform/apiresponse"
	"github.com/travel-super-app/backend/internal/platform/dbtime"
)

const (
	// MaxOpenPerUser stops one account from flooding the queue.
	MaxOpenPerUser = 5
	maxSubject     = 120
	maxBody        = 2000
)

var categories = map[string]bool{"BOOKING": true, "PAYMENT": true, "REFUND": true, "ACCOUNT": true, "OTHER": true}

var (
	errNotFound = errors.New("not found")
	errClosed   = errors.New("closed")
	errLimit    = errors.New("limit")
)

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

func auditLog(c *gin.Context, tx audit.Execer, action, id string, before, after any) error {
	p, _ := auth.CurrentPrincipal(c)
	return audit.Log(c.Request.Context(), tx, audit.Entry{ActorUserID: p.UserID, Action: action, SubjectType: "support_ticket", SubjectID: id, Before: before, After: after, IPAddress: c.ClientIP(), RequestID: c.GetString("request_id")})
}

// cleanText trims and checks a required text field by characters (not bytes), so Thai text is not cut short.
func cleanText(s string, max int) (string, bool) {
	s = strings.TrimSpace(s)
	n := utf8.RuneCountInString(s)
	return s, n >= 1 && n <= max
}

// RegisterRoutes mounts the customer endpoints on a signed-in group:
//
//	POST /tickets            {"subject","category","description","booking_id"?}
//	GET  /tickets            ?status ?limit ?offset (your own, newest first)
//	GET  /tickets/:id        the ticket with its messages (never reveals which staff member wrote a reply)
//	POST /tickets/:id/messages {"body"}
//	POST /tickets/:id/close
//
// Another user's ticket always answers 404, the same as one that does not exist.
func RegisterRoutes(g *gin.RouterGroup, db *sql.DB) {
	g.POST("/tickets", create(db))
	g.GET("/tickets", list(db))
	g.GET("/tickets/:id", detail(db))
	g.POST("/tickets/:id/messages", reply(db))
	g.POST("/tickets/:id/close", closeTicket(db))
}

func create(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		p, ok := auth.CurrentPrincipal(c)
		if !ok {
			apiresponse.Unauthorized(c)
			return
		}
		var in struct {
			Subject     string `json:"subject"`
			Category    string `json:"category"`
			Description string `json:"description"`
			BookingID   string `json:"booking_id"`
		}
		if err := c.ShouldBindJSON(&in); err != nil {
			apiresponse.BadRequest(c, "invalid JSON body")
			return
		}
		subject, okS := cleanText(in.Subject, maxSubject)
		if !okS || utf8.RuneCountInString(subject) < 3 {
			apiresponse.BadRequest(c, "subject must be 3 to 120 characters")
			return
		}
		desc, okD := cleanText(in.Description, maxBody)
		if !okD {
			apiresponse.BadRequest(c, "description must be 1 to 2000 characters")
			return
		}
		category := strings.ToUpper(strings.TrimSpace(in.Category))
		if category == "" {
			category = "OTHER"
		}
		if !categories[category] {
			apiresponse.BadRequest(c, "category must be BOOKING, PAYMENT, REFUND, ACCOUNT or OTHER")
			return
		}
		id := uuid.NewString()
		now := time.Now().UTC()
		err := inTx(c.Request.Context(), db, func(tx *sql.Tx) error {
			var booking any
			if b := strings.TrimSpace(in.BookingID); b != "" {
				var one int
				if err := tx.QueryRowContext(c.Request.Context(), "SELECT 1 FROM bookings WHERE id = ? AND user_id = ? AND deleted_at IS NULL", b, p.UserID).Scan(&one); err != nil {
					if errors.Is(err, sql.ErrNoRows) {
						return errNotFound
					}
					return err
				}
				booking = b
			}
			// Lock the user row so two simultaneous requests cannot both slip under the limit.
			if _, err := tx.ExecContext(c.Request.Context(), "SELECT id FROM users WHERE id = ? FOR UPDATE", p.UserID); err != nil {
				return err
			}
			var open int
			if err := tx.QueryRowContext(c.Request.Context(), "SELECT COUNT(*) FROM support_tickets WHERE user_id = ? AND status IN ('OPEN','IN_PROGRESS') AND deleted_at IS NULL", p.UserID).Scan(&open); err != nil {
				return err
			}
			if open >= MaxOpenPerUser {
				return errLimit
			}
			if _, err := tx.ExecContext(c.Request.Context(), `INSERT INTO support_tickets (id, created_at, updated_at, user_id, booking_id, category, subject, description, status, priority) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'OPEN', 'NORMAL')`,
				id, now, now, p.UserID, booking, category, subject, desc); err != nil {
				return err
			}
			return auditLog(c, tx, "support.ticket.created", id, nil, gin.H{"category": category, "booking_id": booking})
		})
		switch {
		case errors.Is(err, errNotFound):
			apiresponse.NotFound(c, "booking not found")
		case errors.Is(err, errLimit):
			apiresponse.Conflict(c, "you already have the maximum number of open tickets; wait for one to be resolved or close it")
		case err != nil:
			apiresponse.Internal(c)
		default:
			apiresponse.Created(c, gin.H{"id": id, "status": "OPEN", "category": category, "subject": subject})
		}
	}
}

type ticketRow struct {
	ID          string `json:"id"`
	Subject     string `json:"subject"`
	Category    string `json:"category"`
	Status      string `json:"status"`
	BookingCode string `json:"booking_code"`
	CreatedAt   string `json:"created_at"`
	UpdatedAt   string `json:"updated_at"`
	Replies     int    `json:"reply_count"`
}

func list(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		p, ok := auth.CurrentPrincipal(c)
		if !ok {
			apiresponse.Unauthorized(c)
			return
		}
		limit, offset, ok := apiresponse.Page(c)
		if !ok {
			return
		}
		where, args := "t.user_id = ? AND t.deleted_at IS NULL", []any{p.UserID}
		if st := strings.ToUpper(strings.TrimSpace(c.Query("status"))); st != "" {
			if !statusOK(st) {
				apiresponse.BadRequest(c, "status is invalid")
				return
			}
			where += " AND t.status = ?"
			args = append(args, st)
		}
		var total int
		if err := db.QueryRowContext(c.Request.Context(), "SELECT COUNT(*) FROM support_tickets t WHERE "+where, args...).Scan(&total); err != nil {
			apiresponse.Internal(c)
			return
		}
		rows, err := db.QueryContext(c.Request.Context(), `SELECT t.id, COALESCE(t.subject, ''), t.category, t.status, COALESCE(b.booking_code, ''),
			DATE_FORMAT(t.created_at, `+dbtime.SQLDateTime+`), DATE_FORMAT(t.updated_at, `+dbtime.SQLDateTime+`),
			(SELECT COUNT(*) FROM support_ticket_messages m WHERE m.ticket_id = t.id AND m.author_kind = 'STAFF' AND m.deleted_at IS NULL)
			FROM support_tickets t LEFT JOIN bookings b ON b.id = t.booking_id
			WHERE `+where+` ORDER BY t.created_at DESC, t.id DESC LIMIT ? OFFSET ?`, append(append([]any{}, args...), limit, offset)...)
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		defer rows.Close()
		items := []ticketRow{}
		for rows.Next() {
			var r ticketRow
			if err := rows.Scan(&r.ID, &r.Subject, &r.Category, &r.Status, &r.BookingCode, &r.CreatedAt, &r.UpdatedAt, &r.Replies); err != nil {
				apiresponse.Internal(c)
				return
			}
			items = append(items, r)
		}
		if rows.Err() != nil {
			apiresponse.Internal(c)
			return
		}
		apiresponse.OK(c, gin.H{"items": items, "total": total, "limit": limit, "offset": offset})
	}
}

func statusOK(s string) bool {
	switch s {
	case "OPEN", "IN_PROGRESS", "RESOLVED", "CLOSED":
		return true
	}
	return false
}

func detail(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		p, ok := auth.CurrentPrincipal(c)
		if !ok {
			apiresponse.Unauthorized(c)
			return
		}
		var t ticketRow
		var desc string
		err := db.QueryRowContext(c.Request.Context(), `SELECT t.id, COALESCE(t.subject, ''), t.category, t.status, COALESCE(b.booking_code, ''), COALESCE(t.description, ''),
			DATE_FORMAT(t.created_at, `+dbtime.SQLDateTime+`), DATE_FORMAT(t.updated_at, `+dbtime.SQLDateTime+`)
			FROM support_tickets t LEFT JOIN bookings b ON b.id = t.booking_id
			WHERE t.id = ? AND t.user_id = ? AND t.deleted_at IS NULL`, c.Param("id"), p.UserID).Scan(&t.ID, &t.Subject, &t.Category, &t.Status, &t.BookingCode, &desc, &t.CreatedAt, &t.UpdatedAt)
		if errors.Is(err, sql.ErrNoRows) {
			apiresponse.NotFound(c, "ticket not found")
			return
		}
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		rows, err := db.QueryContext(c.Request.Context(), `SELECT id, author_kind, body, DATE_FORMAT(created_at, `+dbtime.SQLDateTime+`)
			FROM support_ticket_messages WHERE ticket_id = ? AND deleted_at IS NULL ORDER BY created_at ASC, id ASC`, t.ID)
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
		apiresponse.OK(c, gin.H{"id": t.ID, "subject": t.Subject, "category": t.Category, "status": t.Status, "booking_code": t.BookingCode,
			"description": desc, "created_at": t.CreatedAt, "updated_at": t.UpdatedAt, "messages": msgs})
	}
}

func reply(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		p, ok := auth.CurrentPrincipal(c)
		if !ok {
			apiresponse.Unauthorized(c)
			return
		}
		var in struct {
			Body string `json:"body"`
		}
		if err := c.ShouldBindJSON(&in); err != nil {
			apiresponse.BadRequest(c, "invalid JSON body")
			return
		}
		body, okB := cleanText(in.Body, maxBody)
		if !okB {
			apiresponse.BadRequest(c, "body must be 1 to 2000 characters")
			return
		}
		id, msgID, now := c.Param("id"), uuid.NewString(), time.Now().UTC()
		err := inTx(c.Request.Context(), db, func(tx *sql.Tx) error {
			var status string
			if err := tx.QueryRowContext(c.Request.Context(), "SELECT status FROM support_tickets WHERE id = ? AND user_id = ? AND deleted_at IS NULL FOR UPDATE", id, p.UserID).Scan(&status); err != nil {
				if errors.Is(err, sql.ErrNoRows) {
					return errNotFound
				}
				return err
			}
			if status == "CLOSED" {
				return errClosed
			}
			if _, err := tx.ExecContext(c.Request.Context(), `INSERT INTO support_ticket_messages (id, created_at, updated_at, ticket_id, author_user_id, author_kind, body) VALUES (?, ?, ?, ?, ?, 'CUSTOMER', ?)`, msgID, now, now, id, p.UserID, body); err != nil {
				return err
			}
			// A reply to a resolved ticket means it is not resolved: put it back in the staff queue (a transition the staff side also allows).
			next := status
			if status == "RESOLVED" {
				next = "IN_PROGRESS"
			}
			if _, err := tx.ExecContext(c.Request.Context(), "UPDATE support_tickets SET status = ?, updated_at = ? WHERE id = ?", next, now, id); err != nil {
				return err
			}
			if next != status {
				return auditLog(c, tx, "support.ticket.reopened", id, gin.H{"status": status}, gin.H{"status": next})
			}
			return nil
		})
		switch {
		case errors.Is(err, errNotFound):
			apiresponse.NotFound(c, "ticket not found")
		case errors.Is(err, errClosed):
			apiresponse.Conflict(c, "this ticket is closed; open a new one")
		case err != nil:
			apiresponse.Internal(c)
		default:
			apiresponse.Created(c, gin.H{"id": msgID})
		}
	}
}

func closeTicket(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		p, ok := auth.CurrentPrincipal(c)
		if !ok {
			apiresponse.Unauthorized(c)
			return
		}
		id := c.Param("id")
		err := inTx(c.Request.Context(), db, func(tx *sql.Tx) error {
			var status string
			if err := tx.QueryRowContext(c.Request.Context(), "SELECT status FROM support_tickets WHERE id = ? AND user_id = ? AND deleted_at IS NULL FOR UPDATE", id, p.UserID).Scan(&status); err != nil {
				if errors.Is(err, sql.ErrNoRows) {
					return errNotFound
				}
				return err
			}
			if status == "CLOSED" {
				return errClosed
			}
			if _, err := tx.ExecContext(c.Request.Context(), "UPDATE support_tickets SET status = 'CLOSED', updated_at = ? WHERE id = ?", time.Now().UTC(), id); err != nil {
				return err
			}
			return auditLog(c, tx, "support.ticket.closed", id, gin.H{"status": status}, gin.H{"status": "CLOSED", "by": "customer"})
		})
		switch {
		case errors.Is(err, errNotFound):
			apiresponse.NotFound(c, "ticket not found")
		case errors.Is(err, errClosed):
			apiresponse.Conflict(c, "this ticket is already closed")
		case err != nil:
			apiresponse.Internal(c)
		default:
			apiresponse.OK(c, gin.H{"id": id, "status": "CLOSED"})
		}
	}
}
