// Package tag is the central tagging system for user content (trips, reviews, community posts; more types as their tables arrive).
//
// Rules:
//   - a tag is a normalised slug (lowercase, letters/digits/marks and '-') with the user's original label;
//   - only the owner of a piece of content may change its tags;
//   - tags on private content (trips) are visible only to the owner, and never counted in public tag statistics.
package tag

import (
	"context"
	"database/sql"
	"errors"
	"strings"
	"unicode"
	"unicode/utf8"

	"github.com/google/uuid"
	"github.com/travel-super-app/backend/internal/platform/dbtime"
)

var (
	ErrNotFound   = errors.New("content not found")
	ErrValidation = errors.New("validation error")
)

const (
	MaxTagsPerContent = 10
	MaxTagRunes       = 30
)

// Content types that may carry tags. Private ones are visible only to their owner.
const (
	TypeTrip          = "TRIP"
	TypeReview        = "REVIEW"
	TypeCommunityPost = "COMMUNITY_POST"
)

var contentTypes = map[string]bool{TypeTrip: true, TypeReview: true, TypeCommunityPost: true}

func validationf(msg string) error { return errors.Join(ErrValidation, errors.New(msg)) }

// Tag is what the API returns.
type Tag struct {
	Slug  string `json:"slug"`
	Label string `json:"label"`
	Uses  int    `json:"uses,omitempty"`
}

// Normalize turns user input into (slug, label). Letters of any script (Thai included), digits, combining marks and '-' are
// kept; whitespace becomes '-'; anything else is rejected rather than silently dropped.
func Normalize(raw string) (slug, label string, err error) {
	label = strings.Join(strings.Fields(raw), " ")
	if label == "" {
		return "", "", validationf("tag must not be empty")
	}
	if utf8.RuneCountInString(label) > MaxTagRunes {
		return "", "", validationf("tag must be at most 30 characters")
	}
	var b strings.Builder
	for _, r := range strings.ToLower(label) {
		switch {
		case unicode.IsLetter(r), unicode.IsDigit(r), unicode.IsMark(r), r == '-':
			b.WriteRune(r)
		case r == ' ':
			b.WriteRune('-')
		default:
			return "", "", validationf("tag may contain only letters, digits, spaces and '-'")
		}
	}
	slug = strings.Trim(b.String(), "-")
	if slug == "" {
		return "", "", validationf("tag must contain a letter or digit")
	}
	return slug, label, nil
}

type Service struct{ db *sql.DB }

func NewService(db *sql.DB) *Service { return &Service{db: db} }

func checkType(t string) (string, error) {
	t = strings.ToUpper(strings.TrimSpace(t))
	if !contentTypes[t] {
		return "", validationf("content type must be one of TRIP, REVIEW, COMMUNITY_POST")
	}
	return t, nil
}

type querier interface {
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
}

// access reports whether the viewer may see the content (and, with forUpdate, locks its row so concurrent edits serialise).
func access(ctx context.Context, q querier, userID, ctype, id string, write, forUpdate bool) error {
	var query string
	args := []any{id}
	switch ctype {
	case TypeTrip: // private: owner only, for reads and writes
		query = "SELECT 1 FROM trips WHERE id = ? AND user_id = ? AND deleted_at IS NULL"
		args = append(args, userID)
	case TypeCommunityPost: // readable by any signed-in user; only the author may change tags
		query = "SELECT 1 FROM community_posts WHERE id = ? AND deleted_at IS NULL"
		if write {
			query += " AND user_id = ?"
			args = append(args, userID)
		}
	case TypeReview: // readable by any signed-in user; only the author may change tags
		query = "SELECT 1 FROM reviews WHERE id = ? AND deleted_at IS NULL"
		if write {
			query += " AND user_id = ?"
			args = append(args, userID)
		}
	}
	if forUpdate {
		query += " FOR UPDATE"
	}
	var one int
	if err := q.QueryRowContext(ctx, query, args...).Scan(&one); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return ErrNotFound
		}
		return err
	}
	return nil
}

// Set replaces the tag set of one piece of content (idempotent). An empty list removes all tags.
func (s *Service) Set(ctx context.Context, userID, ctype, contentID string, labels []string) ([]Tag, error) {
	ctype, err := checkType(ctype)
	if err != nil {
		return nil, err
	}
	if len(labels) > MaxTagsPerContent {
		return nil, validationf("at most 10 tags per item")
	}
	type item struct{ slug, label string }
	var wanted []item
	seen := map[string]bool{}
	for _, raw := range labels {
		slug, label, err := Normalize(raw)
		if err != nil {
			return nil, err
		}
		if !seen[slug] {
			seen[slug] = true
			wanted = append(wanted, item{slug, label})
		}
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer func() { _ = tx.Rollback() }()
	if err := access(ctx, tx, userID, ctype, contentID, true, true); err != nil {
		return nil, err
	}

	now := dbtime.Now()
	ids := make([]string, 0, len(wanted))
	for _, w := range wanted {
		// INSERT IGNORE keeps the first label spelling; concurrent creators of the same slug cannot collide.
		if _, err := tx.ExecContext(ctx, "INSERT IGNORE INTO tags (id, created_at, updated_at, slug, label, created_by) VALUES (?, ?, ?, ?, ?, ?)", uuid.NewString(), now, now, w.slug, w.label, userID); err != nil {
			return nil, err
		}
		var id string
		if err := tx.QueryRowContext(ctx, "SELECT id FROM tags WHERE slug = ?", w.slug).Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}

	if _, err := tx.ExecContext(ctx, "DELETE FROM content_tags WHERE content_type = ? AND content_id = ?", ctype, contentID); err != nil {
		return nil, err
	}
	for _, id := range ids {
		if _, err := tx.ExecContext(ctx, "INSERT INTO content_tags (id, created_at, tag_id, content_type, content_id, tagged_by) VALUES (?, ?, ?, ?, ?, ?)", uuid.NewString(), now, id, ctype, contentID, userID); err != nil {
			return nil, err
		}
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return s.TagsOf(ctx, userID, ctype, contentID)
}

// TagsOf lists the tags of one piece of content the viewer may see.
func (s *Service) TagsOf(ctx context.Context, userID, ctype, contentID string) ([]Tag, error) {
	ctype, err := checkType(ctype)
	if err != nil {
		return nil, err
	}
	if err := access(ctx, s.db, userID, ctype, contentID, false, false); err != nil {
		return nil, err
	}
	rows, err := s.db.QueryContext(ctx, "SELECT t.slug, t.label FROM content_tags ct JOIN tags t ON t.id = ct.tag_id WHERE ct.content_type = ? AND ct.content_id = ? ORDER BY t.slug", ctype, contentID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Tag{}
	for rows.Next() {
		var t Tag
		if err := rows.Scan(&t.Slug, &t.Label); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

func escapeLike(s string) string {
	return strings.NewReplacer(`\`, `\\`, `%`, `\%`, `_`, `\_`).Replace(s)
}

// Popular lists tags by public usage (REVIEW and COMMUNITY_POST content only): private trips never feed public statistics.
// prefix filters by slug prefix (autocomplete).
func (s *Service) Popular(ctx context.Context, prefix string, limit, offset int) ([]Tag, error) {
	prefix = strings.ToLower(strings.TrimSpace(prefix))
	rows, err := s.db.QueryContext(ctx, `SELECT t.slug, t.label, COUNT(*) AS uses
		FROM tags t JOIN content_tags ct ON ct.tag_id = t.id
		WHERE t.slug LIKE ? ESCAPE '\\'
		  AND ((ct.content_type = 'REVIEW' AND EXISTS (SELECT 1 FROM reviews r WHERE r.id = ct.content_id AND r.deleted_at IS NULL))
		    OR (ct.content_type = 'COMMUNITY_POST' AND EXISTS (SELECT 1 FROM community_posts cp WHERE cp.id = ct.content_id AND cp.deleted_at IS NULL)))
		GROUP BY t.id, t.slug, t.label ORDER BY uses DESC, t.slug LIMIT ? OFFSET ?`, escapeLike(prefix)+"%", limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Tag{}
	for rows.Next() {
		var t Tag
		if err := rows.Scan(&t.Slug, &t.Label, &t.Uses); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// ContentByTag returns ids of content of one type carrying the tag, limited to what the viewer may see
// (own trips; any non-deleted review; community posts the viewer has not reported).
func (s *Service) ContentByTag(ctx context.Context, userID, slug, ctype string, limit, offset int) ([]string, error) {
	ctype, err := checkType(ctype)
	if err != nil {
		return nil, err
	}
	slug, _, err = Normalize(slug)
	if err != nil {
		return nil, err
	}
	var q string
	args := []any{slug}
	switch ctype {
	case TypeTrip:
		q = "SELECT ct.content_id FROM content_tags ct JOIN tags t ON t.id = ct.tag_id JOIN trips x ON x.id = ct.content_id AND x.user_id = ? AND x.deleted_at IS NULL WHERE t.slug = ? AND ct.content_type = 'TRIP' ORDER BY ct.created_at DESC, ct.id LIMIT ? OFFSET ?"
		args = []any{userID, slug}
	case TypeCommunityPost:
		q = "SELECT ct.content_id FROM content_tags ct JOIN tags t ON t.id = ct.tag_id JOIN community_posts x ON x.id = ct.content_id AND x.deleted_at IS NULL WHERE t.slug = ? AND ct.content_type = 'COMMUNITY_POST' AND NOT EXISTS (SELECT 1 FROM community_reports r WHERE r.post_id = x.id AND r.reporter_id = ?) ORDER BY ct.created_at DESC, ct.id LIMIT ? OFFSET ?"
		args = []any{slug, userID}
	default:
		q = "SELECT ct.content_id FROM content_tags ct JOIN tags t ON t.id = ct.tag_id JOIN reviews x ON x.id = ct.content_id AND x.deleted_at IS NULL WHERE t.slug = ? AND ct.content_type = 'REVIEW' ORDER BY ct.created_at DESC, ct.id LIMIT ? OFFSET ?"
	}
	rows, err := s.db.QueryContext(ctx, q, append(args, limit, offset)...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []string{}
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out = append(out, id)
	}
	return out, rows.Err()
}
