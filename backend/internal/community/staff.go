package community

import (
	"context"
	"database/sql"
	"errors"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/travel-super-app/backend/internal/audit"
	"github.com/travel-super-app/backend/internal/auth"
	"github.com/travel-super-app/backend/internal/platform/apiresponse"
	"github.com/travel-super-app/backend/internal/platform/dbtime"
)

// ReportedPost is one row of the staff moderation queue: a live post with at least one open (unreviewed) report.
type ReportedPost struct {
	ID          string   `json:"id"`
	Body        string   `json:"body"`
	AuthorName  string   `json:"author_name"`
	CreatedAt   string   `json:"created_at"`
	ReportCount int      `json:"report_count"`
	Reasons     []string `json:"reasons"`
}

// ReportedPosts lists live posts with open reports, most reported first.
func (s *Service) ReportedPosts(ctx context.Context, limit, offset int) ([]ReportedPost, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT p.id, p.body, DATE_FORMAT(p.created_at, `+dbtime.SQLDateTime+`),
		COALESCE((SELECT NULLIF(TRIM(CONCAT_WS(' ', up.first_name, up.last_name)), '') FROM user_profiles up WHERE up.user_id = p.user_id AND up.deleted_at IS NULL LIMIT 1), ?),
		COUNT(r.id), GROUP_CONCAT(DISTINCT r.reason ORDER BY r.reason SEPARATOR ',')
		FROM community_posts p JOIN community_reports r ON r.post_id = p.id AND r.reviewed_at IS NULL
		WHERE p.deleted_at IS NULL
		GROUP BY p.id
		ORDER BY COUNT(r.id) DESC, MAX(r.created_at) DESC, p.id DESC LIMIT ? OFFSET ?`, anonymousName, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []ReportedPost{}
	for rows.Next() {
		var p ReportedPost
		var reasons string
		if err := rows.Scan(&p.ID, &p.Body, &p.CreatedAt, &p.AuthorName, &p.ReportCount, &reasons); err != nil {
			return nil, err
		}
		p.Reasons = strings.Split(reasons, ",")
		out = append(out, p)
	}
	return out, rows.Err()
}

// Moderate resolves a post's open reports. action "remove" also soft-deletes the post; "dismiss" keeps it. Both are audited
// in the same transaction. ErrNotFound when the post is gone or has no open report.
func (s *Service) Moderate(ctx context.Context, actorID, postID, action, note, ip, requestID string) error {
	if action != "remove" && action != "dismiss" {
		return validationf("unknown moderation action")
	}
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()
	now := dbtime.Now()
	res, err := tx.ExecContext(ctx, "UPDATE community_reports SET reviewed_at = ?, reviewed_by = ? WHERE post_id = ? AND reviewed_at IS NULL AND EXISTS (SELECT 1 FROM community_posts WHERE id = ? AND deleted_at IS NULL)", now, actorID, postID, postID)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return ErrNotFound
	}
	if action == "remove" {
		if _, err := tx.ExecContext(ctx, "UPDATE community_posts SET deleted_at = ?, updated_at = ? WHERE id = ? AND deleted_at IS NULL", now, now, postID); err != nil {
			return err
		}
	}
	if err := audit.Log(ctx, tx, audit.Entry{ActorUserID: actorID, Action: "community.post." + action, SubjectType: "community_post", SubjectID: postID, Before: map[string]string{"state": "REPORTED"}, After: map[string]string{"action": action, "note": strings.TrimSpace(note)}, IPAddress: ip, RequestID: requestID}); err != nil {
		return err
	}
	return tx.Commit()
}

// RegisterStaffRoutes mounts on the /portal group (already behind portal.read):
//
//	GET  /community/reports            open moderation queue
//	POST /community/posts/:id/remove   {"note": "..."} delete the post and close its reports
//	POST /community/posts/:id/dismiss  {"note": "..."} keep the post and close its reports
//
// Both actions need the support.manage permission and are written to audit_logs.
func RegisterStaffRoutes(g *gin.RouterGroup, s *Service) {
	perm := auth.RequirePermission("support.manage")
	g.GET("/community/reports", perm, func(c *gin.Context) {
		limit, offset, ok := apiresponse.Page(c)
		if !ok {
			return
		}
		items, err := s.ReportedPosts(c.Request.Context(), limit, offset)
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		apiresponse.OK(c, gin.H{"items": items})
	})
	act := func(action string) gin.HandlerFunc {
		return func(c *gin.Context) {
			p, ok := auth.CurrentPrincipal(c)
			if !ok {
				apiresponse.Unauthorized(c)
				return
			}
			var req struct {
				Note string `json:"note"`
			}
			_ = c.ShouldBindJSON(&req) // the note is optional
			if err := s.Moderate(c.Request.Context(), p.UserID, c.Param("id"), action, req.Note, c.ClientIP(), c.GetString("request_id")); err != nil {
				if errors.Is(err, sql.ErrNoRows) {
					err = ErrNotFound
				}
				fail(c, err)
				return
			}
			apiresponse.OK(c, gin.H{"action": action})
		}
	}
	g.POST("/community/posts/:id/remove", perm, act("remove"))
	g.POST("/community/posts/:id/dismiss", perm, act("dismiss"))
}
