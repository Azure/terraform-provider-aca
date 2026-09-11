package provider

import (
	"context"
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/azcore"
	"github.com/hashicorp/terraform-plugin-framework/datasource"
	"github.com/hashicorp/terraform-plugin-framework/provider"
	"github.com/hashicorp/terraform-plugin-framework/provider/schema"
	"github.com/hashicorp/terraform-plugin-framework/resource"
	"github.com/hashicorp/terraform-plugin-framework/types"

	"github.com/Azure/terraform-provider-aca/provider/internal/auth"
	"github.com/Azure/terraform-provider-aca/provider/internal/client"
	"github.com/Azure/terraform-provider-aca/provider/internal/ids"
)

const (
	defaultAPIVersion = "2026-02-01-preview"
	defaultTokenScope = "https://dynamicsessions.io/.default"
)

var _ provider.Provider = &ACAProvider{}

type ACAProvider struct {
	version string
}

type providerModel struct {
	TenantID                  types.String `tfsdk:"tenant_id"`
	ClientID                  types.String `tfsdk:"client_id"`
	ClientSecret              types.String `tfsdk:"client_secret"`
	ClientCertificatePath     types.String `tfsdk:"client_certificate_path"`
	ClientCertificatePassword types.String `tfsdk:"client_certificate_password"`
	OIDCTokenFilePath         types.String `tfsdk:"oidc_token_file_path"`
	UseManagedIdentity        types.Bool   `tfsdk:"use_managed_identity"`
	ManagedIdentityClientID   types.String `tfsdk:"managed_identity_client_id"`
	UseAzureCLI               types.Bool   `tfsdk:"use_azure_cli"`
	AuthorityHost             types.String `tfsdk:"authority_host"`
	DisableInstanceDiscovery  types.Bool   `tfsdk:"disable_instance_discovery"`
	TokenScope                types.String `tfsdk:"token_scope"`
	APIVersion                types.String `tfsdk:"api_version"`
	AllowCustomEndpoint       types.Bool   `tfsdk:"allow_custom_endpoint"`
	UserAgent                 types.String `tfsdk:"user_agent"`
}

func New(version string) func() provider.Provider {
	return func() provider.Provider {
		return &ACAProvider{version: version}
	}
}

func (p *ACAProvider) Metadata(
	_ context.Context,
	_ provider.MetadataRequest,
	resp *provider.MetadataResponse,
) {
	resp.TypeName = "aca"
	resp.Version = p.version
}

func (p *ACAProvider) Schema(
	_ context.Context,
	_ provider.SchemaRequest,
	resp *provider.SchemaResponse,
) {
	resp.Schema = schema.Schema{
		MarkdownDescription: "Native Terraform provider for the Azure Container Apps Sandbox data plane.",
		Attributes: map[string]schema.Attribute{
			"tenant_id": schema.StringAttribute{
				Optional:    true,
				Description: "Microsoft Entra tenant ID. Defaults to AZURE_TENANT_ID.",
			},
			"client_id": schema.StringAttribute{
				Optional:    true,
				Description: "Client ID for service principal or workload identity authentication.",
			},
			"client_secret": schema.StringAttribute{
				Optional:    true,
				Sensitive:   true,
				Description: "Client secret for service principal authentication. Defaults to AZURE_CLIENT_SECRET.",
			},
			"client_certificate_path": schema.StringAttribute{
				Optional:    true,
				Description: "Path to a PEM or PKCS#12 client certificate.",
			},
			"client_certificate_password": schema.StringAttribute{
				Optional:    true,
				Sensitive:   true,
				Description: "Password for the client certificate.",
			},
			"oidc_token_file_path": schema.StringAttribute{
				Optional:    true,
				Description: "Path to a federated workload identity token file.",
			},
			"use_managed_identity": schema.BoolAttribute{
				Optional:    true,
				Description: "Use an Azure managed identity. Disabled by default to avoid probing IMDS on non-Azure hosts.",
			},
			"managed_identity_client_id": schema.StringAttribute{
				Optional:    true,
				Description: "Client ID of a user-assigned managed identity.",
			},
			"use_azure_cli": schema.BoolAttribute{
				Optional:    true,
				Description: "Use the identity logged in through Azure CLI as a local-development credential.",
			},
			"authority_host": schema.StringAttribute{
				Optional:    true,
				Description: "Microsoft Entra authority host. Defaults to AZURE_AUTHORITY_HOST or Azure public cloud.",
			},
			"disable_instance_discovery": schema.BoolAttribute{
				Optional:    true,
				Description: "Disable Microsoft Entra instance discovery for disconnected or private clouds.",
			},
			"token_scope": schema.StringAttribute{
				Optional:    true,
				Description: "OAuth token scope. Defaults to https://dynamicsessions.io/.default.",
			},
			"api_version": schema.StringAttribute{
				Optional:    true,
				Description: "Sandbox data-plane API version. Defaults to 2026-02-01-preview.",
			},
			"allow_custom_endpoint": schema.BoolAttribute{
				Optional:    true,
				Description: "Allow endpoints outside azuredevcompute.io. Requires an explicit token_scope.",
			},
			"user_agent": schema.StringAttribute{
				Optional:    true,
				Description: "Additional user-agent suffix for data-plane requests.",
			},
		},
	}
}

func (p *ACAProvider) Configure(
	ctx context.Context,
	req provider.ConfigureRequest,
	resp *provider.ConfigureResponse,
) {
	var config providerModel
	resp.Diagnostics.Append(req.Config.Get(ctx, &config)...)
	if resp.Diagnostics.HasError() {
		return
	}

	for name, value := range map[string]types.String{
		"tenant_id":                   config.TenantID,
		"client_id":                   config.ClientID,
		"client_secret":               config.ClientSecret,
		"client_certificate_path":     config.ClientCertificatePath,
		"client_certificate_password": config.ClientCertificatePassword,
		"token_scope":                 config.TokenScope,
		"api_version":                 config.APIVersion,
		"authority_host":              config.AuthorityHost,
		"oidc_token_file_path":        config.OIDCTokenFilePath,
		"managed_identity_client_id":  config.ManagedIdentityClientID,
	} {
		if value.IsUnknown() {
			resp.Diagnostics.AddError(
				"Unknown provider configuration",
				fmt.Sprintf("%s must be known when the provider is configured.", name),
			)
		}
	}
	if resp.Diagnostics.HasError() {
		return
	}

	explicitCredentialModes := 0
	for _, value := range []types.String{
		config.ClientSecret,
		config.ClientCertificatePath,
		config.OIDCTokenFilePath,
	} {
		if !value.IsNull() && stringValue(value) != "" {
			explicitCredentialModes++
		}
	}
	if explicitCredentialModes > 1 {
		resp.Diagnostics.AddError(
			"Conflicting Azure credentials",
			"Configure only one of client_secret, client_certificate_path, or oidc_token_file_path.",
		)
	}
	if !config.ClientCertificatePassword.IsNull() && config.ClientCertificatePath.IsNull() {
		resp.Diagnostics.AddError(
			"Client certificate path is required",
			"client_certificate_password cannot be configured without client_certificate_path.",
		)
	}
	if !config.ManagedIdentityClientID.IsNull() && !boolValue(config.UseManagedIdentity) {
		resp.Diagnostics.AddError(
			"Managed identity is not enabled",
			"managed_identity_client_id requires use_managed_identity = true.",
		)
	}
	if resp.Diagnostics.HasError() {
		return
	}

	credential, err := auth.NewCredential(auth.Config{
		TenantID:                  stringValue(config.TenantID),
		ClientID:                  stringValue(config.ClientID),
		ClientSecret:              stringValue(config.ClientSecret),
		ClientCertificatePath:     stringValue(config.ClientCertificatePath),
		ClientCertificatePassword: stringValue(config.ClientCertificatePassword),
		OIDCTokenFilePath:         stringValue(config.OIDCTokenFilePath),
		UseManagedIdentity:        boolValue(config.UseManagedIdentity),
		ManagedIdentityClientID:   stringValue(config.ManagedIdentityClientID),
		UseAzureCLI:               boolValue(config.UseAzureCLI),
		AuthorityHost:             stringValue(config.AuthorityHost),
		DisableInstanceDiscovery:  boolValue(config.DisableInstanceDiscovery),
	})
	if err != nil {
		resp.Diagnostics.AddError("Unable to configure Azure authentication", err.Error())
		return
	}

	tokenScope := stringValue(config.TokenScope)
	tokenScopeExplicit := tokenScope != ""
	if tokenScope == "" {
		tokenScope = defaultTokenScope
	}
	apiVersion := stringValue(config.APIVersion)
	if apiVersion == "" {
		apiVersion = defaultAPIVersion
	}

	httpClient := &http.Client{
		Timeout: 2 * time.Minute,
		CheckRedirect: func(_ *http.Request, _ []*http.Request) error {
			return fmt.Errorf("redirects are disabled for authenticated sandbox data-plane requests")
		},
	}

	data := &ProviderData{
		Credential:          credential,
		TokenScope:          tokenScope,
		TokenScopeExplicit:  tokenScopeExplicit,
		APIVersion:          apiVersion,
		AllowCustomEndpoint: boolValue(config.AllowCustomEndpoint),
		UserAgent:           p.version + " " + stringValue(config.UserAgent),
		HTTPClient:          httpClient,
	}
	resp.DataSourceData = data
	resp.ResourceData = data
}

func (p *ACAProvider) Resources(_ context.Context) []func() resource.Resource {
	return []func() resource.Resource{
		NewDiskImageResource,
		NewSandboxResource,
	}
}

func (p *ACAProvider) DataSources(_ context.Context) []func() datasource.DataSource {
	return []func() datasource.DataSource{
		NewDiskImageDataSource,
		NewPublicDiskImageDataSource,
		NewSandboxDataSource,
	}
}

type ProviderData struct {
	Credential          azcore.TokenCredential
	TokenScope          string
	TokenScopeExplicit  bool
	APIVersion          string
	AllowCustomEndpoint bool
	UserAgent           string
	HTTPClient          client.HTTPDoer

	clients sync.Map
	locks   sync.Map
}

func (d *ProviderData) Client(
	groupID string,
	location string,
	endpointValue string,
) (*client.Client, ids.Endpoint, ids.GroupID, error) {
	group, err := ids.ParseGroupID(groupID)
	if err != nil {
		return nil, ids.Endpoint{}, ids.GroupID{}, err
	}

	var endpoint ids.Endpoint
	switch {
	case location != "" && endpointValue != "":
		return nil, ids.Endpoint{}, ids.GroupID{}, fmt.Errorf("location and endpoint are mutually exclusive")
	case location != "":
		endpoint, err = ids.EndpointForLocation(location)
	case endpointValue != "":
		endpoint, err = ids.ParseEndpoint(endpointValue)
	default:
		return nil, ids.Endpoint{}, ids.GroupID{}, fmt.Errorf("exactly one of location or endpoint is required")
	}
	if err != nil {
		return nil, ids.Endpoint{}, ids.GroupID{}, err
	}

	if !ids.IsSandboxHost(endpoint.URL.Hostname()) {
		if !d.AllowCustomEndpoint {
			return nil, ids.Endpoint{}, ids.GroupID{}, fmt.Errorf(
				"endpoint host %q is outside azuredevcompute.io; set allow_custom_endpoint = true to use it",
				endpoint.URL.Hostname(),
			)
		}
		if !d.TokenScopeExplicit {
			return nil, ids.Endpoint{}, ids.GroupID{}, fmt.Errorf(
				"an explicit token_scope is required with a custom endpoint",
			)
		}
	}

	key := endpoint.URL.String() + "|" + group.String() + "|" + d.TokenScope + "|" + d.APIVersion
	if cached, ok := d.clients.Load(key); ok {
		return cached.(*client.Client), endpoint, group, nil
	}

	apiClient := client.New(endpoint, group, d.Credential, client.Options{
		APIVersion: d.APIVersion,
		TokenScope: d.TokenScope,
		UserAgent:  d.UserAgent,
		HTTPClient: d.HTTPClient,
	})
	actual, _ := d.clients.LoadOrStore(key, apiClient)
	return actual.(*client.Client), endpoint, group, nil
}

func (d *ProviderData) LockCreate(key string) func() {
	value, _ := d.locks.LoadOrStore(key, &sync.Mutex{})
	mutex := value.(*sync.Mutex)
	mutex.Lock()
	return mutex.Unlock
}

func stringValue(value types.String) string {
	if value.IsNull() || value.IsUnknown() {
		return ""
	}
	return value.ValueString()
}

func boolValue(value types.Bool) bool {
	return !value.IsNull() && !value.IsUnknown() && value.ValueBool()
}
