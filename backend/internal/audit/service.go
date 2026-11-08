package audit

import (
	"context"
	"database/sql"
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

type Entry struct {
	ActorUserID, Action, SubjectType, SubjectID, IPAddress, RequestID string
	Before, After                                                     any
}

// Execer is satisfied by *sql.DB and *sql.Tx, so an audit row can be written in the same transaction as the change it records.
type Execer interface {
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
}

func Log(ctx context.Context, db Execer, entry Entry) error {
	before, err := json.Marshal(entry.Before)
	if err != nil {
		return err
	}
	after, err := json.Marshal(entry.After)
	if err != nil {
		return err
	}
	_, err = db.ExecContext(ctx, `INSERT INTO audit_logs (id, created_at, updated_at, actor_user_id, action, subject_type, subject_id, before_json, after_json, ip_address, request_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`, uuid.NewString(), time.Now().UTC(), time.Now().UTC(), entry.ActorUserID, entry.Action, entry.SubjectType, entry.SubjectID, before, after, entry.IPAddress, entry.RequestID)
	return err
}
