package trip

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
	"github.com/travel-super-app/backend/internal/platform/dbtime"
)

var (
	ErrNotFound   = errors.New("trip not found")
	ErrValidation = errors.New("validation error")
)

// Allowed trip lifecycle values.
var statuses = map[string]bool{"DRAFT": true, "PLANNED": true, "ONGOING": true, "COMPLETED": true, "CANCELLED": true}

const (
	maxNameRunes  = 200
	maxTitleRunes = 200
	maxIDLen      = 36 // destination_id is CHAR(36); catalog slugs and UUIDs both fit
	maxTripDays   = 60
)

type Trip struct {
	ID            string `json:"id"`
	Name          string `json:"name"`
	DestinationID string `json:"destination_id"`
	StartDate     string `json:"start_date"`
	EndDate       string `json:"end_date"`
	Status        string `json:"status"`
	CreatedAt     string `json:"created_at"`
	Days          []Day  `json:"days,omitempty"`
}

type Day struct {
	ID         string     `json:"id"`
	Date       string     `json:"date"`
	DayNumber  int        `json:"day_number"`
	Activities []Activity `json:"activities"`
}

type Activity struct {
	ID            string `json:"id"`
	Title         string `json:"title"`
	DestinationID string `json:"destination_id"`
	StartsAt      string `json:"starts_at"`
	EndsAt        string `json:"ends_at"`
}

type CreateInput struct{ Name, DestinationID, StartDate, EndDate string }

// UpdateInput carries optional changes; nil means "leave unchanged".
type UpdateInput struct{ Name, DestinationID, StartDate, EndDate, Status *string }

type ActivityInput struct{ Title, Date, StartTime, EndTime, DestinationID string }

type Service struct{ db *sql.DB }

func NewService(db *sql.DB) *Service { return &Service{db: db} }

func validationf(format string, a ...any) error {
	return fmt.Errorf("%w: %s", ErrValidation, fmt.Sprintf(format, a...))
}

func cleanName(s string) (string, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return "", validationf("trip name is required")
	}
	if utf8.RuneCountInString(s) > maxNameRunes {
		return "", validationf("trip name must be at most %d characters", maxNameRunes)
	}
	return s, nil
}

func cleanDest(s string) (string, error) {
	s = strings.TrimSpace(s)
	if len(s) > maxIDLen {
		return "", validationf("destination_id must be at most %d characters", maxIDLen)
	}
	return s, nil
}

// parseRange validates an optional [start, end] range; empty strings mean "not set".
func parseRange(start, end string) (sql.NullString, sql.NullString, error) {
	var s, e time.Time
	var err error
	out := func(v string) sql.NullString { return sql.NullString{String: v, Valid: v != ""} }
	if start != "" {
		if s, err = dbtime.ParseDate(start); err != nil {
			return out(""), out(""), validationf("start_date must be YYYY-MM-DD")
		}
	}
	if end != "" {
		if e, err = dbtime.ParseDate(end); err != nil {
			return out(""), out(""), validationf("end_date must be YYYY-MM-DD")
		}
	}
	if start != "" && end != "" {
		if e.Before(s) {
			return out(""), out(""), validationf("end_date must not be before start_date")
		}
		if int(e.Sub(s).Hours()/24)+1 > maxTripDays {
			return out(""), out(""), validationf("a trip can span at most %d days", maxTripDays)
		}
	}
	return out(start), out(end), nil
}

const tripCols = `id, name, COALESCE(destination_id, ''), COALESCE(DATE_FORMAT(start_date, ` + dbtime.SQLDate + `), ''), COALESCE(DATE_FORMAT(end_date, ` + dbtime.SQLDate + `), ''), status, DATE_FORMAT(created_at, ` + dbtime.SQLDateTime + `)`

func scanTrip(row interface{ Scan(...any) error }) (Trip, error) {
	var t Trip
	err := row.Scan(&t.ID, &t.Name, &t.DestinationID, &t.StartDate, &t.EndDate, &t.Status, &t.CreatedAt)
	return t, err
}

func (s *Service) List(ctx context.Context, userID string, limit, offset int) ([]Trip, error) {
	rows, err := s.db.QueryContext(ctx, "SELECT "+tripCols+" FROM trips WHERE user_id = ? AND deleted_at IS NULL ORDER BY created_at DESC, id LIMIT ? OFFSET ?", userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	trips := []Trip{}
	for rows.Next() {
		t, err := scanTrip(rows)
		if err != nil {
			return nil, err
		}
		trips = append(trips, t)
	}
	return trips, rows.Err()
}

func (s *Service) Create(ctx context.Context, userID string, in CreateInput) (Trip, error) {
	name, err := cleanName(in.Name)
	if err != nil {
		return Trip{}, err
	}
	dest, err := cleanDest(in.DestinationID)
	if err != nil {
		return Trip{}, err
	}
	start, end, err := parseRange(in.StartDate, in.EndDate)
	if err != nil {
		return Trip{}, err
	}
	now := dbtime.Now()
	t := Trip{ID: uuid.NewString(), Name: name, DestinationID: dest, StartDate: start.String, EndDate: end.String, Status: "DRAFT", CreatedAt: now.Format("2006-01-02T15:04:05.000000Z")}
	var destArg any
	if dest != "" {
		destArg = dest
	}
	_, err = s.db.ExecContext(ctx, "INSERT INTO trips (id, created_at, updated_at, user_id, destination_id, name, start_date, end_date, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'DRAFT')", t.ID, now, now, userID, destArg, name, nullable(start), nullable(end))
	if err != nil {
		return Trip{}, err
	}
	return t, nil
}

func nullable(v sql.NullString) any {
	if v.Valid {
		return v.String
	}
	return nil
}

// Get returns one trip with its itinerary. Trips owned by other users are reported as not found.
func (s *Service) Get(ctx context.Context, userID, tripID string) (Trip, error) {
	t, err := scanTrip(s.db.QueryRowContext(ctx, "SELECT "+tripCols+" FROM trips WHERE id = ? AND user_id = ? AND deleted_at IS NULL", tripID, userID))
	if errors.Is(err, sql.ErrNoRows) {
		return Trip{}, ErrNotFound
	}
	if err != nil {
		return Trip{}, err
	}
	dayRows, err := s.db.QueryContext(ctx, "SELECT id, DATE_FORMAT(travel_date, "+dbtime.SQLDate+"), day_number FROM trip_days WHERE trip_id = ? AND deleted_at IS NULL ORDER BY day_number, travel_date", tripID)
	if err != nil {
		return Trip{}, err
	}
	defer dayRows.Close()
	index := map[string]int{}
	t.Days = []Day{}
	for dayRows.Next() {
		var d Day
		if err := dayRows.Scan(&d.ID, &d.Date, &d.DayNumber); err != nil {
			return Trip{}, err
		}
		d.Activities = []Activity{}
		index[d.ID] = len(t.Days)
		t.Days = append(t.Days, d)
	}
	if err := dayRows.Err(); err != nil {
		return Trip{}, err
	}
	actRows, err := s.db.QueryContext(ctx, `SELECT a.id, a.trip_day_id, a.title, COALESCE(a.destination_id, ''), COALESCE(DATE_FORMAT(a.starts_at, `+dbtime.SQLDateTime+`), ''), COALESCE(DATE_FORMAT(a.ends_at, `+dbtime.SQLDateTime+`), '')
FROM trip_activities a JOIN trip_days d ON d.id = a.trip_day_id
WHERE d.trip_id = ? AND d.deleted_at IS NULL AND a.deleted_at IS NULL ORDER BY a.starts_at, a.created_at, a.id`, tripID)
	if err != nil {
		return Trip{}, err
	}
	defer actRows.Close()
	for actRows.Next() {
		var a Activity
		var dayID string
		if err := actRows.Scan(&a.ID, &dayID, &a.Title, &a.DestinationID, &a.StartsAt, &a.EndsAt); err != nil {
			return Trip{}, err
		}
		if i, ok := index[dayID]; ok {
			t.Days[i].Activities = append(t.Days[i].Activities, a)
		}
	}
	return t, actRows.Err()
}

func (s *Service) Update(ctx context.Context, userID, tripID string, in UpdateInput) (Trip, error) {
	t, err := scanTrip(s.db.QueryRowContext(ctx, "SELECT "+tripCols+" FROM trips WHERE id = ? AND user_id = ? AND deleted_at IS NULL", tripID, userID))
	if errors.Is(err, sql.ErrNoRows) {
		return Trip{}, ErrNotFound
	}
	if err != nil {
		return Trip{}, err
	}
	if in.Name != nil {
		if t.Name, err = cleanName(*in.Name); err != nil {
			return Trip{}, err
		}
	}
	if in.DestinationID != nil {
		if t.DestinationID, err = cleanDest(*in.DestinationID); err != nil {
			return Trip{}, err
		}
	}
	if in.StartDate != nil {
		t.StartDate = *in.StartDate
	}
	if in.EndDate != nil {
		t.EndDate = *in.EndDate
	}
	start, end, err := parseRange(t.StartDate, t.EndDate)
	if err != nil {
		return Trip{}, err
	}
	if in.Status != nil {
		if !statuses[*in.Status] {
			return Trip{}, validationf("status must be one of DRAFT, PLANNED, ONGOING, COMPLETED, CANCELLED")
		}
		t.Status = *in.Status
	}
	var destArg any
	if t.DestinationID != "" {
		destArg = t.DestinationID
	}
	res, err := s.db.ExecContext(ctx, "UPDATE trips SET name = ?, destination_id = ?, start_date = ?, end_date = ?, status = ?, updated_at = ? WHERE id = ? AND user_id = ? AND deleted_at IS NULL", t.Name, destArg, nullable(start), nullable(end), t.Status, dbtime.Now(), tripID, userID)
	if err != nil {
		return Trip{}, err
	}
	if n, err := res.RowsAffected(); err == nil && n == 0 {
		// MySQL reports 0 for a no-op update; confirm the row still exists before claiming it is gone.
		var one int
		if err := s.db.QueryRowContext(ctx, "SELECT 1 FROM trips WHERE id = ? AND user_id = ? AND deleted_at IS NULL", tripID, userID).Scan(&one); errors.Is(err, sql.ErrNoRows) {
			return Trip{}, ErrNotFound
		}
	}
	return t, nil
}

func (s *Service) Delete(ctx context.Context, userID, tripID string) error {
	now := dbtime.Now()
	res, err := s.db.ExecContext(ctx, "UPDATE trips SET deleted_at = ?, updated_at = ? WHERE id = ? AND user_id = ? AND deleted_at IS NULL", now, now, tripID, userID)
	if err != nil {
		return err
	}
	n, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if n == 0 {
		return ErrNotFound
	}
	return nil
}

func parseClock(v string) (string, error) {
	if v == "" {
		return "", nil
	}
	t, err := time.Parse("15:04", v)
	if err != nil {
		return "", validationf("time must be HH:MM")
	}
	return t.Format("15:04:05"), nil
}

// AddActivity adds an item to the trip's itinerary, creating the trip day on first use.
// Times are wall-clock times at the destination; no time zone conversion is applied.
func (s *Service) AddActivity(ctx context.Context, userID, tripID string, in ActivityInput) (Activity, error) {
	title := strings.TrimSpace(in.Title)
	if title == "" || utf8.RuneCountInString(title) > maxTitleRunes {
		return Activity{}, validationf("title is required and must be at most %d characters", maxTitleRunes)
	}
	date, err := dbtime.ParseDate(in.Date)
	if err != nil {
		return Activity{}, validationf("date must be YYYY-MM-DD")
	}
	startClock, err := parseClock(in.StartTime)
	if err != nil {
		return Activity{}, err
	}
	endClock, err := parseClock(in.EndTime)
	if err != nil {
		return Activity{}, err
	}
	if endClock != "" && startClock == "" {
		return Activity{}, validationf("start_time is required when end_time is set")
	}
	if startClock != "" && endClock != "" && endClock < startClock {
		return Activity{}, validationf("end_time must not be before start_time")
	}
	dest, err := cleanDest(in.DestinationID)
	if err != nil {
		return Activity{}, err
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Activity{}, err
	}
	defer tx.Rollback()

	var tripStart, tripEnd sql.NullString
	err = tx.QueryRowContext(ctx, "SELECT DATE_FORMAT(start_date, "+dbtime.SQLDate+"), DATE_FORMAT(end_date, "+dbtime.SQLDate+") FROM trips WHERE id = ? AND user_id = ? AND deleted_at IS NULL FOR UPDATE", tripID, userID).Scan(&tripStart, &tripEnd)
	if errors.Is(err, sql.ErrNoRows) {
		return Activity{}, ErrNotFound
	}
	if err != nil {
		return Activity{}, err
	}
	if tripStart.Valid && in.Date < tripStart.String || tripEnd.Valid && in.Date > tripEnd.String {
		return Activity{}, validationf("date is outside the trip dates")
	}

	now := dbtime.Now()
	var dayID string
	err = tx.QueryRowContext(ctx, "SELECT id FROM trip_days WHERE trip_id = ? AND travel_date = ? AND deleted_at IS NULL LIMIT 1", tripID, in.Date).Scan(&dayID)
	if errors.Is(err, sql.ErrNoRows) {
		dayNumber := 1
		if tripStart.Valid {
			ts, _ := dbtime.ParseDate(tripStart.String)
			dayNumber = int(date.Sub(ts).Hours()/24) + 1
		} else if err := tx.QueryRowContext(ctx, "SELECT COUNT(*) + 1 FROM trip_days WHERE trip_id = ? AND deleted_at IS NULL", tripID).Scan(&dayNumber); err != nil {
			return Activity{}, err
		}
		dayID = uuid.NewString()
		if _, err := tx.ExecContext(ctx, "INSERT INTO trip_days (id, created_at, updated_at, trip_id, travel_date, day_number) VALUES (?, ?, ?, ?, ?, ?)", dayID, now, now, tripID, in.Date, dayNumber); err != nil {
			return Activity{}, err
		}
	} else if err != nil {
		return Activity{}, err
	}

	a := Activity{ID: uuid.NewString(), Title: title, DestinationID: dest}
	var startsArg, endsArg, destArg any
	if startClock != "" {
		startsArg = in.Date + " " + startClock
		a.StartsAt = in.Date + "T" + startClock + ".000000Z"
	}
	if endClock != "" {
		endsArg = in.Date + " " + endClock
		a.EndsAt = in.Date + "T" + endClock + ".000000Z"
	}
	if dest != "" {
		destArg = dest
	}
	if _, err := tx.ExecContext(ctx, "INSERT INTO trip_activities (id, created_at, updated_at, trip_day_id, destination_id, title, starts_at, ends_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)", a.ID, now, now, dayID, destArg, title, startsArg, endsArg); err != nil {
		return Activity{}, err
	}
	if err := tx.Commit(); err != nil {
		return Activity{}, err
	}
	return a, nil
}

func (s *Service) DeleteActivity(ctx context.Context, userID, tripID, activityID string) error {
	now := dbtime.Now()
	res, err := s.db.ExecContext(ctx, `UPDATE trip_activities a JOIN trip_days d ON d.id = a.trip_day_id JOIN trips t ON t.id = d.trip_id
SET a.deleted_at = ?, a.updated_at = ? WHERE a.id = ? AND t.id = ? AND t.user_id = ? AND t.deleted_at IS NULL AND a.deleted_at IS NULL`, now, now, activityID, tripID, userID)
	if err != nil {
		return err
	}
	n, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if n == 0 {
		return ErrNotFound
	}
	return nil
}
