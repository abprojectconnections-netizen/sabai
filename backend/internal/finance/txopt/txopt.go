// Package txopt holds the transaction options every financial transaction uses.
//
// READ COMMITTED is deliberate: under the default REPEATABLE READ, a plain read at the start of a transaction (for example an
// idempotency lookup) fixes a snapshot, and later "check, then act" reads inside the same transaction cannot see rows that a
// concurrent transaction committed while we waited for a row lock. The integration tests found exactly that: eight concurrent
// refund requests for one booking were all accepted. With READ COMMITTED each statement sees the latest committed data, and
// the row locks (SELECT ... FOR UPDATE) order the work. It also avoids gap locks and the deadlocks they cause.
package txopt

import "database/sql"

var Financial = &sql.TxOptions{Isolation: sql.LevelReadCommitted}
