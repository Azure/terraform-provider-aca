package provider

import (
	"context"
	"fmt"

	"github.com/hashicorp/terraform-plugin-framework/datasource"
	"github.com/hashicorp/terraform-plugin-framework/datasource/schema"
	"github.com/hashicorp/terraform-plugin-framework/types"

	"github.com/Azure/terraform-provider-aca/provider/internal/client"
	"github.com/Azure/terraform-provider-aca/provider/internal/ids"
)

var (
	_ datasource.DataSource              = &diskImageDataSource{}
	_ datasource.DataSourceWithConfigure = &diskImageDataSource{}
)

type diskImageDataSource struct {
	providerData *ProviderData
}

type diskImageDataSourceModel struct {
	SandboxGroupID types.String `tfsdk:"sandbox_group_id"`
	Location       types.String `tfsdk:"location"`
	Endpoint       types.String `tfsdk:"endpoint"`
	ID             types.String `tfsdk:"id"`
	Name           types.String `tfsdk:"name"`
	BaseImage      types.String `tfsdk:"base_image"`
	Entrypoint     types.List   `tfsdk:"entrypoint"`
	Command        types.List   `tfsdk:"command"`
	Labels         types.Map    `tfsdk:"labels"`
	ResourceURL    types.String `tfsdk:"resource_url"`
	Status         types.String `tfsdk:"status"`
	StatusMessage  types.String `tfsdk:"status_message"`
}

func NewDiskImageDataSource() datasource.DataSource {
	return &diskImageDataSource{}
}

func (d *diskImageDataSource) Metadata(
	_ context.Context,
	req datasource.MetadataRequest,
	resp *datasource.MetadataResponse,
) {
	resp.TypeName = req.ProviderTypeName + "_sandbox_disk_image"
}

func (d *diskImageDataSource) Schema(
	_ context.Context,
	_ datasource.SchemaRequest,
	resp *datasource.SchemaResponse,
) {
	resp.Schema = schema.Schema{
		MarkdownDescription: "Reads a private ACA Sandbox disk image by service-generated ID.",
		Attributes: map[string]schema.Attribute{
			"sandbox_group_id": schema.StringAttribute{
				Required:    true,
				Description: "ARM resource ID of the SandboxGroup.",
			},
			"location": schema.StringAttribute{
				Optional:    true,
				Description: "Canonical Azure location used to derive the data-plane endpoint.",
			},
			"endpoint": schema.StringAttribute{
				Optional:    true,
				Description: "Explicit Sandbox data-plane endpoint. Conflicts with location.",
			},
			"id": schema.StringAttribute{
				Required:    true,
				Description: "Service-generated disk image ID.",
			},
			"name": schema.StringAttribute{
				Computed:    true,
				Description: "Disk image name.",
			},
			"base_image": schema.StringAttribute{
				Computed:    true,
				Description: "Base container image reference.",
			},
			"entrypoint": schema.ListAttribute{
				Computed:    true,
				ElementType: types.StringType,
				Description: "Image entrypoint.",
			},
			"command": schema.ListAttribute{
				Computed:    true,
				ElementType: types.StringType,
				Description: "Image command.",
			},
			"labels": schema.MapAttribute{
				Computed:    true,
				ElementType: types.StringType,
				Description: "Disk image labels.",
			},
			"resource_url": schema.StringAttribute{
				Computed:    true,
				Description: "Canonical data-plane resource URL.",
			},
			"status": schema.StringAttribute{
				Computed:    true,
				Description: "Disk image status.",
			},
			"status_message": schema.StringAttribute{
				Computed:    true,
				Description: "Disk image status message.",
			},
		},
	}
}

func (d *diskImageDataSource) Configure(
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

func (d *diskImageDataSource) Read(
	ctx context.Context,
	req datasource.ReadRequest,
	resp *datasource.ReadResponse,
) {
	var config diskImageDataSourceModel
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

	image, err := apiClient.GetDiskImage(ctx, stringValue(config.ID))
	if err != nil {
		resp.Diagnostics.AddError("Unable to read disk image", err.Error())
		return
	}
	flattenDiskImageDataSource(&config, image, endpoint, group)
	resp.Diagnostics.Append(resp.State.Set(ctx, &config)...)
}

func flattenDiskImageDataSource(
	model *diskImageDataSourceModel,
	image client.DiskImage,
	endpoint ids.Endpoint,
	group ids.GroupID,
) {
	model.ID = types.StringValue(image.ID)
	if image.Name != "" {
		model.Name = types.StringValue(image.Name)
	} else if image.Labels[labelTerraformName] != "" {
		model.Name = types.StringValue(image.Labels[labelTerraformName])
	} else {
		model.Name = types.StringNull()
	}
	if image.Image != nil {
		model.BaseImage = types.StringValue(image.Image.Base)
		model.Entrypoint = listFromStrings(image.Image.Entrypoint)
		model.Command = listFromStrings(image.Image.Command)
	}
	model.Labels = mapFromStrings(image.Labels)
	resourceURL, _ := ids.ResourceURL(endpoint, group, "diskimages", image.ID)
	model.ResourceURL = types.StringValue(resourceURL)
	if image.Status != nil {
		model.Status = types.StringValue(image.Status.State)
		if image.Status.Message != "" {
			model.StatusMessage = types.StringValue(image.Status.Message)
		} else {
			model.StatusMessage = types.StringNull()
		}
	}
}
