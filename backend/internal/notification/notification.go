// Package notification stores in-app notifications and exposes them to their owner.
package notification

import (
	"context"
	"database/sql"
	"errors"
	"strings"
	"unicode/utf8"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/travel-super-app/backend/internal/auth"
	"github.com/travel-super-app/backend/internal/platform/apiresponse"
	"github.com/travel-super-app/backend/internal/platform/dbtime"
)

var ErrNotFound = errors.New("notification not found")

type Notification struct {
	ID        string `json:"id"`
	Type      string `json:"type"`
	Title     string `json:"title"`
	Body      string `json:"body"`
	Read      bool   `json:"read"`
	CreatedAt string `json:"created_at"`
}

type Service struct{ db *sql.DB }

func NewService(db *sql.DB) *Service { return &Service{db: db} }

// Create stores a notification for a user. Other domains call this when something noteworthy happens.
func (s *Service) Create(ctx context.Context, userID, kind, title, body string) (string, error) {
	title = strings.TrimSpace(title)
	kind = strings.TrimSpace(kind)
	if userID == "" || kind == "" || title == "" || utf8.RuneCountInString(title) > 200 || utf8.RuneCountInString(kind) > 50 {
		return "", errors.New("notification requires user, type (<=50) and title (<=200)")
	}
	id, now := uuid.NewString(), dbtime.Now()
	_, err := s.db.ExecContext(ctx, "INSERT INTO notifications (id, created_at, updated_at, user_id, type, title, body) VALUES (?, ?, ?, ?, ?, ?, ?)", id, now, now, userID, kind, title, body)
	return id, err
}

func (s *Service) List(ctx context.Context, userID string, unreadOnly bool, limit, offset int) ([]Notification, int, error) {
	q := "SELECT id, type, title, COALESCE(body, ''), read_at IS NOT NULL, DATE_FORMAT(created_at, " + dbtime.SQLDateTime + ") FROM notifications WHERE user_id = ? AND deleted_at IS NULL"
	if unreadOnly {
		q += " AND read_at IS NULL"
	}
	rows, err := s.db.QueryContext(ctx, q+" ORDER BY created_at DESC, id LIMIT ? OFFSET ?", userID, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()
	items := []Notification{}
	for rows.Next() {
		var n Notification
		if err := rows.Scan(&n.ID, &n.Type, &n.Title, &n.Body, &n.Read, &n.CreatedAt); err != nil {
			return nil, 0, err
		}
		items = append(items, n)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, err
	}
	var unread int
	if err := s.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM notifications WHERE user_id = ? AND deleted_at IS NULL AND read_at IS NULL", userID).Scan(&unread); err != nil {
		return nil, 0, err
	}
	return items, unread, nil
}

// MarkRead is idempotent: reading an already-read notification succeeds.
func (s *Service) MarkRead(ctx context.Context, userID, id string) error {
	now := dbtime.Now()
	if _, err := s.db.ExecContext(ctx, "UPDATE notifications SET read_at = COALESCE(read_at, ?), updated_at = ? WHERE id = ? AND user_id = ? AND deleted_at IS NULL", now, now, id, userID); err != nil {
		return err
	}
	var one int
	err := s.db.QueryRowContext(ctx, "SELECT 1 FROM notifications WHERE id = ? AND user_id = ? AND deleted_at IS NULL", id, userID).Scan(&one)
	if errors.Is(err, sql.ErrNoRows) {
		return ErrNotFound
	}
	return err
}

func (s *Service) MarkAllRead(ctx context.Context, userID string) (int64, error) {
	now := dbtime.Now()
	res, err := s.db.ExecContext(ctx, "UPDATE notifications SET read_at = ?, updated_at = ? WHERE user_id = ? AND deleted_at IS NULL AND read_at IS NULL", now, now, userID)
	if err != nil {
		return 0, err
	}
	return res.RowsAffected()
}

func RegisterRoutes(group *gin.RouterGroup, s *Service) {
	group.GET("", func(c *gin.Context) {
		p, ok := auth.CurrentPrincipal(c)
		if !ok {
			apiresponse.Unauthorized(c)
			return
		}
		limit, offset, ok := apiresponse.Page(c)
		if !ok {
			return
		}
		items, unread, err := s.List(c.Request.Context(), p.UserID, c.Query("unread") == "true", limit, offset)
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		apiresponse.OK(c, gin.H{"items": items, "unread_count": unread})
	})
	group.POST("/read-all", func(c *gin.Context) {
		p, ok := auth.CurrentPrincipal(c)
		if !ok {
			apiresponse.Unauthorized(c)
			return
		}
		n, err := s.MarkAllRead(c.Request.Context(), p.UserID)
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		apiresponse.OK(c, gin.H{"updated": n})
	})
	group.PATCH("/:id/read", func(c *gin.Context) {
		p, ok := auth.CurrentPrincipal(c)
		if !ok {
			apiresponse.Unauthorized(c)
			return
		}
		switch err := s.MarkRead(c.Request.Context(), p.UserID, c.Param("id")); {
		case errors.Is(err, ErrNotFound):
			apiresponse.NotFound(c, "notification not found")
		case err != nil:
			apiresponse.Internal(c)
		default:
			apiresponse.OK(c, gin.H{"id": c.Param("id"), "read": true})
		}
	})
}
