package provider

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/hashicorp/terraform-plugin-framework-timeouts/resource/timeouts"
	"github.com/hashicorp/terraform-plugin-framework-validators/stringvalidator"
	"github.com/hashicorp/terraform-plugin-framework/diag"
	"github.com/hashicorp/terraform-plugin-framework/path"
	"github.com/hashicorp/terraform-plugin-framework/resource"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/listplanmodifier"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/mapplanmodifier"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/planmodifier"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/stringdefault"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/stringplanmodifier"
	"github.com/hashicorp/terraform-plugin-framework/schema/validator"
	"github.com/hashicorp/terraform-plugin-framework/types"

	"github.com/Azure/terraform-provider-aca/provider/internal/client"
	"github.com/Azure/terraform-provider-aca/provider/internal/ids"
)

const (
	labelManagedBy         = "managed_by"
	labelTerraformName     = "tf_aca_name"
	labelCreateFingerprint = "tf_aca_create_fingerprint"
)

var (
	_ resource.Resource                   = &diskImageResource{}
	_ resource.ResourceWithConfigure      = &diskImageResource{}
	_ resource.ResourceWithImportState    = &diskImageResource{}
	_ resource.ResourceWithValidateConfig = &diskImageResource{}
)

type diskImageResource struct {
	providerData *ProviderData
}

type diskImageModel struct {
	SandboxGroupID            types.String   `tfsdk:"sandbox_group_id"`
	Location                  types.String   `tfsdk:"location"`
	Endpoint                  types.String   `tfsdk:"endpoint"`
	Name                      types.String   `tfsdk:"name"`
	BaseImage                 types.String   `tfsdk:"base_image"`
	Entrypoint                types.List     `tfsdk:"entrypoint"`
	Command                   types.List     `tfsdk:"command"`
	Labels                    types.Map      `tfsdk:"labels"`
	ManagedIdentityResourceID types.String   `tfsdk:"managed_identity_resource_id"`
	ManagedIdentityClientID   types.String   `tfsdk:"managed_identity_client_id"`
	RegistryUsername          types.String   `tfsdk:"registry_username"`
	RegistryTokenWO           types.String   `tfsdk:"registry_token_wo"`
	DeletionPolicy            types.String   `tfsdk:"deletion_policy"`
	ID                        types.String   `tfsdk:"id"`
	ResourceURL               types.String   `tfsdk:"resource_url"`
	Status                    types.String   `tfsdk:"status"`
	StatusMessage             types.String   `tfsdk:"status_message"`
	Timeouts                  timeouts.Value `tfsdk:"timeouts"`
}

func NewDiskImageResource() resource.Resource {
	return &diskImageResource{}
}

func (r *diskImageResource) Metadata(
	_ context.Context,
	req resource.MetadataRequest,
	resp *resource.MetadataResponse,
) {
	resp.TypeName = req.ProviderTypeName + "_sandbox_disk_image"
}

func (r *diskImageResource) Schema(
	ctx context.Context,
	_ resource.SchemaRequest,
	resp *resource.SchemaResponse,
) {
	resp.Schema = schema.Schema{
		MarkdownDescription: "Imports a container image into an ACA SandboxGroup as a private disk image.",
		Attributes: map[string]schema.Attribute{
			"sandbox_group_id": requiredReplaceString("ARM resource ID of the SandboxGroup."),
			"location":         optionalReplaceString("Canonical Azure location used to derive the regional data-plane endpoint."),
			"endpoint":         optionalReplaceString("Explicit Sandbox data-plane endpoint. Conflicts with location."),
			"name":             requiredReplaceString("Logical name, unique among provider-managed disk images in the SandboxGroup."),
			"base_image":       requiredReplaceString("Container image reference used to build the disk. Digest pinning is recommended."),
			"entrypoint": schema.ListAttribute{
				Optional:      true,
				ElementType:   types.StringType,
				Description:   "Optional image entrypoint.",
				PlanModifiers: []planmodifier.List{listplanmodifier.RequiresReplace()},
			},
			"command": schema.ListAttribute{
				Optional:      true,
				ElementType:   types.StringType,
				Description:   "Optional image command.",
				PlanModifiers: []planmodifier.List{listplanmodifier.RequiresReplace()},
			},
			"labels": schema.MapAttribute{
				Optional:      true,
				ElementType:   types.StringType,
				Description:   "User labels. Provider-reserved labels cannot be overridden.",
				PlanModifiers: []planmodifier.Map{mapplanmodifier.RequiresReplace()},
			},
			"managed_identity_resource_id": optionalReplaceString(
				"Managed identity resource ID used by the service to pull the container image. Use system for the Sandbox Group system-assigned identity.",
			),
			"managed_identity_client_id": optionalReplaceString(
				"User-assigned managed identity client ID used by service rollouts that require managedIdentityClientId.",
			),
			"registry_username": optionalReplaceString(
				"Registry username. Use with registry_token_wo instead of managed identity.",
			),
			"registry_token_wo": schema.StringAttribute{
				Optional:    true,
				Sensitive:   true,
				WriteOnly:   true,
				Description: "Write-only registry token consumed only during disk creation.",
			},
			"deletion_policy": schema.StringAttribute{
				Optional:    true,
				Computed:    true,
				Description: "Delete removes the remote image; Retain only removes Terraform state.",
				Default:     stringdefault.StaticString("Delete"),
				Validators: []validator.String{
					stringvalidator.OneOf("Delete", "Retain"),
				},
			},
			"id": schema.StringAttribute{
				Computed:    true,
				Description: "Service-generated disk image ID.",
			},
			"resource_url": schema.StringAttribute{
				Computed:    true,
				Description: "Canonical data-plane resource URL used for import.",
			},
			"status": schema.StringAttribute{
				Computed:    true,
				Description: "Current disk image status.",
			},
			"status_message": schema.StringAttribute{
				Computed:    true,
				Description: "Current disk image status message.",
			},
			"timeouts": timeouts.Attributes(ctx, timeouts.Opts{
				Create: true,
				Delete: true,
			}),
		},
		Version: 1,
	}
}

func (r *diskImageResource) Configure(
	_ context.Context,
	req resource.ConfigureRequest,
	resp *resource.ConfigureResponse,
) {
	if req.ProviderData == nil {
		return
	}
	data, ok := req.ProviderData.(*ProviderData)
	if !ok {
		resp.Diagnostics.AddError(
			"Unexpected provider data",
			fmt.Sprintf("Expected *ProviderData, got %T.", req.ProviderData),
		)
		return
	}
	r.providerData = data
}

func (r *diskImageResource) ValidateConfig(
	ctx context.Context,
	req resource.ValidateConfigRequest,
	resp *resource.ValidateConfigResponse,
) {
	var config diskImageModel
	resp.Diagnostics.Append(req.Config.Get(ctx, &config)...)
	if resp.Diagnostics.HasError() {
		return
	}
	validateScope(config.Location, config.Endpoint, &resp.Diagnostics)

	managedIdentityResourceIDSet := config.ManagedIdentityResourceID.IsUnknown() ||
		(!config.ManagedIdentityResourceID.IsNull() && stringValue(config.ManagedIdentityResourceID) != "")
	managedIdentityClientIDSet := config.ManagedIdentityClientID.IsUnknown() ||
		(!config.ManagedIdentityClientID.IsNull() && stringValue(config.ManagedIdentityClientID) != "")
	usernameSet := config.RegistryUsername.IsUnknown() ||
		(!config.RegistryUsername.IsNull() && stringValue(config.RegistryUsername) != "")
	tokenSet := config.RegistryTokenWO.IsUnknown() || !config.RegistryTokenWO.IsNull()
	if managedIdentityResourceIDSet && managedIdentityClientIDSet {
		resp.Diagnostics.AddError(
			"Conflicting managed identity arguments",
			"managed_identity_resource_id and managed_identity_client_id cannot both be configured.",
		)
	}
	if (managedIdentityResourceIDSet || managedIdentityClientIDSet) && (usernameSet || tokenSet) {
		resp.Diagnostics.AddError(
			"Conflicting registry authentication",
			"Managed identity arguments cannot be combined with registry_username or registry_token_wo.",
		)
	}
	if usernameSet != tokenSet {
		resp.Diagnostics.AddError(
			"Incomplete registry authentication",
			"registry_username and registry_token_wo must be configured together.",
		)
	}

	labels, diags := mapValue(ctx, config.Labels)
	resp.Diagnostics.Append(diags...)
	for _, key := range []string{labelManagedBy, labelTerraformName, labelCreateFingerprint} {
		if _, exists := labels[key]; exists {
			resp.Diagnostics.AddAttributeError(
				path.Root("labels").AtMapKey(key),
				"Reserved label",
				fmt.Sprintf("The %q label is managed by the provider.", key),
			)
		}
	}
}

func (r *diskImageResource) Create(
	ctx context.Context,
	req resource.CreateRequest,
	resp *resource.CreateResponse,
) {
	var plan diskImageModel
	var config diskImageModel
	resp.Diagnostics.Append(req.Plan.Get(ctx, &plan)...)
	resp.Diagnostics.Append(req.Config.Get(ctx, &config)...)
	if resp.Diagnostics.HasError() {
		return
	}

	apiClient, endpoint, group, err := r.clientFor(plan)
	if err != nil {
		resp.Diagnostics.AddError("Invalid Sandbox scope", err.Error())
		return
	}

	createTimeout, diags := plan.Timeouts.Create(ctx, 15*time.Minute)
	resp.Diagnostics.Append(diags...)
	if resp.Diagnostics.HasError() {
		return
	}
	ctx, cancel := context.WithTimeout(ctx, createTimeout)
	defer cancel()
	unlock := r.providerData.LockCreate(
		group.String() + "|diskimages|" + stringValue(plan.Name),
	)
	defer unlock()

	userLabels, diags := mapValue(ctx, plan.Labels)
	resp.Diagnostics.Append(diags...)
	entrypoint, entrypointDiags := stringList(ctx, plan.Entrypoint)
	command, commandDiags := stringList(ctx, plan.Command)
	resp.Diagnostics.Append(entrypointDiags...)
	resp.Diagnostics.Append(commandDiags...)
	if resp.Diagnostics.HasError() {
		return
	}

	fingerprint, err := diskImageFingerprint(plan, userLabels, entrypoint, command)
	if err != nil {
		resp.Diagnostics.AddError("Unable to fingerprint disk image configuration", err.Error())
		return
	}
	labels := mergeReservedLabels(userLabels, stringValue(plan.Name), fingerprint)

	existing, err := apiClient.ListDiskImages(ctx)
	if err != nil {
		resp.Diagnostics.AddError("Unable to check existing disk images", err.Error())
		return
	}
	matches := filterDiskImagesByLabel(existing, labelTerraformName, stringValue(plan.Name))
	if len(matches) > 0 {
		resp.Diagnostics.AddError(
			"Disk image name already exists",
			existingImportMessage(matches, endpoint, group, "diskimages"),
		)
		return
	}

	createRequest := client.CreateDiskImageRequest{
		Image: client.DiskImageSpec{
			Base:       stringValue(plan.BaseImage),
			Entrypoint: entrypoint,
			Command:    command,
		},
		Labels:                    labels,
		ManagedIdentityResourceID: stringValue(plan.ManagedIdentityResourceID),
		ManagedIdentityClientID:   stringValue(plan.ManagedIdentityClientID),
	}
	if username := stringValue(plan.RegistryUsername); username != "" {
		createRequest.RegistryCredentials = &client.RegistryCredentials{
			Username: username,
			Token:    stringValue(config.RegistryTokenWO),
		}
	}

	image, createErr := apiClient.CreateDiskImage(ctx, createRequest)
	if createErr != nil && !client.IsAmbiguousCreateError(createErr) {
		resp.Diagnostics.AddError("Unable to create disk image", createErr.Error())
		return
	}
	if createErr != nil || image.ID == "" {
		recovered, recoveryErr := recoverDiskImage(
			ctx,
			apiClient,
			stringValue(plan.Name),
			fingerprint,
		)
		if recoveryErr != nil {
			if createErr != nil {
				resp.Diagnostics.AddError("Unable to create disk image", createErr.Error()+"; recovery failed: "+recoveryErr.Error())
			} else {
				resp.Diagnostics.AddError("Disk image response did not contain an ID", recoveryErr.Error())
			}
			return
		}
		image = recovered
		if createErr != nil {
			resp.Diagnostics.AddWarning(
				"Recovered disk image after an ambiguous create response",
				"The service created the disk image even though the create response failed. Terraform recovered it by reserved labels.",
			)
		}
	}

	applyDiskImageResponse(&plan, image, endpoint, group)
	resp.Diagnostics.Append(resp.State.Set(ctx, &plan)...)
	if resp.Diagnostics.HasError() {
		return
	}

	image, err = apiClient.WaitForDiskImage(ctx, image.ID, createTimeout)
	if err != nil {
		applyDiskImageResponse(&plan, image, endpoint, group)
		resp.Diagnostics.Append(resp.State.Set(ctx, &plan)...)
		resp.Diagnostics.AddError("Disk image did not become ready", err.Error())
		return
	}
	applyDiskImageResponse(&plan, image, endpoint, group)
	resp.Diagnostics.Append(resp.State.Set(ctx, &plan)...)
}

func (r *diskImageResource) Read(
	ctx context.Context,
	req resource.ReadRequest,
	resp *resource.ReadResponse,
) {
	var state diskImageModel
	resp.Diagnostics.Append(req.State.Get(ctx, &state)...)
	if resp.Diagnostics.HasError() {
		return
	}

	apiClient, endpoint, group, err := r.clientFor(state)
	if err != nil {
		resp.Diagnostics.AddError("Invalid Sandbox scope", err.Error())
		return
	}
	image, err := apiClient.GetDiskImage(ctx, stringValue(state.ID))
	if client.IsNotFound(err) {
		resp.State.RemoveResource(ctx)
		return
	}
	if err != nil {
		resp.Diagnostics.AddError("Unable to read disk image", err.Error())
		return
	}

	if state.Name.IsNull() || state.Name.IsUnknown() {
		state.Name = types.StringValue(image.Labels[labelTerraformName])
		if state.Name.ValueString() == "" && image.Name != "" {
			state.Name = types.StringValue(image.Name)
		}
	}
	if state.BaseImage.IsNull() && image.Image != nil {
		state.BaseImage = types.StringValue(image.Image.Base)
		state.Entrypoint = listFromStrings(image.Image.Entrypoint)
		state.Command = listFromStrings(image.Image.Command)
	}
	userLabels := removeReservedLabels(image.Labels)
	if len(userLabels) > 0 || !state.Labels.IsNull() {
		state.Labels = mapFromStrings(userLabels)
	}
	applyDiskImageResponse(&state, image, endpoint, group)
	resp.Diagnostics.Append(resp.State.Set(ctx, &state)...)
}

func (r *diskImageResource) Update(
	ctx context.Context,
	req resource.UpdateRequest,
	resp *resource.UpdateResponse,
) {
	var plan diskImageModel
	resp.Diagnostics.Append(req.Plan.Get(ctx, &plan)...)
	if resp.Diagnostics.HasError() {
		return
	}
	resp.Diagnostics.Append(resp.State.Set(ctx, &plan)...)
}

func (r *diskImageResource) Delete(
	ctx context.Context,
	req resource.DeleteRequest,
	resp *resource.DeleteResponse,
) {
	var state diskImageModel
	resp.Diagnostics.Append(req.State.Get(ctx, &state)...)
	if resp.Diagnostics.HasError() {
		return
	}
	if strings.EqualFold(stringValue(state.DeletionPolicy), "Retain") {
		resp.Diagnostics.AddWarning(
			"Disk image retained",
			"Terraform removed the disk image from state without deleting it. Re-import it with: "+
				stringValue(state.ResourceURL),
		)
		return
	}

	apiClient, _, _, err := r.clientFor(state)
	if err != nil {
		resp.Diagnostics.AddError("Invalid Sandbox scope", err.Error())
		return
	}
	deleteTimeout, diags := state.Timeouts.Delete(ctx, 5*time.Minute)
	resp.Diagnostics.Append(diags...)
	if resp.Diagnostics.HasError() {
		return
	}
	ctx, cancel := context.WithTimeout(ctx, deleteTimeout)
	defer cancel()

	err = apiClient.DeleteDiskImage(ctx, stringValue(state.ID))
	if err != nil && !client.IsNotFound(err) {
		resp.Diagnostics.AddError("Unable to delete disk image", err.Error())
		return
	}
	if err := apiClient.WaitForDiskImageDeleted(ctx, stringValue(state.ID), deleteTimeout); err != nil {
		resp.Diagnostics.AddError("Disk image deletion did not complete", err.Error())
	}
}

func (r *diskImageResource) ImportState(
	ctx context.Context,
	req resource.ImportStateRequest,
	resp *resource.ImportStateResponse,
) {
	endpoint, group, id, err := ids.ParseResourceURL(req.ID, "diskimages")
	if err != nil {
		resp.Diagnostics.AddError("Invalid disk image import ID", err.Error())
		return
	}
	resp.Diagnostics.Append(resp.State.SetAttribute(ctx, path.Root("sandbox_group_id"), group.String())...)
	resp.Diagnostics.Append(resp.State.SetAttribute(ctx, path.Root("id"), id)...)
	resp.Diagnostics.Append(resp.State.SetAttribute(ctx, path.Root("resource_url"), req.ID)...)
	resp.Diagnostics.Append(resp.State.SetAttribute(ctx, path.Root("deletion_policy"), "Delete")...)
	if endpoint.Standard {
		resp.Diagnostics.Append(resp.State.SetAttribute(ctx, path.Root("location"), endpoint.Location)...)
	} else {
		resp.Diagnostics.Append(resp.State.SetAttribute(ctx, path.Root("endpoint"), endpoint.URL.String())...)
	}
}

func (r *diskImageResource) clientFor(model diskImageModel) (*client.Client, ids.Endpoint, ids.GroupID, error) {
	if r.providerData == nil {
		return nil, ids.Endpoint{}, ids.GroupID{}, fmt.Errorf("provider is not configured")
	}
	return r.providerData.Client(
		stringValue(model.SandboxGroupID),
		stringValue(model.Location),
		stringValue(model.Endpoint),
	)
}

func requiredReplaceString(description string) schema.StringAttribute {
	return schema.StringAttribute{
		Required:      true,
		Description:   description,
		PlanModifiers: []planmodifier.String{stringplanmodifier.RequiresReplace()},
	}
}

func optionalReplaceString(description string) schema.StringAttribute {
	return schema.StringAttribute{
		Optional:      true,
		Description:   description,
		PlanModifiers: []planmodifier.String{stringplanmodifier.RequiresReplace()},
	}
}

func validateScope(location, endpoint types.String, diagnostics *diag.Diagnostics) {
	if location.IsUnknown() || endpoint.IsUnknown() {
		return
	}
	locationSet := !location.IsNull() && location.ValueString() != ""
	endpointSet := !endpoint.IsNull() && endpoint.ValueString() != ""
	if locationSet == endpointSet {
		diagnostics.AddError(
			"Invalid Sandbox endpoint configuration",
			"Exactly one of location or endpoint must be configured.",
		)
	}
}

func mapValue(ctx context.Context, value types.Map) (map[string]string, diag.Diagnostics) {
	result := map[string]string{}
	if value.IsNull() || value.IsUnknown() {
		return result, nil
	}
	diags := value.ElementsAs(ctx, &result, false)
	return result, diags
}

func stringList(ctx context.Context, value types.List) ([]string, diag.Diagnostics) {
	var result []string
	if value.IsNull() || value.IsUnknown() {
		return result, nil
	}
	diags := value.ElementsAs(ctx, &result, false)
	return result, diags
}

func listFromStrings(values []string) types.List {
	if values == nil {
		return types.ListNull(types.StringType)
	}
	result, _ := types.ListValueFrom(context.Background(), types.StringType, values)
	return result
}

func mapFromStrings(values map[string]string) types.Map {
	if values == nil {
		return types.MapNull(types.StringType)
	}
	result, _ := types.MapValueFrom(context.Background(), types.StringType, values)
	return result
}

func mergeReservedLabels(user map[string]string, name, fingerprint string) map[string]string {
	result := make(map[string]string, len(user)+3)
	for key, value := range user {
		result[key] = value
	}
	result[labelManagedBy] = "terraform-provider-aca"
	result[labelTerraformName] = name
	result[labelCreateFingerprint] = fingerprint
	return result
}

func removeReservedLabels(labels map[string]string) map[string]string {
	result := make(map[string]string, len(labels))
	for key, value := range labels {
		switch key {
		case labelManagedBy, labelTerraformName, labelCreateFingerprint:
			continue
		default:
			result[key] = value
		}
	}
	return result
}

func diskImageFingerprint(
	model diskImageModel,
	labels map[string]string,
	entrypoint []string,
	command []string,
) (string, error) {
	payload := struct {
		GroupID                   string            `json:"group_id"`
		Name                      string            `json:"name"`
		BaseImage                 string            `json:"base_image"`
		Entrypoint                []string          `json:"entrypoint,omitempty"`
		Command                   []string          `json:"command,omitempty"`
		Labels                    map[string]string `json:"labels,omitempty"`
		ManagedIdentityResourceID string            `json:"managed_identity_resource_id,omitempty"`
		ManagedIdentityClientID   string            `json:"managed_identity_client_id,omitempty"`
		RegistryUsername          string            `json:"registry_username,omitempty"`
	}{
		GroupID:                   stringValue(model.SandboxGroupID),
		Name:                      stringValue(model.Name),
		BaseImage:                 stringValue(model.BaseImage),
		Entrypoint:                entrypoint,
		Command:                   command,
		Labels:                    labels,
		ManagedIdentityResourceID: stringValue(model.ManagedIdentityResourceID),
		ManagedIdentityClientID:   stringValue(model.ManagedIdentityClientID),
		RegistryUsername:          stringValue(model.RegistryUsername),
	}
	encoded, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}
	hash := sha256.Sum256(encoded)
	return hex.EncodeToString(hash[:16]), nil
}

func filterDiskImagesByLabel(images []client.DiskImage, key, value string) []client.DiskImage {
	var result []client.DiskImage
	for _, image := range images {
		if image.Labels[key] == value {
			result = append(result, image)
		}
	}
	return result
}

func recoverDiskImage(
	ctx context.Context,
	apiClient *client.Client,
	name string,
	fingerprint string,
) (client.DiskImage, error) {
	deadline := recoveryDeadline(ctx)
	for {
		images, err := apiClient.ListDiskImages(ctx)
		if err != nil {
			return client.DiskImage{}, err
		}
		var matches []client.DiskImage
		for _, image := range images {
			if image.Labels[labelTerraformName] == name &&
				image.Labels[labelCreateFingerprint] == fingerprint {
				matches = append(matches, image)
			}
		}
		switch len(matches) {
		case 1:
			return matches[0], nil
		case 0:
			if time.Now().Before(deadline) {
				if err := waitRecoveryPoll(ctx); err != nil {
					return client.DiskImage{}, err
				}
				continue
			}
		default:
			return client.DiskImage{}, fmt.Errorf(
				"found %d disk images with the same recovery labels; import the intended image explicitly",
				len(matches),
			)
		}
		return client.DiskImage{}, fmt.Errorf("no disk image appeared with the recovery labels")
	}
}

func recoveryDeadline(ctx context.Context) time.Time {
	deadline := time.Now().Add(30 * time.Second)
	if contextDeadline, ok := ctx.Deadline(); ok && contextDeadline.Before(deadline) {
		return contextDeadline
	}
	return deadline
}

func waitRecoveryPoll(ctx context.Context) error {
	timer := time.NewTimer(2 * time.Second)
	defer timer.Stop()
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-timer.C:
		return nil
	}
}

func existingImportMessage(
	images []client.DiskImage,
	endpoint ids.Endpoint,
	group ids.GroupID,
	collection string,
) string {
	var values []string
	for _, image := range images {
		resourceURL, _ := ids.ResourceURL(endpoint, group, collection, image.ID)
		values = append(values, image.ID+" ("+resourceURL+")")
	}
	return "A provider-managed disk image with this name already exists. Import exactly one instead of creating another: " +
		strings.Join(values, ", ")
}

func applyDiskImageResponse(
	model *diskImageModel,
	image client.DiskImage,
	endpoint ids.Endpoint,
	group ids.GroupID,
) {
	if image.ID != "" {
		model.ID = types.StringValue(image.ID)
		resourceURL, err := ids.ResourceURL(endpoint, group, "diskimages", image.ID)
		if err == nil {
			model.ResourceURL = types.StringValue(resourceURL)
		}
	}
	if image.Status != nil {
		model.Status = types.StringValue(image.Status.State)
		if image.Status.Message == "" {
			model.StatusMessage = types.StringNull()
		} else {
			model.StatusMessage = types.StringValue(image.Status.Message)
		}
	}
}
