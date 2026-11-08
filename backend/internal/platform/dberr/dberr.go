// Package dberr classifies MySQL driver errors so services can turn constraint violations into clean 4xx results
// instead of leaking them as 500s. Constraints are the only race-free way to enforce uniqueness and references.
package dberr

import (
	"errors"

	"github.com/go-sql-driver/mysql"
)

const (
	codeDuplicate  = 1062 // ER_DUP_ENTRY
	codeForeignKey = 1452 // ER_NO_REFERENCED_ROW_2
)

func has(err error, code uint16) bool {
	var me *mysql.MySQLError
	return errors.As(err, &me) && me.Number == code
}

// IsDuplicate reports a unique-key violation.
func IsDuplicate(err error) bool { return has(err, codeDuplicate) }

// IsForeignKey reports an insert/update that references a row that does not exist.
func IsForeignKey(err error) bool { return has(err, codeForeignKey) }
