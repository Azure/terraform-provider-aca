package client

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/azcore"
	"github.com/Azure/azure-sdk-for-go/sdk/azcore/policy"

	"github.com/Azure/terraform-provider-aca/provider/internal/ids"
)

type staticCredential struct{}

func (staticCredential) GetToken(
	_ context.Context,
	_ policy.TokenRequestOptions,
) (azcore.AccessToken, error) {
	return azcore.AccessToken{Token: "test-token", ExpiresOn: time.Now().Add(time.Hour)}, nil
}

func newTestClient(t *testing.T, handler http.Handler) (*Client, *httptest.Server) {
	t.Helper()
	server := httptest.NewTLSServer(handler)
	endpoint, err := ids.ParseEndpoint(server.URL)
	if err != nil {
		server.Close()
		t.Fatalf("ParseEndpoint() error = %v", err)
	}
	group, err := ids.ParseGroupID(
		"/subscriptions/sub/resourceGroups/rg/providers/Microsoft.App/sandboxGroups/group",
	)
	if err != nil {
		server.Close()
		t.Fatalf("ParseGroupID() error = %v", err)
	}
	return New(endpoint, group, staticCredential{}, Options{
		APIVersion: "2026-02-01-preview",
		TokenScope: "scope/.default",
		UserAgent:  "test",
		HTTPClient: server.Client(),
	}), server
}

func TestListSandboxesSendsScopeAndLabels(t *testing.T) {
	t.Parallel()

	apiClient, server := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer test-token" {
			t.Errorf("Authorization = %q", r.Header.Get("Authorization"))
		}
		if r.URL.Query().Get("api-version") != "2026-02-01-preview" {
			t.Errorf("api-version = %q", r.URL.Query().Get("api-version"))
		}
		if r.URL.Query().Get("labels") != "a=1,b=2" {
			t.Errorf("labels = %q", r.URL.Query().Get("labels"))
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"value":[{"id":"one","state":"Running"}]}`))
	}))
	defer server.Close()

	values, err := apiClient.ListSandboxes(context.Background(), map[string]string{"b": "2", "a": "1"})
	if err != nil {
		t.Fatalf("ListSandboxes() error = %v", err)
	}
	if len(values) != 1 || values[0].ID != "one" {
		t.Fatalf("ListSandboxes() = %#v", values)
	}
}

func TestCreateDoesNotRetry(t *testing.T) {
	t.Parallel()

	var calls atomic.Int64
	apiClient, server := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		calls.Add(1)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = w.Write([]byte(`{"error":{"code":"InternalError","message":"failed"}}`))
	}))
	defer server.Close()

	_, err := apiClient.CreateDiskImage(context.Background(), CreateDiskImageRequest{
		Image: DiskImageSpec{Base: "example/image@sha256:abc"},
	})
	if err == nil {
		t.Fatal("CreateDiskImage() expected an error")
	}
	if calls.Load() != 1 {
		t.Fatalf("CreateDiskImage() calls = %d, want 1", calls.Load())
	}
}

func TestCreateDiskImageUsesManagedIdentityClientID(t *testing.T) {
	t.Parallel()

	apiClient, server := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var body map[string]any
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			t.Errorf("decoding request body: %v", err)
		}
		if body["managedIdentityClientId"] != "client-id" {
			t.Errorf("managedIdentityClientId = %#v", body["managedIdentityClientId"])
		}
		if _, exists := body["managedIdentityResourceId"]; exists {
			t.Error("request must not contain managedIdentityResourceId")
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"id":"disk-id","status":{"state":"Ready"}}`))
	}))
	defer server.Close()

	_, err := apiClient.CreateDiskImage(context.Background(), CreateDiskImageRequest{
		Image:                   DiskImageSpec{Base: "example/image:tag"},
		ManagedIdentityClientID: "client-id",
	})
	if err != nil {
		t.Fatalf("CreateDiskImage() error = %v", err)
	}
}

func TestCreateDiskImageUsesManagedIdentityResourceID(t *testing.T) {
	t.Parallel()

	apiClient, server := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var body map[string]any
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			t.Errorf("decoding request body: %v", err)
		}
		if body["managedIdentityResourceId"] != "system" {
			t.Errorf("managedIdentityResourceId = %#v", body["managedIdentityResourceId"])
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"id":"disk-id","status":{"state":"Ready"}}`))
	}))
	defer server.Close()

	_, err := apiClient.CreateDiskImage(context.Background(), CreateDiskImageRequest{
		Image:                     DiskImageSpec{Base: "example/image:tag"},
		ManagedIdentityResourceID: "system",
	})
	if err != nil {
		t.Fatalf("CreateDiskImage() error = %v", err)
	}
}

func TestListRejectsCrossHostContinuation(t *testing.T) {
	t.Parallel()

	apiClient, server := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"value":[],"nextLink":"https://example.test/next"}`))
	}))
	defer server.Close()

	_, err := apiClient.ListDiskImages(context.Background())
	if err == nil {
		t.Fatal("ListDiskImages() expected an error")
	}
}

func TestServiceErrorRedactsAuthorization(t *testing.T) {
	t.Parallel()

	apiClient, server := newTestClient(t, http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnauthorized)
		_, _ = w.Write([]byte(`{"error":{"code":"Unauthorized","message":"token rejected"}}`))
	}))
	defer server.Close()

	_, err := apiClient.GetSandbox(context.Background(), "sandbox")
	if err == nil {
		t.Fatal("GetSandbox() expected an error")
	}
	if got := err.Error(); got == "" || got == "test-token" {
		t.Fatalf("GetSandbox() error = %q", got)
	}
}

func TestIsAmbiguousCreateError(t *testing.T) {
	t.Parallel()

	if IsAmbiguousCreateError(&ServiceError{StatusCode: http.StatusBadRequest}) {
		t.Fatal("400 response must not be treated as ambiguous")
	}
	if !IsAmbiguousCreateError(&ServiceError{StatusCode: http.StatusServiceUnavailable}) {
		t.Fatal("503 response must be treated as ambiguous")
	}
	if !IsAmbiguousCreateError(context.DeadlineExceeded) {
		t.Fatal("transport/deadline error must be treated as ambiguous")
	}
}
