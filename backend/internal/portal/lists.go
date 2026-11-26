package portal

import (
	"database/sql"
	"regexp"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/travel-super-app/backend/internal/auth"
	"github.com/travel-super-app/backend/internal/platform/apiresponse"
	"github.com/travel-super-app/backend/internal/platform/dbtime"
)

// registerLists adds the read-only work queues behind the status-change endpoints. Each list needs the same permission as the
// action it feeds, and every row carries next_statuses computed from the server's own transition rules, so a client never has
// to copy (and can never disagree with) those rules.
func registerLists(group *gin.RouterGroup, db *sql.DB) {
	group.GET("/bookings", auth.RequirePermission("booking.manage"), listBookings(db))
	group.GET("/disputes", auth.RequirePermission("support.manage"), listDisputes(db))
	group.GET("/partners", auth.RequirePermission("partner.review"), listPartners(db))
	registerTickets(group, db)
}

var statusFormat = regexp.MustCompile(`^[A-Z_]{1,30}$`)

func nextStatuses(t transitions, from string) []string {
	return append([]string{}, t[from]...)
}

func likeEscape(s string) string {
	return strings.NewReplacer(`\`, `\\`, `%`, `\%`, `_`, `\_`).Replace(s)
}

// statusFilter validates ?status (any well-formed status, because booking statuses also include financial ones such as PAID).
func statusFilter(c *gin.Context, column string, where *[]string, args *[]any) bool {
	st := strings.ToUpper(strings.TrimSpace(c.Query("status")))
	if st == "" {
		return true
	}
	if !statusFormat.MatchString(st) {
		apiresponse.BadRequest(c, "status is invalid")
		return false
	}
	*where = append(*where, column+" = ?")
	*args = append(*args, st)
	return true
}

type bookingRow struct {
	ID           string   `json:"id"`
	Code         string   `json:"booking_code"`
	Status       string   `json:"status"`
	Currency     string   `json:"currency"`
	Total        string   `json:"total_amount"`
	CustomerMail string   `json:"customer_email"`
	CreatedAt    string   `json:"created_at"`
	NextStatuses []string `json:"next_statuses"`
}

// listBookings supports ?status, ?q (booking code contains), ?limit and ?offset, newest first.
func listBookings(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		limit, offset, ok := apiresponse.Page(c)
		if !ok {
			return
		}
		where := []string{"b.deleted_at IS NULL"}
		args := []any{}
		if !statusFilter(c, "b.status", &where, &args) {
			return
		}
		if q := strings.TrimSpace(c.Query("q")); q != "" {
			if len(q) > 40 {
				apiresponse.BadRequest(c, "q is too long")
				return
			}
			where = append(where, `b.booking_code LIKE ? ESCAPE '\\'`)
			args = append(args, "%"+likeEscape(q)+"%")
		}
		cond := strings.Join(where, " AND ")
		var total int
		if err := db.QueryRowContext(c.Request.Context(), "SELECT COUNT(*) FROM bookings b WHERE "+cond, args...).Scan(&total); err != nil {
			apiresponse.Internal(c)
			return
		}
		rows, err := db.QueryContext(c.Request.Context(), `SELECT b.id, b.booking_code, b.status, b.currency_code, CAST(b.total_amount AS CHAR),
			COALESCE(u.email, ''), DATE_FORMAT(b.created_at, `+dbtime.SQLDateTime+`)
			FROM bookings b LEFT JOIN users u ON u.id = b.user_id
			WHERE `+cond+` ORDER BY b.created_at DESC, b.id DESC LIMIT ? OFFSET ?`, append(append([]any{}, args...), limit, offset)...)
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		defer rows.Close()
		items := []bookingRow{}
		for rows.Next() {
			var r bookingRow
			if err := rows.Scan(&r.ID, &r.Code, &r.Status, &r.Currency, &r.Total, &r.CustomerMail, &r.CreatedAt); err != nil {
				apiresponse.Internal(c)
				return
			}
			r.NextStatuses = nextStatuses(bookingTransitions, r.Status)
			items = append(items, r)
		}
		if rows.Err() != nil {
			apiresponse.Internal(c)
			return
		}
		apiresponse.OK(c, gin.H{"items": items, "total": total, "limit": limit, "offset": offset})
	}
}

type disputeRow struct {
	ID           string   `json:"id"`
	BookingID    string   `json:"booking_id"`
	BookingCode  string   `json:"booking_code"`
	Reason       string   `json:"reason"`
	Description  string   `json:"description"`
	Status       string   `json:"status"`
	OpenedBy     string   `json:"opened_by_email"`
	AssignedTo   string   `json:"assigned_staff_id"`
	Resolution   string   `json:"resolution"`
	CreatedAt    string   `json:"created_at"`
	NextStatuses []string `json:"next_statuses"`
}

// listDisputes supports ?status, ?limit and ?offset, newest first.
func listDisputes(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		limit, offset, ok := apiresponse.Page(c)
		if !ok {
			return
		}
		where := []string{"d.deleted_at IS NULL"}
		args := []any{}
		if !statusFilter(c, "d.status", &where, &args) {
			return
		}
		cond := strings.Join(where, " AND ")
		var total int
		if err := db.QueryRowContext(c.Request.Context(), "SELECT COUNT(*) FROM disputes d WHERE "+cond, args...).Scan(&total); err != nil {
			apiresponse.Internal(c)
			return
		}
		rows, err := db.QueryContext(c.Request.Context(), `SELECT d.id, d.booking_id, COALESCE(b.booking_code, ''), d.reason, COALESCE(d.description, ''),
			d.status, COALESCE(u.email, ''), COALESCE(d.assigned_staff_id, ''), COALESCE(d.resolution, ''), DATE_FORMAT(d.created_at, `+dbtime.SQLDateTime+`)
			FROM disputes d LEFT JOIN bookings b ON b.id = d.booking_id LEFT JOIN users u ON u.id = d.opened_by_user_id
			WHERE `+cond+` ORDER BY d.created_at DESC, d.id DESC LIMIT ? OFFSET ?`, append(append([]any{}, args...), limit, offset)...)
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		defer rows.Close()
		items := []disputeRow{}
		for rows.Next() {
			var r disputeRow
			if err := rows.Scan(&r.ID, &r.BookingID, &r.BookingCode, &r.Reason, &r.Description, &r.Status, &r.OpenedBy, &r.AssignedTo, &r.Resolution, &r.CreatedAt); err != nil {
				apiresponse.Internal(c)
				return
			}
			r.NextStatuses = nextStatuses(disputeTransitions, r.Status)
			items = append(items, r)
		}
		if rows.Err() != nil {
			apiresponse.Internal(c)
			return
		}
		apiresponse.OK(c, gin.H{"items": items, "total": total, "limit": limit, "offset": offset})
	}
}

type partnerRow struct {
	ID           string   `json:"id"`
	LegalName    string   `json:"legal_name"`
	Status       string   `json:"status"`
	OwnerEmail   string   `json:"owner_email"`
	CreatedAt    string   `json:"created_at"`
	NextStatuses []string `json:"next_statuses"`
}

// listPartners supports ?status, ?limit and ?offset, oldest first so the longest-waiting application is on top.
func listPartners(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		limit, offset, ok := apiresponse.Page(c)
		if !ok {
			return
		}
		where := []string{"p.deleted_at IS NULL"}
		args := []any{}
		if !statusFilter(c, "p.status", &where, &args) {
			return
		}
		cond := strings.Join(where, " AND ")
		var total int
		if err := db.QueryRowContext(c.Request.Context(), "SELECT COUNT(*) FROM partners p WHERE "+cond, args...).Scan(&total); err != nil {
			apiresponse.Internal(c)
			return
		}
		rows, err := db.QueryContext(c.Request.Context(), `SELECT p.id, p.legal_name, p.status, COALESCE(u.email, ''), DATE_FORMAT(p.created_at, `+dbtime.SQLDateTime+`)
			FROM partners p LEFT JOIN users u ON u.id = p.owner_user_id
			WHERE `+cond+` ORDER BY p.created_at ASC, p.id ASC LIMIT ? OFFSET ?`, append(append([]any{}, args...), limit, offset)...)
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		defer rows.Close()
		items := []partnerRow{}
		for rows.Next() {
			var r partnerRow
			if err := rows.Scan(&r.ID, &r.LegalName, &r.Status, &r.OwnerEmail, &r.CreatedAt); err != nil {
				apiresponse.Internal(c)
				return
			}
			r.NextStatuses = nextStatuses(partnerTransitions, r.Status)
			items = append(items, r)
		}
		if rows.Err() != nil {
			apiresponse.Internal(c)
			return
		}
		apiresponse.OK(c, gin.H{"items": items, "total": total, "limit": limit, "offset": offset})
	}
}
