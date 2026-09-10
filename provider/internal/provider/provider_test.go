package provider

import (
	"context"
	"testing"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/azcore"
	"github.com/Azure/azure-sdk-for-go/sdk/azcore/policy"
	"github.com/hashicorp/terraform-plugin-framework/providerserver"
	"github.com/hashicorp/terraform-plugin-go/tfprotov6"
)

type providerTestCredential struct{}

func (providerTestCredential) GetToken(
	_ context.Context,
	_ policy.TokenRequestOptions,
) (azcore.AccessToken, error) {
	return azcore.AccessToken{Token: "test", ExpiresOn: time.Now().Add(time.Hour)}, nil
}

func TestProviderSchema(t *testing.T) {
	t.Parallel()

	server, err := providerserver.NewProtocol6WithError(New("test")())()
	if err != nil {
		t.Fatalf("NewProtocol6WithError() error = %v", err)
	}
	response, err := server.GetProviderSchema(
		context.Background(),
		&tfprotov6.GetProviderSchemaRequest{},
	)
	if err != nil {
		t.Fatalf("GetProviderSchema() error = %v", err)
	}
	for _, diagnostic := range response.Diagnostics {
		if diagnostic.Severity == tfprotov6.DiagnosticSeverityError {
			t.Errorf("schema diagnostic: %s: %s", diagnostic.Summary, diagnostic.Detail)
		}
	}
	for _, name := range []string{"aca_sandbox", "aca_sandbox_disk_image"} {
		if _, ok := response.ResourceSchemas[name]; !ok {
			t.Errorf("missing resource schema %q", name)
		}
	}
	for _, name := range []string{
		"aca_sandbox",
		"aca_sandbox_disk_image",
		"aca_sandbox_public_disk_image",
	} {
		if _, ok := response.DataSourceSchemas[name]; !ok {
			t.Errorf("missing data source schema %q", name)
		}
	}
}

func TestProviderDataRejectsUnapprovedCustomEndpoint(t *testing.T) {
	t.Parallel()

	data := &ProviderData{
		Credential: providerTestCredential{},
		TokenScope: defaultTokenScope,
		APIVersion: defaultAPIVersion,
	}
	_, _, _, err := data.Client(
		"/subscriptions/sub/resourceGroups/rg/providers/Microsoft.App/sandboxGroups/group",
		"",
		"https://sandbox.example.test",
	)
	if err == nil {
		t.Fatal("Client() expected an error")
	}
}

func TestProviderDataRequiresExplicitScopeForCustomEndpoint(t *testing.T) {
	t.Parallel()

	data := &ProviderData{
		Credential:          providerTestCredential{},
		TokenScope:          defaultTokenScope,
		APIVersion:          defaultAPIVersion,
		AllowCustomEndpoint: true,
	}
	_, _, _, err := data.Client(
		"/subscriptions/sub/resourceGroups/rg/providers/Microsoft.App/sandboxGroups/group",
		"",
		"https://sandbox.example.test",
	)
	if err == nil {
		t.Fatal("Client() expected an error")
	}
}

func TestProviderDataAllowsExplicitCustomEndpoint(t *testing.T) {
	t.Parallel()

	data := &ProviderData{
		Credential:          providerTestCredential{},
		TokenScope:          "api://sandbox/.default",
		TokenScopeExplicit:  true,
		APIVersion:          defaultAPIVersion,
		AllowCustomEndpoint: true,
	}
	if _, _, _, err := data.Client(
		"/subscriptions/sub/resourceGroups/rg/providers/Microsoft.App/sandboxGroups/group",
		"",
		"https://sandbox.example.test",
	); err != nil {
		t.Fatalf("Client() error = %v", err)
	}
}
