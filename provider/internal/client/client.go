package client

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"math"
	mathrand "math/rand/v2"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/azcore"
	"github.com/Azure/azure-sdk-for-go/sdk/azcore/policy"

	"github.com/Azure/terraform-provider-aca/provider/internal/ids"
)

const (
	defaultAPIVersion = "2026-02-01-preview"
	defaultTokenScope = "https://dynamicsessions.io/.default"
	maxResponseBytes  = 8 * 1024 * 1024
)

type HTTPDoer interface {
	Do(*http.Request) (*http.Response, error)
}

type Options struct {
	APIVersion string
	TokenScope string
	UserAgent  string
	HTTPClient HTTPDoer
}

type Client struct {
	endpoint   ids.Endpoint
	group      ids.GroupID
	credential azcore.TokenCredential
	apiVersion string
	tokenScope string
	userAgent  string
	httpClient HTTPDoer
}

func New(
	endpoint ids.Endpoint,
	group ids.GroupID,
	credential azcore.TokenCredential,
	options Options,
) *Client {
	apiVersion := options.APIVersion
	if apiVersion == "" {
		apiVersion = defaultAPIVersion
	}
	tokenScope := options.TokenScope
	if tokenScope == "" {
		tokenScope = defaultTokenScope
	}
	httpClient := options.HTTPClient
	if httpClient == nil {
		httpClient = &http.Client{
			Timeout: 2 * time.Minute,
			CheckRedirect: func(_ *http.Request, _ []*http.Request) error {
				return fmt.Errorf("redirects are disabled for authenticated sandbox data-plane requests")
			},
		}
	}

	return &Client{
		endpoint:   endpoint,
		group:      group,
		credential: credential,
		apiVersion: apiVersion,
		tokenScope: tokenScope,
		userAgent:  strings.TrimSpace("terraform-provider-aca/" + options.UserAgent),
		httpClient: httpClient,
	}
}

func (c *Client) Endpoint() ids.Endpoint {
	return c.endpoint
}

func (c *Client) Group() ids.GroupID {
	return c.group
}

func (c *Client) ListDiskImages(ctx context.Context) ([]DiskImage, error) {
	var result []DiskImage
	next := c.group.DataPlanePath() + "/diskimages"

	for next != "" {
		var page json.RawMessage
		if err := c.get(ctx, next, &page, true); err != nil {
			return nil, err
		}
		if len(page) == 0 {
			break
		}
		var list []DiskImage
		if err := json.Unmarshal(page, &list); err == nil {
			result = append(result, list...)
			break
		}
		var wrapped DiskImageList
		if err := json.Unmarshal(page, &wrapped); err != nil {
			return nil, fmt.Errorf("decoding disk image list: %w", err)
		}
		result = append(result, wrapped.Value...)
		next = wrapped.NextLink
	}
	return result, nil
}

func (c *Client) GetDiskImage(ctx context.Context, id string) (DiskImage, error) {
	var result DiskImage
	err := c.get(ctx, c.group.DataPlanePath()+"/diskimages/"+url.PathEscape(id), &result, true)
	return result, err
}

func (c *Client) GetPublicDiskImage(ctx context.Context, name string) (PublicDiskImage, error) {
	var result PublicDiskImage
	err := c.get(ctx, c.group.DataPlanePath()+"/diskimages/public/"+url.PathEscape(name), &result, true)
	return result, err
}

func (c *Client) CreateDiskImage(
	ctx context.Context,
	request CreateDiskImageRequest,
) (DiskImage, error) {
	var result DiskImage
	err := c.send(
		ctx,
		http.MethodPut,
		c.group.DataPlanePath()+"/diskimages",
		request,
		&result,
		false,
	)
	return result, err
}

func (c *Client) DeleteDiskImage(ctx context.Context, id string) error {
	return c.send(
		ctx,
		http.MethodDelete,
		c.group.DataPlanePath()+"/diskimages/"+url.PathEscape(id),
		nil,
		nil,
		false,
	)
}

func (c *Client) ListSandboxes(
	ctx context.Context,
	labels map[string]string,
) ([]Sandbox, error) {
	path := c.group.DataPlanePath() + "/sandboxes"
	if len(labels) > 0 {
		keys := sortedKeys(labels)
		parts := make([]string, 0, len(keys))
		for _, key := range keys {
			parts = append(parts, key+"="+labels[key])
		}
		path += "?labels=" + url.QueryEscape(strings.Join(parts, ","))
	}

	var result []Sandbox
	next := path
	for next != "" {
		var page json.RawMessage
		if err := c.get(ctx, next, &page, true); err != nil {
			return nil, err
		}
		if len(page) == 0 {
			break
		}
		var list []Sandbox
		if err := json.Unmarshal(page, &list); err == nil {
			result = append(result, list...)
			break
		}
		var wrapped SandboxList
		if err := json.Unmarshal(page, &wrapped); err != nil {
			return nil, fmt.Errorf("decoding sandbox list: %w", err)
		}
		result = append(result, wrapped.Value...)
		next = wrapped.NextLink
	}
	return result, nil
}

func (c *Client) GetSandbox(ctx context.Context, id string) (Sandbox, error) {
	var result Sandbox
	err := c.get(ctx, c.group.DataPlanePath()+"/sandboxes/"+url.PathEscape(id), &result, true)
	return result, err
}

func (c *Client) CreateSandbox(
	ctx context.Context,
	request CreateSandboxRequest,
) (Sandbox, error) {
	var result Sandbox
	err := c.send(
		ctx,
		http.MethodPut,
		c.group.DataPlanePath()+"/sandboxes",
		request,
		&result,
		false,
	)
	return result, err
}

func (c *Client) DeleteSandbox(ctx context.Context, id string) error {
	return c.send(
		ctx,
		http.MethodDelete,
		c.group.DataPlanePath()+"/sandboxes/"+url.PathEscape(id),
		nil,
		nil,
		false,
	)
}

func (c *Client) SetLifecycle(
	ctx context.Context,
	id string,
	policy LifecyclePolicy,
) (LifecyclePolicy, error) {
	var result LifecyclePolicy
	err := c.send(
		ctx,
		http.MethodPost,
		c.group.DataPlanePath()+"/sandboxes/"+url.PathEscape(id)+"/lifecycle",
		policy,
		&result,
		false,
	)
	return result, err
}

func (c *Client) SetEgressPolicy(
	ctx context.Context,
	id string,
	policy EgressPolicy,
) (EgressPolicy, error) {
	var result EgressPolicy
	err := c.send(
		ctx,
		http.MethodPost,
		c.group.DataPlanePath()+"/sandboxes/"+url.PathEscape(id)+"/egresspolicy",
		policy,
		&result,
		false,
	)
	return result, err
}

func (c *Client) UpdatePorts(
	ctx context.Context,
	id string,
	ports []PortRequest,
) ([]SandboxPort, error) {
	var raw json.RawMessage
	err := c.send(
		ctx,
		http.MethodPut,
		c.group.DataPlanePath()+"/sandboxes/"+url.PathEscape(id)+"/ports",
		map[string]any{"ports": ports},
		&raw,
		false,
	)
	if err != nil {
		return nil, err
	}
	if len(raw) == 0 {
		return nil, nil
	}
	var result []SandboxPort
	if err := json.Unmarshal(raw, &result); err == nil {
		return result, nil
	}
	var wrapped struct {
		Ports []SandboxPort `json:"ports"`
	}
	if err := json.Unmarshal(raw, &wrapped); err != nil {
		return nil, fmt.Errorf("decoding port update response: %w", err)
	}
	return wrapped.Ports, nil
}

func (c *Client) ResumeSandbox(ctx context.Context, id string) error {
	return c.send(
		ctx,
		http.MethodPost,
		c.group.DataPlanePath()+"/sandboxes/"+url.PathEscape(id)+"/resume",
		nil,
		nil,
		false,
	)
}

func (c *Client) get(
	ctx context.Context,
	path string,
	result any,
	retryAuthorization bool,
) error {
	return c.sendWithOptions(ctx, http.MethodGet, path, nil, result, sendOptions{
		retryReads:         true,
		retryAuthorization: retryAuthorization,
	})
}

func (c *Client) send(
	ctx context.Context,
	method string,
	path string,
	body any,
	result any,
	retryReads bool,
) error {
	return c.sendWithOptions(ctx, method, path, body, result, sendOptions{
		retryReads: retryReads,
	})
}

type sendOptions struct {
	retryReads         bool
	retryAuthorization bool
}

func (c *Client) sendWithOptions(
	ctx context.Context,
	method string,
	path string,
	body any,
	result any,
	options sendOptions,
) error {
	var requestBody []byte
	var err error
	if body != nil {
		requestBody, err = json.Marshal(body)
		if err != nil {
			return fmt.Errorf("encoding sandbox data-plane request: %w", err)
		}
	}

	target, err := c.resolveURL(path)
	if err != nil {
		return err
	}

	started := time.Now()
	attempt := 0
	for {
		attempt++
		request, err := http.NewRequestWithContext(
			ctx,
			method,
			target.String(),
			bytes.NewReader(requestBody),
		)
		if err != nil {
			return fmt.Errorf("creating sandbox data-plane request: %w", err)
		}

		token, err := c.credential.GetToken(ctx, policy.TokenRequestOptions{
			Scopes: []string{c.tokenScope},
		})
		if err != nil {
			return fmt.Errorf("acquiring sandbox data-plane token: %w", err)
		}

		request.Header.Set("Authorization", "Bearer "+token.Token)
		request.Header.Set("Accept", "application/json")
		request.Header.Set("x-ms-client-request-id", requestID())
		if c.userAgent != "" {
			request.Header.Set("User-Agent", c.userAgent)
		}
		if body != nil {
			request.Header.Set("Content-Type", "application/json")
		}

		response, err := c.httpClient.Do(request)
		if err != nil {
			return fmt.Errorf("sending sandbox data-plane request: %w", err)
		}

		responseBody, readErr := io.ReadAll(io.LimitReader(response.Body, maxResponseBytes+1))
		_ = response.Body.Close()
		if readErr != nil {
			return fmt.Errorf("reading sandbox data-plane response: %w", readErr)
		}
		if len(responseBody) > maxResponseBytes {
			return fmt.Errorf("sandbox data-plane response exceeded %d bytes", maxResponseBytes)
		}

		if response.StatusCode >= 200 && response.StatusCode < 300 {
			if result == nil || response.StatusCode == http.StatusNoContent || len(responseBody) == 0 {
				return nil
			}
			if err := json.Unmarshal(responseBody, result); err != nil {
				return fmt.Errorf("decoding sandbox data-plane response: %w", err)
			}
			return nil
		}

		serviceError := serviceErrorFromResponse(response, truncate(responseBody, maxErrorBodyBytes))
		if !c.shouldRetry(serviceError, options, started, attempt) {
			return serviceError
		}
		if err := sleepContext(ctx, retryDelay(serviceError, attempt)); err != nil {
			return err
		}
	}
}

func (c *Client) resolveURL(path string) (*url.URL, error) {
	if absolute, err := url.Parse(path); err == nil && absolute.IsAbs() {
		if absolute.Scheme != "https" ||
			!strings.EqualFold(absolute.Hostname(), c.endpoint.URL.Hostname()) {
			return nil, fmt.Errorf("continuation URL must use HTTPS and the configured endpoint host")
		}
		return absolute, nil
	}

	relative, err := url.Parse(path)
	if err != nil {
		return nil, fmt.Errorf("parsing sandbox data-plane path: %w", err)
	}
	base := *c.endpoint.URL
	base.Path = strings.TrimSuffix(base.Path, "/") + "/" + strings.TrimPrefix(relative.Path, "/")
	query := relative.Query()
	if query.Get("api-version") == "" {
		query.Set("api-version", c.apiVersion)
	}
	base.RawQuery = query.Encode()
	return &base, nil
}

func (c *Client) shouldRetry(
	err *ServiceError,
	options sendOptions,
	started time.Time,
	attempt int,
) bool {
	if attempt >= 10 || time.Since(started) >= time.Minute {
		return false
	}
	if err.StatusCode == http.StatusForbidden && options.retryAuthorization {
		code := strings.ToLower(err.Code + " " + err.Message)
		return strings.Contains(code, "authorization") ||
			strings.Contains(code, "forbidden") ||
			strings.Contains(code, "role assignment")
	}
	if !options.retryReads {
		return false
	}
	switch err.StatusCode {
	case http.StatusRequestTimeout,
		http.StatusInternalServerError,
		http.StatusBadGateway,
		http.StatusServiceUnavailable,
		http.StatusGatewayTimeout:
		return true
	case http.StatusTooManyRequests:
		code := strings.ToLower(err.Code + " " + err.Message)
		return !strings.Contains(code, "quota") && !strings.Contains(code, "capacity")
	default:
		return false
	}
}

func retryDelay(err *ServiceError, attempt int) time.Duration {
	if err.RetryAfter > 0 {
		return min(err.RetryAfter, 30*time.Second)
	}
	exponent := math.Pow(2, float64(min(attempt-1, 5)))
	base := time.Duration(exponent * float64(500*time.Millisecond))
	jitter := time.Duration(mathrand.IntN(500)) * time.Millisecond
	return min(base+jitter, 30*time.Second)
}

func sleepContext(ctx context.Context, duration time.Duration) error {
	timer := time.NewTimer(duration)
	defer timer.Stop()
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-timer.C:
		return nil
	}
}

func requestID() string {
	var value [16]byte
	if _, err := rand.Read(value[:]); err != nil {
		return fmt.Sprintf("%d", time.Now().UnixNano())
	}
	value[6] = (value[6] & 0x0f) | 0x40
	value[8] = (value[8] & 0x3f) | 0x80
	encoded := hex.EncodeToString(value[:])
	return encoded[0:8] + "-" + encoded[8:12] + "-" + encoded[12:16] + "-" +
		encoded[16:20] + "-" + encoded[20:32]
}

func truncate(value []byte, limit int) []byte {
	if len(value) <= limit {
		return value
	}
	return value[:limit]
}

func sortedKeys(values map[string]string) []string {
	result := make([]string, 0, len(values))
	for key := range values {
		result = append(result, key)
	}
	slicesSort(result)
	return result
}

func slicesSort(values []string) {
	for i := 1; i < len(values); i++ {
		for j := i; j > 0 && values[j] < values[j-1]; j-- {
			values[j], values[j-1] = values[j-1], values[j]
		}
	}
}
