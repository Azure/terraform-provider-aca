package provider

import (
	"context"
	"fmt"
	"net/url"
	"strings"

	"github.com/hashicorp/terraform-plugin-framework/datasource"
	"github.com/hashicorp/terraform-plugin-framework/datasource/schema"
	"github.com/hashicorp/terraform-plugin-framework/types"
)

var (
	_ datasource.DataSource              = &publicDiskImageDataSource{}
	_ datasource.DataSourceWithConfigure = &publicDiskImageDataSource{}
)

type publicDiskImageDataSource struct {
	providerData *ProviderData
}

type publicDiskImageDataSourceModel struct {
	SandboxGroupID types.String `tfsdk:"sandbox_group_id"`
	Location       types.String `tfsdk:"location"`
	Endpoint       types.String `tfsdk:"endpoint"`
	Name           types.String `tfsdk:"name"`
	ID             types.String `tfsdk:"id"`
	Description    types.String `tfsdk:"description"`
	Tags           types.Map    `tfsdk:"tags"`
	Status         types.String `tfsdk:"status"`
	StatusMessage  types.String `tfsdk:"status_message"`
	ResourceURL    types.String `tfsdk:"resource_url"`
}

func NewPublicDiskImageDataSource() datasource.DataSource {
	return &publicDiskImageDataSource{}
}

func (d *publicDiskImageDataSource) Metadata(
	_ context.Context,
	req datasource.MetadataRequest,
	resp *datasource.MetadataResponse,
) {
	resp.TypeName = req.ProviderTypeName + "_sandbox_public_disk_image"
}

func (d *publicDiskImageDataSource) Schema(
	_ context.Context,
	_ datasource.SchemaRequest,
	resp *datasource.SchemaResponse,
) {
	resp.Schema = schema.Schema{
		MarkdownDescription: "Reads a public disk image available to an ACA SandboxGroup.",
		Attributes: map[string]schema.Attribute{
			"sandbox_group_id": schema.StringAttribute{Required: true, Description: "ARM resource ID of the SandboxGroup."},
			"location":         schema.StringAttribute{Optional: true, Description: "Canonical Azure location."},
			"endpoint":         schema.StringAttribute{Optional: true, Description: "Explicit Sandbox data-plane endpoint."},
			"name":             schema.StringAttribute{Required: true, Description: "Public disk image name."},
			"id":               schema.StringAttribute{Computed: true, Description: "Public disk image ID."},
			"description":      schema.StringAttribute{Computed: true, Description: "Public disk image description."},
			"tags": schema.MapAttribute{
				Computed:    true,
				ElementType: types.StringType,
				Description: "Public disk image tags.",
			},
			"status":         schema.StringAttribute{Computed: true, Description: "Public disk image status."},
			"status_message": schema.StringAttribute{Computed: true, Description: "Public disk image status message."},
			"resource_url":   schema.StringAttribute{Computed: true, Description: "Canonical data-plane resource URL."},
		},
	}
}

func (d *publicDiskImageDataSource) Configure(
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

func (d *publicDiskImageDataSource) Read(
	ctx context.Context,
	req datasource.ReadRequest,
	resp *datasource.ReadResponse,
) {
	var config publicDiskImageDataSourceModel
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
	image, err := apiClient.GetPublicDiskImage(ctx, stringValue(config.Name))
	if err != nil {
		resp.Diagnostics.AddError("Unable to read public disk image", err.Error())
		return
	}

	config.ID = types.StringValue(image.ID)
	if image.Description != "" {
		config.Description = types.StringValue(image.Description)
	} else {
		config.Description = types.StringNull()
	}
	config.Tags = mapFromStrings(image.Tags)
	if image.Status != nil {
		config.Status = types.StringValue(image.Status.State)
		if image.Status.Message != "" {
			config.StatusMessage = types.StringValue(image.Status.Message)
		} else {
			config.StatusMessage = types.StringNull()
		}
	}
	config.ResourceURL = types.StringValue(
		strings.TrimSuffix(endpoint.URL.String(), "/") +
			group.DataPlanePath() + "/diskimages/public/" + url.PathEscape(image.Name),
	)
	resp.Diagnostics.Append(resp.State.Set(ctx, &config)...)
}
