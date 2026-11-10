// Package faudit writes the hash-chained, append-only financial audit log inside the caller's transaction.
// Each row's hash covers the previous row's hash, so removing or editing any row is detectable by Verify.
package faudit

import (
	"bytes"
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
)

type Entry struct {
	ActorUserID string // empty = none (system / webhook)
	ActorType   string // USER | STAFF | SYSTEM | WEBHOOK | SUPPLIER
	ActorRoles  []string
	EntityType  string
	EntityID    string
	Action      string
	Changes     any // field-level before/after
	Reason      string
	ReferenceID string
	IP          string
	Device      string
	RequestID   string
}

type Tx interface {
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
}

func canon(v any) (string, error) {
	if v == nil {
		return "null", nil
	}
	raw, err := json.Marshal(v)
	if err != nil {
		return "", err
	}
	return canonRaw(raw)
}

// canonRaw re-encodes JSON deterministically (sorted keys, no spaces) so that the form MySQL returns hashes identically to the form written.
func canonRaw(raw []byte) (string, error) {
	var x any
	d := json.NewDecoder(bytes.NewReader(raw))
	d.UseNumber()
	if err := d.Decode(&x); err != nil {
		return "", err
	}
	out, err := json.Marshal(x)
	return string(out), err
}

func rowHash(prev, id string, at time.Time, actor, actorType, roles, entityType, entityID, action, changes, reason, ref, reqID string) string {
	h := sha256.Sum256([]byte(fmt.Sprintf("%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s",
		prev, id, at.UTC().Format("2006-01-02T15:04:05.000000"), actor, actorType, roles, entityType, entityID, action, changes, reason, ref, reqID)))
	return hex.EncodeToString(h[:])
}

// Append adds one entry. The previous row is locked so concurrent writers form a single chain.
func Append(ctx context.Context, tx Tx, e Entry) error {
	if e.ActorType == "" {
		e.ActorType = "USER"
	}
	changes, err := canon(e.Changes)
	if err != nil {
		return err
	}
	roles, err := canon(e.ActorRoles)
	if err != nil {
		return err
	}
	// One locked row serialises writers, so the chain has exactly one successor per entry.
	var prev sql.NullString
	if err = tx.QueryRowContext(ctx, "SELECT last_hash FROM financial_audit_head WHERE id = 1 FOR UPDATE").Scan(&prev); err != nil {
		return err
	}
	id, at := uuid.NewString(), time.Now().UTC().Truncate(time.Microsecond)
	hash := rowHash(prev.String, id, at, e.ActorUserID, e.ActorType, roles, e.EntityType, e.EntityID, e.Action, changes, e.Reason, e.ReferenceID, e.RequestID)
	res, err := tx.ExecContext(ctx, `INSERT INTO financial_audit_logs (id, occurred_at, actor_user_id, actor_type, actor_roles_json, entity_type, entity_id, action, field_changes_json, reason, reference_id, ip_address, device_info, request_id, prev_hash, row_hash)
		VALUES (?, ?, NULLIF(?, ''), ?, ?, ?, ?, ?, ?, NULLIF(?, ''), NULLIF(?, ''), NULLIF(?, ''), NULLIF(?, ''), NULLIF(?, ''), ?, ?)`,
		id, at, e.ActorUserID, e.ActorType, roles, e.EntityType, e.EntityID, e.Action, changes, e.Reason, e.ReferenceID, e.IP, e.Device, e.RequestID, nullable(prev), hash)
	if err != nil {
		return err
	}
	seq, err := res.LastInsertId()
	if err != nil {
		return err
	}
	_, err = tx.ExecContext(ctx, "UPDATE financial_audit_head SET last_seq = ?, last_hash = ? WHERE id = 1", seq, hash)
	return err
}

func nullable(s sql.NullString) any {
	if s.Valid {
		return s.String
	}
	return nil
}

// Verify walks the chain (rows after afterSeq; 0 = from the start) and returns the sequence number of the first row that does not verify (0 = intact).
func Verify(ctx context.Context, db *sql.DB, afterSeq int64) (badSeq int64, rows int, err error) {
	prev, first := "", true
	r, err := db.QueryContext(ctx, `SELECT seq, id, occurred_at, COALESCE(actor_user_id,''), actor_type, COALESCE(CAST(actor_roles_json AS CHAR),'null'), entity_type, entity_id, action,
		COALESCE(CAST(field_changes_json AS CHAR),'null'), COALESCE(reason,''), COALESCE(reference_id,''), COALESCE(request_id,''), COALESCE(prev_hash,''), row_hash FROM financial_audit_logs WHERE seq > ? ORDER BY seq`, afterSeq)
	if err != nil {
		return 0, 0, err
	}
	defer r.Close()
	for r.Next() {
		var seq int64
		var id, actor, atype, roles, et, eid, action, changes, reason, ref, req, prevHash, hash string
		var at time.Time
		if err := r.Scan(&seq, &id, &at, &actor, &atype, &roles, &et, &eid, &action, &changes, &reason, &ref, &req, &prevHash, &hash); err != nil {
			return 0, rows, err
		}
		rows++
		cr, err1 := canonRaw([]byte(roles))
		cc, err2 := canonRaw([]byte(changes))
		if first {
			prev, first = prevHash, false // the first row anchors the walk; every later row must chain from it
		}
		if err1 != nil || err2 != nil || prevHash != prev || rowHash(prev, id, at, actor, atype, cr, et, eid, action, cc, reason, ref, req) != hash {
			return seq, rows, nil
		}
		prev = hash
	}
	return 0, rows, r.Err()
}
