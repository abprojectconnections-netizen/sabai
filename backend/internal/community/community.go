// Package community is the public feed: posts are visible to signed-in users immediately, and abuse is reported afterwards.
// There is no pre-moderation. A user never sees posts they reported, and cannot report their own post.
// Reports are stored for staff review; the review tooling is not part of this package.
package community

import (
	"context"
	"database/sql"
	"errors"
	"strings"
	"unicode/utf8"

	"github.com/google/uuid"
	"github.com/travel-super-app/backend/internal/platform/dberr"
	"github.com/travel-super-app/backend/internal/platform/dbtime"
)

var (
	ErrNotFound   = errors.New("post not found")
	ErrValidation = errors.New("validation error")
)

const (
	MaxBodyRunes   = 1000
	MaxDetailRunes = 500
	anonymousName  = "ผู้ใช้ Sabai"
)

var reasons = map[string]bool{"SPAM": true, "ABUSE": true, "MISLEADING": true, "OTHER": true}

func validationf(msg string) error { return errors.Join(ErrValidation, errors.New(msg)) }

type Author struct {
	DisplayName string `json:"display_name"`
}

type Post struct {
	ID        string   `json:"id"`
	Body      string   `json:"body"`
	CreatedAt string   `json:"created_at"`
	Author    Author   `json:"author"`
	Mine      bool     `json:"mine"`
	Tags      []string `json:"tags"`
}

type Service struct{ db *sql.DB }

func NewService(db *sql.DB) *Service { return &Service{db: db} }

// Create publishes a post immediately.
func (s *Service) Create(ctx context.Context, userID, body string) (Post, error) {
	body = strings.TrimSpace(body)
	if body == "" {
		return Post{}, validationf("body is required")
	}
	if utf8.RuneCountInString(body) > MaxBodyRunes {
		return Post{}, validationf("body must be at most 1000 characters")
	}
	id, now := uuid.NewString(), dbtime.Now()
	if _, err := s.db.ExecContext(ctx, "INSERT INTO community_posts (id, created_at, updated_at, user_id, body) VALUES (?, ?, ?, ?, ?)", id, now, now, userID, body); err != nil {
		return Post{}, err
	}
	name, err := s.authorName(ctx, userID)
	if err != nil {
		return Post{}, err
	}
	return Post{ID: id, Body: body, CreatedAt: now.Format("2006-01-02T15:04:05.000000Z"), Author: Author{DisplayName: name}, Mine: true, Tags: []string{}}, nil
}

// authorName never falls back to the e-mail address: only a display name or a neutral label is public.
func (s *Service) authorName(ctx context.Context, userID string) (string, error) {
	var name string
	err := s.db.QueryRowContext(ctx, "SELECT COALESCE(NULLIF(TRIM(CONCAT_WS(' ', first_name, last_name)), ''), ?) FROM user_profiles WHERE user_id = ? AND deleted_at IS NULL", anonymousName, userID).Scan(&name)
	if errors.Is(err, sql.ErrNoRows) {
		return anonymousName, nil
	}
	return name, err
}

// Feed lists live posts newest first, without posts the viewer reported.
func (s *Service) Feed(ctx context.Context, viewerID string, limit, offset int) ([]Post, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT p.id, p.body, DATE_FORMAT(p.created_at, `+dbtime.SQLDateTime+`),
		COALESCE(NULLIF(TRIM(CONCAT_WS(' ', up.first_name, up.last_name)), ''), ?), p.user_id = ?
		FROM community_posts p LEFT JOIN user_profiles up ON up.user_id = p.user_id AND up.deleted_at IS NULL
		WHERE p.deleted_at IS NULL
		  AND NOT EXISTS (SELECT 1 FROM community_reports r WHERE r.post_id = p.id AND r.reporter_id = ?)
		ORDER BY p.created_at DESC, p.id DESC LIMIT ? OFFSET ?`, anonymousName, viewerID, viewerID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	posts := []Post{}
	index := map[string]int{}
	var ids []any
	for rows.Next() {
		var p Post
		if err := rows.Scan(&p.ID, &p.Body, &p.CreatedAt, &p.Author.DisplayName, &p.Mine); err != nil {
			return nil, err
		}
		p.Tags = []string{}
		index[p.ID] = len(posts)
		ids = append(ids, p.ID)
		posts = append(posts, p)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if len(ids) == 0 {
		return posts, nil
	}
	// One query for all tags of the page (no per-post queries).
	tagRows, err := s.db.QueryContext(ctx, "SELECT ct.content_id, t.label FROM content_tags ct JOIN tags t ON t.id = ct.tag_id WHERE ct.content_type = 'COMMUNITY_POST' AND ct.content_id IN (?"+strings.Repeat(",?", len(ids)-1)+") ORDER BY t.slug", ids...)
	if err != nil {
		return nil, err
	}
	defer tagRows.Close()
	for tagRows.Next() {
		var id, label string
		if err := tagRows.Scan(&id, &label); err != nil {
			return nil, err
		}
		if i, ok := index[id]; ok {
			posts[i].Tags = append(posts[i].Tags, label)
		}
	}
	return posts, tagRows.Err()
}

// Delete soft-deletes the viewer's own post. Someone else's post is "not found".
func (s *Service) Delete(ctx context.Context, userID, id string) error {
	res, err := s.db.ExecContext(ctx, "UPDATE community_posts SET deleted_at = ?, updated_at = ? WHERE id = ? AND user_id = ? AND deleted_at IS NULL", dbtime.Now(), dbtime.Now(), id, userID)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return ErrNotFound
	}
	return nil
}

// Report records an abuse report (idempotent per user and post) and hides the post from the reporter.
func (s *Service) Report(ctx context.Context, userID, postID, reason, detail string) error {
	reason = strings.ToUpper(strings.TrimSpace(reason))
	detail = strings.TrimSpace(detail)
	if !reasons[reason] {
		return validationf("reason must be one of SPAM, ABUSE, MISLEADING, OTHER")
	}
	if utf8.RuneCountInString(detail) > MaxDetailRunes {
		return validationf("detail must be at most 500 characters")
	}
	var author string
	if err := s.db.QueryRowContext(ctx, "SELECT user_id FROM community_posts WHERE id = ? AND deleted_at IS NULL", postID).Scan(&author); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return ErrNotFound
		}
		return err
	}
	if author == userID {
		return validationf("you cannot report your own post")
	}
	var detailArg any
	if detail != "" {
		detailArg = detail
	}
	_, err := s.db.ExecContext(ctx, "INSERT INTO community_reports (id, created_at, post_id, reporter_id, reason, detail) VALUES (?, ?, ?, ?, ?, ?)", uuid.NewString(), dbtime.Now(), postID, userID, reason, detailArg)
	if err != nil && !dberr.IsDuplicate(err) {
		return err
	}
	return nil
}
