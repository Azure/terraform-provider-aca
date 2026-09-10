package client

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"
)

const maxErrorBodyBytes = 64 * 1024

type ServiceError struct {
	StatusCode int
	Code       string
	Message    string
	RequestID  string
	RetryAfter time.Duration
}

func (e *ServiceError) Error() string {
	message := e.Message
	if message == "" {
		message = http.StatusText(e.StatusCode)
	}
	if e.Code != "" {
		message = e.Code + ": " + message
	}
	if e.RequestID != "" {
		message += " (request ID: " + e.RequestID + ")"
	}
	return fmt.Sprintf("sandbox data-plane request failed with HTTP %d: %s", e.StatusCode, message)
}

func IsNotFound(err error) bool {
	var serviceError *ServiceError
	return errors.As(err, &serviceError) && serviceError.StatusCode == http.StatusNotFound
}

func IsConflict(err error) bool {
	var serviceError *ServiceError
	return errors.As(err, &serviceError) && serviceError.StatusCode == http.StatusConflict
}

func IsAmbiguousCreateError(err error) bool {
	if err == nil {
		return false
	}
	var serviceError *ServiceError
	if !errors.As(err, &serviceError) {
		return true
	}
	return serviceError.StatusCode == http.StatusRequestTimeout ||
		serviceError.StatusCode >= http.StatusInternalServerError
}

func serviceErrorFromResponse(response *http.Response, body []byte) *ServiceError {
	type errorBody struct {
		Error *struct {
			Code    string `json:"code"`
			Message string `json:"message"`
		} `json:"error"`
		Code    string `json:"code"`
		Message string `json:"message"`
	}

	var decoded errorBody
	_ = json.Unmarshal(body, &decoded)

	code := decoded.Code
	message := decoded.Message
	if decoded.Error != nil {
		if decoded.Error.Code != "" {
			code = decoded.Error.Code
		}
		if decoded.Error.Message != "" {
			message = decoded.Error.Message
		}
	}
	if message == "" && len(body) > 0 {
		message = strings.TrimSpace(string(body))
	}

	return &ServiceError{
		StatusCode: response.StatusCode,
		Code:       code,
		Message:    message,
		RequestID: firstHeader(
			response.Header,
			"x-ms-request-id",
			"x-ms-correlation-request-id",
			"x-ms-client-request-id",
		),
		RetryAfter: parseRetryAfter(response.Header),
	}
}

func firstHeader(headers http.Header, names ...string) string {
	for _, name := range names {
		if value := headers.Get(name); value != "" {
			return value
		}
	}
	return ""
}

func parseRetryAfter(headers http.Header) time.Duration {
	if milliseconds := headers.Get("x-ms-retry-after-ms"); milliseconds != "" {
		if value, err := strconv.Atoi(milliseconds); err == nil && value >= 0 {
			return time.Duration(value) * time.Millisecond
		}
	}
	if seconds := headers.Get("Retry-After"); seconds != "" {
		if value, err := strconv.Atoi(seconds); err == nil && value >= 0 {
			return time.Duration(value) * time.Second
		}
		if when, err := http.ParseTime(seconds); err == nil {
			return time.Until(when)
		}
	}
	return 0
}
