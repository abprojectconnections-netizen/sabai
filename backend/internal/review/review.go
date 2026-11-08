// Package review lets users rate and review places, hotels, tours and bookings.
package review

import (
	"context"
	"database/sql"
	"errors"
	"github.com/travel-super-app/backend/internal/platform/dberr"
	"math"
	"strings"
	"unicode/utf8"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/travel-super-app/backend/internal/auth"
	"github.com/travel-super-app/backend/internal/platform/apiresponse"
	"github.com/travel-super-app/backend/internal/platform/dbtime"
)

var (
	ErrNotFound   = errors.New("review not found")
	ErrDuplicate  = errors.New("you have already reviewed this item")
	ErrValidation = errors.New("validation error")
)

var subjectTypes = map[string]bool{"DESTINATION": true, "HOTEL": true, "RESTAURANT": true, "TOUR": true, "BOOKING": true}

const maxBodyRunes = 2000

type Review struct {
	ID          string  `json:"id"`
	SubjectType string  `json:"subject_type"`
	SubjectID   string  `json:"subject_id"`
	Rating      float64 `json:"rating"`
	Body        string  `json:"body"`
	CreatedAt   string  `json:"created_at"`
	Mine        bool    `json:"mine"`
}

type Summary struct {
	Count   int     `json:"count"`
	Average float64 `json:"average"`
}

type CreateInput struct {
	SubjectType, SubjectID, Body string
	Rating                       float64
}

type Service struct{ db *sql.DB }

func NewService(db *sql.DB) *Service { return &Service{db: db} }

func validationf(msg string) error { return errors.Join(ErrValidation, errors.New(msg)) }

// Create stores one review per user per subject. The subject's existence is not verified here:
// the schema has no per-type foreign key, so callers must only expose reviewable subjects.
func (s *Service) Create(ctx context.Context, userID string, in CreateInput) (Review, error) {
	in.SubjectType = strings.ToUpper(strings.TrimSpace(in.SubjectType))
	in.SubjectID = strings.TrimSpace(in.SubjectID)
	in.Body = strings.TrimSpace(in.Body)
	if !subjectTypes[in.SubjectType] {
		return Review{}, validationf("subject_type must be one of DESTINATION, HOTEL, RESTAURANT, TOUR, BOOKING")
	}
	if in.SubjectID == "" || len(in.SubjectID) > 36 {
		return Review{}, validationf("subject_id is required (max 36 characters)")
	}
	if in.Rating < 1 || in.Rating > 5 || math.Mod(in.Rating*2, 1) != 0 {
		return Review{}, validationf("rating must be between 1 and 5 in steps of 0.5")
	}
	if utf8.RuneCountInString(in.Body) > maxBodyRunes {
		return Review{}, validationf("body must be at most 2000 characters")
	}
	var exists int
	err := s.db.QueryRowContext(ctx, "SELECT 1 FROM reviews WHERE user_id = ? AND subject_type = ? AND subject_id = ? AND deleted_at IS NULL LIMIT 1", userID, in.SubjectType, in.SubjectID).Scan(&exists)
	if err == nil {
		return Review{}, ErrDuplicate
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return Review{}, err
	}
	now := dbtime.Now()
	r := Review{ID: uuid.NewString(), SubjectType: in.SubjectType, SubjectID: in.SubjectID, Rating: in.Rating, Body: in.Body, CreatedAt: now.Format("2006-01-02T15:04:05.000000Z"), Mine: true}
	if _, err := s.db.ExecContext(ctx, "INSERT INTO reviews (id, created_at, updated_at, user_id, subject_type, subject_id, rating, body) VALUES (?, ?, ?, ?, ?, ?, ?, ?)", r.ID, now, now, userID, r.SubjectType, r.SubjectID, r.Rating, r.Body); err != nil {
		if dberr.IsDuplicate(err) {
			return Review{}, ErrDuplicate
		}
		return Review{}, err
	}
	return r, nil
}

const cols = "id, subject_type, subject_id, rating, COALESCE(body, ''), DATE_FORMAT(created_at, " + dbtime.SQLDateTime + "), user_id = ?"

func scan(rows *sql.Rows) ([]Review, error) {
	defer rows.Close()
	out := []Review{}
	for rows.Next() {
		var r Review
		if err := rows.Scan(&r.ID, &r.SubjectType, &r.SubjectID, &r.Rating, &r.Body, &r.CreatedAt, &r.Mine); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

func (s *Service) ForSubject(ctx context.Context, viewerID, subjectType, subjectID string, limit, offset int) ([]Review, Summary, error) {
	subjectType = strings.ToUpper(subjectType)
	if !subjectTypes[subjectType] || subjectID == "" {
		return nil, Summary{}, validationf("subject_type and subject_id are required")
	}
	rows, err := s.db.QueryContext(ctx, "SELECT "+cols+" FROM reviews WHERE subject_type = ? AND subject_id = ? AND deleted_at IS NULL ORDER BY created_at DESC, id LIMIT ? OFFSET ?", viewerID, subjectType, subjectID, limit, offset)
	if err != nil {
		return nil, Summary{}, err
	}
	items, err := scan(rows)
	if err != nil {
		return nil, Summary{}, err
	}
	var sum Summary
	var avg sql.NullFloat64
	if err := s.db.QueryRowContext(ctx, "SELECT COUNT(*), AVG(rating) FROM reviews WHERE subject_type = ? AND subject_id = ? AND deleted_at IS NULL", subjectType, subjectID).Scan(&sum.Count, &avg); err != nil {
		return nil, Summary{}, err
	}
	if avg.Valid {
		sum.Average = math.Round(avg.Float64*10) / 10
	}
	return items, sum, nil
}

func (s *Service) Mine(ctx context.Context, userID string, limit, offset int) ([]Review, error) {
	rows, err := s.db.QueryContext(ctx, "SELECT "+cols+" FROM reviews WHERE user_id = ? AND deleted_at IS NULL ORDER BY created_at DESC, id LIMIT ? OFFSET ?", userID, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	return scan(rows)
}

func (s *Service) Delete(ctx context.Context, userID, id string) error {
	now := dbtime.Now()
	res, err := s.db.ExecContext(ctx, "UPDATE reviews SET deleted_at = ?, updated_at = ? WHERE id = ? AND user_id = ? AND deleted_at IS NULL", now, now, id, userID)
	if err != nil {
		return err
	}
	if n, err := res.RowsAffected(); err != nil {
		return err
	} else if n == 0 {
		return ErrNotFound
	}
	return nil
}

type createRequest struct {
	SubjectType string  `json:"subject_type"`
	SubjectID   string  `json:"subject_id"`
	Rating      float64 `json:"rating"`
	Body        string  `json:"body"`
}

func fail(c *gin.Context, err error) {
	switch {
	case errors.Is(err, ErrNotFound):
		apiresponse.NotFound(c, "review not found")
	case errors.Is(err, ErrDuplicate):
		apiresponse.Conflict(c, err.Error())
	case errors.Is(err, ErrValidation):
		apiresponse.BadRequest(c, strings.TrimPrefix(strings.TrimPrefix(err.Error(), ErrValidation.Error()), "\n"))
	default:
		apiresponse.Internal(c)
	}
}

func RegisterRoutes(group *gin.RouterGroup, s *Service) {
	group.POST("", func(c *gin.Context) {
		p, ok := auth.CurrentPrincipal(c)
		if !ok {
			apiresponse.Unauthorized(c)
			return
		}
		var req createRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			apiresponse.BadRequest(c, "invalid JSON body")
			return
		}
		r, err := s.Create(c.Request.Context(), p.UserID, CreateInput{SubjectType: req.SubjectType, SubjectID: req.SubjectID, Body: req.Body, Rating: req.Rating})
		if err != nil {
			fail(c, err)
			return
		}
		apiresponse.Created(c, r)
	})
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
		items, sum, err := s.ForSubject(c.Request.Context(), p.UserID, c.Query("subject_type"), c.Query("subject_id"), limit, offset)
		if err != nil {
			fail(c, err)
			return
		}
		apiresponse.OK(c, gin.H{"items": items, "summary": sum})
	})
	group.GET("/mine", func(c *gin.Context) {
		p, ok := auth.CurrentPrincipal(c)
		if !ok {
			apiresponse.Unauthorized(c)
			return
		}
		limit, offset, ok := apiresponse.Page(c)
		if !ok {
			return
		}
		items, err := s.Mine(c.Request.Context(), p.UserID, limit, offset)
		if err != nil {
			apiresponse.Internal(c)
			return
		}
		apiresponse.OK(c, gin.H{"items": items})
	})
	group.DELETE("/:id", func(c *gin.Context) {
		p, ok := auth.CurrentPrincipal(c)
		if !ok {
			apiresponse.Unauthorized(c)
			return
		}
		if err := s.Delete(c.Request.Context(), p.UserID, c.Param("id")); err != nil {
			fail(c, err)
			return
		}
		apiresponse.NoContent(c)
	})
}
