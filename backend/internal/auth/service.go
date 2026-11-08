package auth

import (
	"context"
	"database/sql"
	"errors"
	"github.com/travel-super-app/backend/internal/platform/dberr"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

var ErrInvalidCredentials = errors.New("invalid email or password")
var ErrEmailTaken = errors.New("email is already registered")

type Service struct {
	db        *sql.DB
	jwtSecret []byte
}

func NewService(db *sql.DB, jwtSecret string) *Service {
	if jwtSecret == "" {
		jwtSecret = "development-only-change-before-production"
	}
	return &Service{db: db, jwtSecret: []byte(jwtSecret)}
}

type Account struct{ ID, Email, DisplayName string }

func (s *Service) Register(ctx context.Context, email, password, displayName string) (Account, string, error) {
	var exists string
	err := s.db.QueryRowContext(ctx, "SELECT id FROM users WHERE email = ? AND deleted_at IS NULL LIMIT 1", email).Scan(&exists)
	if err == nil {
		return Account{}, "", ErrEmailTaken
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return Account{}, "", err
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return Account{}, "", err
	}
	account := Account{ID: uuid.NewString(), Email: email, DisplayName: displayName}
	now := time.Now().UTC()
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Account{}, "", err
	}
	defer tx.Rollback()
	if _, err = tx.ExecContext(ctx, "INSERT INTO users (id, created_at, updated_at, email, password_hash, status) VALUES (?, ?, ?, ?, ?, 'ACTIVE')", account.ID, now, now, account.Email, string(hash)); err != nil {
		if dberr.IsDuplicate(err) {
			return Account{}, "", ErrEmailTaken
		}
		return Account{}, "", err
	}
	if _, err = tx.ExecContext(ctx, "INSERT INTO user_profiles (id, created_at, updated_at, user_id, first_name) VALUES (?, ?, ?, ?, ?)", uuid.NewString(), now, now, account.ID, account.DisplayName); err != nil {
		return Account{}, "", err
	}
	if _, err = tx.ExecContext(ctx, `INSERT INTO user_roles (id, created_at, updated_at, user_id, role_id) SELECT ?, ?, ?, ?, id FROM roles WHERE code = 'CUSTOMER' AND deleted_at IS NULL`, uuid.NewString(), now, now, account.ID); err != nil {
		return Account{}, "", err
	}
	if err = tx.Commit(); err != nil {
		return Account{}, "", err
	}
	token, err := s.issueToken(account.ID, account.Email)
	return account, token, err
}

func (s *Service) Login(ctx context.Context, email, password string) (string, error) {
	var id, passwordHash string
	err := s.db.QueryRowContext(ctx, "SELECT id, password_hash FROM users WHERE email = ? AND status = 'ACTIVE' AND deleted_at IS NULL", email).Scan(&id, &passwordHash)
	if err != nil || bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(password)) != nil {
		return "", ErrInvalidCredentials
	}
	if _, err = s.db.ExecContext(ctx, "UPDATE users SET last_login_at = ?, updated_at = ? WHERE id = ?", time.Now().UTC(), time.Now().UTC(), id); err != nil {
		return "", err
	}
	return s.issueToken(id, email)
}

func (s *Service) issueToken(id, email string) (string, error) {
	claims := jwt.MapClaims{"sub": id, "email": email, "exp": time.Now().Add(24 * time.Hour).Unix(), "iat": time.Now().Unix()}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(s.jwtSecret)
}
