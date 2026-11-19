// Package ratelimit is a small in-memory fixed-window limiter.
//
// It protects write endpoints from spam and brute force (community posts, coupon-code guessing, sign-in attempts).
// Limits are per process: with several API instances each keeps its own counters, so the effective limit is the
// configured value times the instance count. Move the counters to a shared store (for example Redis) before relying
// on exact limits behind a load balancer. Behind a proxy, ClientIP is only trustworthy when gin's trusted proxies are
// configured, otherwise a client can rotate X-Forwarded-For to dodge the per-IP limit.
package ratelimit

import (
	"net/http"
	"strconv"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/travel-super-app/backend/internal/auth"
	"github.com/travel-super-app/backend/internal/platform/apiresponse"
)

type window struct {
	count int
	reset time.Time
}

type Limiter struct {
	mu     sync.Mutex
	limit  int
	span   time.Duration
	hits   map[string]*window
	calls  int
	nowFor func() time.Time
}

// New allows at most limit requests per key in each span. limit <= 0 disables the limiter (every request is allowed).
func New(limit int, span time.Duration) *Limiter {
	return &Limiter{limit: limit, span: span, hits: map[string]*window{}, nowFor: time.Now}
}

// Allow records one request for key and reports whether it is within the limit; when it is not, retryAfter says how long
// until the window resets.
func (l *Limiter) Allow(key string) (ok bool, retryAfter time.Duration) {
	if l == nil || l.limit <= 0 {
		return true, 0
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	now := l.nowFor()
	l.calls++
	if l.calls%1024 == 0 { // drop expired windows so memory stays bounded
		for k, w := range l.hits {
			if !now.Before(w.reset) {
				delete(l.hits, k)
			}
		}
	}
	w := l.hits[key]
	if w == nil || !now.Before(w.reset) {
		l.hits[key] = &window{count: 1, reset: now.Add(l.span)}
		return true, 0
	}
	if w.count >= l.limit {
		return false, w.reset.Sub(now)
	}
	w.count++
	return true, 0
}

func isRead(method string) bool {
	return method == http.MethodGet || method == http.MethodHead || method == http.MethodOptions
}

func (l *Limiter) middleware(key func(*gin.Context) string) gin.HandlerFunc {
	return func(c *gin.Context) {
		if isRead(c.Request.Method) {
			c.Next()
			return
		}
		if ok, wait := l.Allow(key(c)); !ok {
			secs := int(wait.Seconds()) + 1
			c.Header("Retry-After", strconv.Itoa(secs))
			apiresponse.TooManyRequests(c, "too many requests, try again in "+strconv.Itoa(secs)+" seconds")
			c.Abort()
			return
		}
		c.Next()
	}
}

// PerUserWrites limits non-read requests per signed-in user. Mount it after authentication.
func (l *Limiter) PerUserWrites() gin.HandlerFunc {
	return l.middleware(func(c *gin.Context) string {
		if p, ok := auth.CurrentPrincipal(c); ok {
			return "u:" + p.UserID
		}
		return "ip:" + c.ClientIP()
	})
}

// PerIPWrites limits non-read requests per client IP (for unauthenticated routes such as sign-in).
func (l *Limiter) PerIPWrites() gin.HandlerFunc {
	return l.middleware(func(c *gin.Context) string { return "ip:" + c.ClientIP() })
}
