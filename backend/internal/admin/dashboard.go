package admin

import (
	"context"
	"database/sql"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/travel-super-app/backend/internal/platform/apiresponse"
)

func count(ctx context.Context, db *sql.DB, query string, args ...any) (int, error) {
	var n int
	err := db.QueryRowContext(ctx, query, args...).Scan(&n)
	return n, err
}

func countsByStatus(ctx context.Context, db *sql.DB, query string) (map[string]int, error) {
	rows, err := db.QueryContext(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[string]int{}
	for rows.Next() {
		var s string
		var n int
		if err := rows.Scan(&s, &n); err != nil {
			return nil, err
		}
		out[s] = n
	}
	return out, rows.Err()
}

// dashboard returns live counts straight from the tables (no cached or demo numbers). Counts only: money figures stay in the
// finance endpoints, which have their own permissions.
func dashboard(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()
		since := time.Now().UTC().AddDate(0, 0, -7)
		fail := func(err error) bool {
			if err != nil {
				apiresponse.Internal(c)
				return true
			}
			return false
		}
		var users struct{ total, active, suspended, new7 int }
		var err error
		if users.total, err = count(ctx, db, "SELECT COUNT(*) FROM users WHERE deleted_at IS NULL"); fail(err) {
			return
		}
		if users.active, err = count(ctx, db, "SELECT COUNT(*) FROM users WHERE deleted_at IS NULL AND status = 'ACTIVE'"); fail(err) {
			return
		}
		if users.suspended, err = count(ctx, db, "SELECT COUNT(*) FROM users WHERE deleted_at IS NULL AND status = 'SUSPENDED'"); fail(err) {
			return
		}
		if users.new7, err = count(ctx, db, "SELECT COUNT(*) FROM users WHERE deleted_at IS NULL AND created_at >= ?", since); fail(err) {
			return
		}
		bookings, err := countsByStatus(ctx, db, "SELECT status, COUNT(*) FROM bookings WHERE deleted_at IS NULL GROUP BY status")
		if fail(err) {
			return
		}
		bookings7, err := count(ctx, db, "SELECT COUNT(*) FROM bookings WHERE deleted_at IS NULL AND created_at >= ?", since)
		if fail(err) {
			return
		}
		payments, err := countsByStatus(ctx, db, "SELECT status, COUNT(*) FROM payments GROUP BY status")
		if fail(err) {
			return
		}
		queues := gin.H{}
		for _, q := range []struct{ key, sql string }{
			{"partners_pending", "SELECT COUNT(*) FROM partners WHERE deleted_at IS NULL AND status = 'PENDING'"},
			{"tickets_open", "SELECT COUNT(*) FROM support_tickets WHERE deleted_at IS NULL AND status IN ('OPEN','IN_PROGRESS')"},
			{"disputes_open", "SELECT COUNT(*) FROM disputes WHERE deleted_at IS NULL AND status IN ('OPEN','IN_REVIEW')"},
			{"refunds_open", "SELECT COUNT(*) FROM refund_requests WHERE status IN ('REQUESTED','UNDER_REVIEW','APPROVED','PROCESSING')"},
			{"role_requests_pending", "SELECT COUNT(*) FROM role_change_requests WHERE status = 'PENDING'"},
			{"community_reports_open", `SELECT COUNT(DISTINCT r.post_id) FROM community_reports r
				JOIN community_posts p ON p.id = r.post_id AND p.deleted_at IS NULL WHERE r.reviewed_at IS NULL`},
		} {
			n, err := count(ctx, db, q.sql)
			if fail(err) {
				return
			}
			queues[q.key] = n
		}
		apiresponse.OK(c, gin.H{
			"generated_at": time.Now().UTC().Format(time.RFC3339),
			"users":        gin.H{"total": users.total, "active": users.active, "suspended": users.suspended, "new_last_7_days": users.new7},
			"bookings":     gin.H{"by_status": bookings, "created_last_7_days": bookings7},
			"payments":     gin.H{"by_status": payments},
			"queues":       queues,
		})
	}
}
