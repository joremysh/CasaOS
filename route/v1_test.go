package route

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/labstack/echo/v4"
	echo_middleware "github.com/labstack/echo/v4/middleware"
	"gotest.tools/assert"
)

func TestSkipInternalStatusLog(t *testing.T) {
	var buf bytes.Buffer
	e := echo.New()
	e.Use(echo_middleware.LoggerWithConfig(echo_middleware.LoggerConfig{
		Skipper: skipInternalStatusLog,
		Output:  &buf,
	}))
	ok := func(c echo.Context) error { return c.NoContent(http.StatusOK) }
	e.POST("/v1/notify/:path", ok)
	e.POST("/v1/notify/system_status", ok)

	cases := []struct {
		name       string
		path       string
		remoteAddr string
		forwarded  string
		logged     bool
	}{
		{"status from IPv4 loopback", "/v1/notify/system_status", "127.0.0.1:42769", "", false},
		{"status from IPv6 loopback", "/v1/notify/system_status", "[::1]:42769", "", false},
		{"status from LAN", "/v1/notify/system_status", "192.168.1.20:5000", "", true},
		{"status proxied from LAN", "/v1/notify/system_status", "127.0.0.1:42769", "192.168.1.20", true},
		{"other notify from loopback", "/v1/notify/app_install", "127.0.0.1:42769", "", true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			buf.Reset()
			req := httptest.NewRequest(http.MethodPost, tc.path, nil)
			req.RemoteAddr = tc.remoteAddr
			if tc.forwarded != "" {
				req.Header.Set(echo.HeaderXForwardedFor, tc.forwarded)
			}
			e.ServeHTTP(httptest.NewRecorder(), req)
			assert.Equal(t, buf.Len() > 0, tc.logged)
		})
	}
}
