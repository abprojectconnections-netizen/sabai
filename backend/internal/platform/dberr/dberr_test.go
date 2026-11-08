package dberr

import (
	"errors"
	"fmt"
	"testing"

	"github.com/go-sql-driver/mysql"
)

func TestClassification(t *testing.T) {
	dup := fmt.Errorf("wrapped: %w", &mysql.MySQLError{Number: 1062})
	fk := &mysql.MySQLError{Number: 1452}
	if !IsDuplicate(dup) || IsDuplicate(fk) || IsForeignKey(dup) || !IsForeignKey(fk) {
		t.Fatal("misclassified")
	}
	if IsDuplicate(errors.New("x")) || IsDuplicate(nil) {
		t.Fatal("non-mysql errors must not match")
	}
}
