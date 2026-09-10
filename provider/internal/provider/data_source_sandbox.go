package provider

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/hashicorp/terraform-plugin-framework/datasource"
	"github.com/hashicorp/terraform-plugin-framework/datasource/schema"
	"github.com/hashicorp/terraform-plugin-framework/types"

	"github.com/Azure/terraform-provider-aca/provider/internal/client"
	"github.com/Azure/terraform-provider-aca/provider/internal/ids"
)

var (
	_ datasource.DataSource              = &sandboxDataSource{}
	_ datasource.DataSourceWithConfigure = &sandboxDataSource{}
)

type sandboxDataSource struct {
	providerData *ProviderData
}

type sandboxDataSourceModel struct {
	SandboxGroupID types.String `tfsdk:"sandbox_group_id"`
	Location       types.String `tfsdk:"location"`
	Endpoint       types.String `tfsdk:"endpoint"`
	ID             types.String `tfsdk:"id"`
	Name           types.String `tfsdk:"name"`
	State          types.String `tfsdk:"state"`
	StoppedReason  types.String `tfsdk:"stopped_reason"`
	StoppedAt      types.String `tfsdk:"stopped_at"`
	Labels         types.Map    `tfsdk:"labels"`
	Connections    types.Set    `tfsdk:"connections"`
	Entrypoint     types.List   `tfsdk:"entrypoint"`
	Hostname       types.String `tfsdk:"hostname"`
	ManagementURL  types.String `tfsdk:"management_url"`
	CreatedAt      types.String `tfsdk:"created_at"`
	Region         types.String `tfsdk:"region"`
	ResourceURL    types.String `tfsdk:"resource_url"`
	SourceJSON     types.String `tfsdk:"source_json"`
	ResourcesJSON  types.String `tfsdk:"resources_json"`
	LifecycleJSON  types.String `tfsdk:"lifecycle_json"`
	EgressJSON     types.String `tfsdk:"egress_policy_json"`
	PortsJSON      types.String `tfsdk:"ports_json"`
}

func NewSandboxDataSource() datasource.DataSource {
	return &sandboxDataSource{}
}

func (d *sandboxDataSource) Metadata(
	_ context.Context,
	req datasource.MetadataRequest,
	resp *datasource.MetadataResponse,
) {
	resp.TypeName = req.ProviderTypeName + "_sandbox"
}

func (d *sandboxDataSource) Schema(
	_ context.Context,
	_ datasource.SchemaRequest,
	resp *datasource.SchemaResponse,
) {
	resp.Schema = schema.Schema{
		MarkdownDescription: "Reads an ACA Sandbox by service-generated ID. Environment values are intentionally omitted.",
		Attributes: map[string]schema.Attribute{
			"sandbox_group_id": schema.StringAttribute{Required: true, Description: "ARM resource ID of the SandboxGroup."},
			"location":         schema.StringAttribute{Optional: true, Description: "Canonical Azure location."},
			"endpoint":         schema.StringAttribute{Optional: true, Description: "Explicit Sandbox data-plane endpoint."},
			"id":               schema.StringAttribute{Required: true, Description: "Service-generated Sandbox ID."},
			"name":             schema.StringAttribute{Computed: true, Description: "Provider logical name when present in labels."},
			"state":            schema.StringAttribute{Computed: true, Description: "Current operational state."},
			"stopped_reason":   schema.StringAttribute{Computed: true, Description: "Reason the Sandbox stopped."},
			"stopped_at":       schema.StringAttribute{Computed: true, Description: "UTC time at which the Sandbox stopped."},
			"labels":           schema.MapAttribute{Computed: true, ElementType: types.StringType, Description: "Sandbox labels."},
			"connections":      schema.SetAttribute{Computed: true, ElementType: types.StringType, Description: "Sandbox connection names."},
			"entrypoint":       schema.ListAttribute{Computed: true, ElementType: types.StringType, Description: "Sandbox entrypoint."},
			"hostname":         schema.StringAttribute{Computed: true, Description: "Sandbox hostname."},
			"management_url":   schema.StringAttribute{Computed: true, Sensitive: true, Description: "Sandbox management URL."},
			"created_at":       schema.StringAttribute{Computed: true, Description: "Sandbox creation time."},
			"region":           schema.StringAttribute{Computed: true, Description: "Service-reported region."},
			"resource_url":     schema.StringAttribute{Computed: true, Description: "Canonical data-plane resource URL."},
			"source_json":      schema.StringAttribute{Computed: true, Description: "JSON representation of the Sandbox source."},
			"resources_json":   schema.StringAttribute{Computed: true, Description: "JSON representation of allocated resources."},
			"lifecycle_json":   schema.StringAttribute{Computed: true, Description: "JSON representation of lifecycle policy."},
			"egress_policy_json": schema.StringAttribute{
				Computed:    true,
				Sensitive:   true,
				Description: "JSON representation of egress policy. Marked sensitive because header values may contain secrets.",
			},
			"ports_json": schema.StringAttribute{
				Computed:    true,
				Description: "JSON representation of exposed ports.",
			},
		},
	}
}

func (d *sandboxDataSource) Configure(
	_ context.Context,
	req datasource.ConfigureRequest,
	resp *datasource.ConfigureResponse,
) {
	if req.ProviderData == nil {
		return
	}
	data, ok := req.ProviderData.(*ProviderData)
	if !ok {
		resp.Diagnostics.AddError("Unexpected provider data", fmt.Sprintf("Expected *ProviderData, got %T.", req.ProviderData))
		return
	}
	d.providerData = data
}

func (d *sandboxDataSource) Read(
	ctx context.Context,
	req datasource.ReadRequest,
	resp *datasource.ReadResponse,
) {
	var config sandboxDataSourceModel
	resp.Diagnostics.Append(req.Config.Get(ctx, &config)...)
	if resp.Diagnostics.HasError() {
		return
	}

	apiClient, endpoint, group, err := d.providerData.Client(
		stringValue(config.SandboxGroupID),
		stringValue(config.Location),
		stringValue(config.Endpoint),
	)
	if err != nil {
		resp.Diagnostics.AddError("Invalid Sandbox scope", err.Error())
		return
	}
	sandbox, err := apiClient.GetSandbox(ctx, stringValue(config.ID))
	if err != nil {
		resp.Diagnostics.AddError("Unable to read Sandbox", err.Error())
		return
	}
	flattenSandboxDataSource(ctx, &config, sandbox, endpoint, group, resp)
	if resp.Diagnostics.HasError() {
		return
	}
	resp.Diagnostics.Append(resp.State.Set(ctx, &config)...)
}

func flattenSandboxDataSource(
	ctx context.Context,
	model *sandboxDataSourceModel,
	sandbox client.Sandbox,
	endpoint ids.Endpoint,
	group ids.GroupID,
	resp *datasource.ReadResponse,
) {
	model.ID = types.StringValue(sandbox.ID)
	model.Name = nullableString(sandbox.Labels[labelTerraformName])
	model.State = nullableString(sandbox.State)
	model.Labels = mapFromStrings(sandbox.Labels)
	model.Hostname = nullableString(sandbox.Hostname)
	model.ManagementURL = nullableString(sandbox.ManagementURL)
	model.CreatedAt = nullableString(sandbox.CreatedAt)
	model.Region = nullableString(sandbox.Region)
	if sandbox.StateDetails != nil {
		model.StoppedReason = nullableString(sandbox.StateDetails.StoppedReason)
		model.StoppedAt = nullableString(sandbox.StateDetails.StoppedAt)
	}
	if sandbox.Connections != nil {
		value, diags := types.SetValueFrom(ctx, types.StringType, sandbox.Connections)
		resp.Diagnostics.Append(diags...)
		model.Connections = value
	}
	model.Entrypoint = listFromStrings(sandbox.Entrypoint)
	resourceURL, _ := ids.ResourceURL(endpoint, group, "sandboxes", sandbox.ID)
	model.ResourceURL = types.StringValue(resourceURL)

	setJSON := func(target *types.String, value any, name string) {
		encoded, err := json.Marshal(value)
		if err != nil {
			resp.Diagnostics.AddError("Unable to encode "+name, err.Error())
			return
		}
		*target = types.StringValue(string(encoded))
	}
	setJSON(&model.SourceJSON, struct {
		Preset     string                    `json:"preset,omitempty"`
		SourcesRef *client.SandboxSourcesRef `json:"sourcesRef,omitempty"`
	}{Preset: sandbox.PresetSandboxType, SourcesRef: sandbox.SourcesRef}, "source")
	setJSON(&model.ResourcesJSON, sandbox.Resources, "resources")
	setJSON(&model.LifecycleJSON, sandbox.Lifecycle, "lifecycle")
	setJSON(&model.EgressJSON, sandbox.EgressPolicy, "egress policy")
	setJSON(&model.PortsJSON, sandbox.Ports, "ports")
}
