package httpapi

import (
	"net/http"
	"net/url"
	"strings"

	"github.com/gin-gonic/gin"
)

func CORS(configuredOrigins string) gin.HandlerFunc {
	origins := make(map[string]struct{})

	for _, origin := range strings.Split(configuredOrigins, ",") {
		origin = strings.TrimSpace(origin)
		if origin != "" {
			origins[origin] = struct{}{}
		}
	}

	// Fallback for local development only.
	if len(origins) == 0 {
		origins["http://localhost:8081"] = struct{}{}
		origins["http://127.0.0.1:8081"] = struct{}{}
	}

	isAllowed := func(origin string) bool {
		if _, ok := origins[origin]; ok {
			return true
		}

		// Allow Flutter Web on dynamic localhost ports
		// during local development.
		u, err := url.Parse(origin)
		if err != nil || u.Host == "" {
			return false
		}

		if u.Scheme != "http" {
			return false
		}

		if u.User != nil || u.RawQuery != "" ||
			u.Fragment != "" || u.Path != "" {
			return false
		}

		host := strings.ToLower(u.Hostname())
		port := u.Port()

		return port != "" &&
			(port == "80" || port != "") &&
			(host == "localhost" || host == "127.0.0.1")
	}

	return func(c *gin.Context) {
		origin := c.GetHeader("Origin")

		if origin != "" && isAllowed(origin) {
			c.Header("Access-Control-Allow-Origin", origin)
			c.Header("Vary", "Origin")
			c.Header(
				"Access-Control-Allow-Methods",
				"GET, POST, PUT, PATCH, DELETE, OPTIONS",
			)
			c.Header(
				"Access-Control-Allow-Headers",
				"Authorization, Content-Type, Idempotency-Key, X-Request-ID",
			)
			c.Header("Access-Control-Expose-Headers", "X-Request-ID")
		}

		if c.Request.Method == http.MethodOptions {
			if origin == "" || !isAllowed(origin) {
				c.AbortWithStatus(http.StatusForbidden)
				return
			}

			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		c.Next()
	}
}
