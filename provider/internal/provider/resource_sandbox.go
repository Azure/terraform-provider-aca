package provider

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/hashicorp/terraform-plugin-framework-timeouts/resource/timeouts"
	"github.com/hashicorp/terraform-plugin-framework/diag"
	"github.com/hashicorp/terraform-plugin-framework/path"
	"github.com/hashicorp/terraform-plugin-framework/resource"
	"github.com/hashicorp/terraform-plugin-framework/types"

	"github.com/Azure/terraform-provider-aca/provider/internal/client"
	"github.com/Azure/terraform-provider-aca/provider/internal/ids"
)

var (
	_ resource.Resource                   = &sandboxResource{}
	_ resource.ResourceWithConfigure      = &sandboxResource{}
	_ resource.ResourceWithImportState    = &sandboxResource{}
	_ resource.ResourceWithValidateConfig = &sandboxResource{}
)

type sandboxResource struct {
	providerData *ProviderData
}

type sandboxModel struct {
	SandboxGroupID             types.String   `tfsdk:"sandbox_group_id"`
	Location                   types.String   `tfsdk:"location"`
	Endpoint                   types.String   `tfsdk:"endpoint"`
	Name                       types.String   `tfsdk:"name"`
	Source                     types.Object   `tfsdk:"source"`
	Resources                  types.Object   `tfsdk:"resources"`
	Labels                     types.Map      `tfsdk:"labels"`
	Environment                types.Map      `tfsdk:"environment"`
	EnvironmentWO              types.Map      `tfsdk:"environment_wo"`
	EnvironmentWOVersion       types.Int64    `tfsdk:"environment_wo_version"`
	Connections                types.Set      `tfsdk:"connections"`
	AutoSuspend                types.Object   `tfsdk:"auto_suspend"`
	EgressPolicy               types.Object   `tfsdk:"egress_policy"`
	Ports                      types.Map      `tfsdk:"ports"`
	Entrypoint                 types.List     `tfsdk:"entrypoint"`
	Command                    types.List     `tfsdk:"command"`
	SkipEgressProxy            types.Bool     `tfsdk:"skip_egress_proxy"`
	CustomerVNetConnectionName types.String   `tfsdk:"customer_vnet_connection_name"`
	VMMType                    types.String   `tfsdk:"vmm_type"`
	AllowResumeForUpdates      types.Bool     `tfsdk:"allow_resume_for_updates"`
	DeletionPolicy             types.String   `tfsdk:"deletion_policy"`
	ID                         types.String   `tfsdk:"id"`
	ResourceURL                types.String   `tfsdk:"resource_url"`
	State                      types.String   `tfsdk:"state"`
	StoppedReason              types.String   `tfsdk:"stopped_reason"`
	StoppedAt                  types.String   `tfsdk:"stopped_at"`
	Hostname                   types.String   `tfsdk:"hostname"`
	ManagementURL              types.String   `tfsdk:"management_url"`
	CreatedAt                  types.String   `tfsdk:"created_at"`
	Region                     types.String   `tfsdk:"region"`
	Timeouts                   timeouts.Value `tfsdk:"timeouts"`
}

func NewSandboxResource() resource.Resource {
	return &sandboxResource{}
}

func (r *sandboxResource) Metadata(
	_ context.Context,
	req resource.MetadataRequest,
	resp *resource.MetadataResponse,
) {
	resp.TypeName = req.ProviderTypeName + "_sandbox"
}

func (r *sandboxResource) Schema(
	ctx context.Context,
	_ resource.SchemaRequest,
	resp *resource.SchemaResponse,
) {
	resp.Schema = sandboxResourceSchema(ctx)
}

func (r *sandboxResource) Configure(
	_ context.Context,
	req resource.ConfigureRequest,
	resp *resource.ConfigureResponse,
) {
	if req.ProviderData == nil {
		return
	}
	data, ok := req.ProviderData.(*ProviderData)
	if !ok {
		resp.Diagnostics.AddError("Unexpected provider data", fmt.Sprintf("Expected *ProviderData, got %T.", req.ProviderData))
		return
	}
	r.providerData = data
}

func (r *sandboxResource) ValidateConfig(
	ctx context.Context,
	req resource.ValidateConfigRequest,
	resp *resource.ValidateConfigResponse,
) {
	var config sandboxModel
	resp.Diagnostics.Append(req.Config.Get(ctx, &config)...)
	if resp.Diagnostics.HasError() {
		return
	}

	validateScope(config.Location, config.Endpoint, &resp.Diagnostics)
	source, sourceDiags := sourceFromObject(ctx, config.Source)
	resp.Diagnostics.Append(sourceDiags...)
	if !sourceHasUnknown(source) {
		kind, _, err := oneSource(source)
		if err != nil {
			resp.Diagnostics.AddAttributeError(path.Root("source"), "Invalid Sandbox source", err.Error())
		}
		if kind == "preset" && !config.Resources.IsNull() {
			resp.Diagnostics.AddAttributeError(
				path.Root("resources"),
				"Resources are not supported with a preset",
				"The service controls resource allocation for preset Sandboxes.",
			)
		}
		if kind != "" && kind != "preset" && config.Resources.IsNull() {
			resp.Diagnostics.AddAttributeError(
				path.Root("resources"),
				"Resources are required",
				"resources must be configured for public and private disk image sources.",
			)
		}
	}

	labels, labelDiags := mapValue(ctx, config.Labels)
	resp.Diagnostics.Append(labelDiags...)
	for _, key := range []string{labelManagedBy, labelTerraformName, labelCreateFingerprint} {
		if _, exists := labels[key]; exists {
			resp.Diagnostics.AddAttributeError(
				path.Root("labels").AtMapKey(key),
				"Reserved label",
				fmt.Sprintf("The %q label is managed by the provider.", key),
			)
		}
	}

	environment, environmentDiags := mapValue(ctx, config.Environment)
	environmentWO, environmentWODiags := mapValue(ctx, config.EnvironmentWO)
	resp.Diagnostics.Append(environmentDiags...)
	resp.Diagnostics.Append(environmentWODiags...)
	for key := range environmentWO {
		if _, exists := environment[key]; exists {
			resp.Diagnostics.AddAttributeError(
				path.Root("environment_wo").AtMapKey(key),
				"Duplicate environment variable",
				fmt.Sprintf("%q is also configured in environment.", key),
			)
		}
	}
	if len(environmentWO) > 0 && config.EnvironmentWOVersion.IsNull() {
		resp.Diagnostics.AddAttributeError(
			path.Root("environment_wo_version"),
			"Missing environment_wo_version",
			"environment_wo_version is required when environment_wo is configured.",
		)
	}
	resp.Diagnostics.Append(validatePorts(ctx, config.Ports)...)
}

func sourceHasUnknown(source sandboxSourceModel) bool {
	return source.PublicDiskImage.IsUnknown() ||
		source.PrivateDiskImageID.IsUnknown() ||
		source.Preset.IsUnknown()
}

func (r *sandboxResource) Create(
	ctx context.Context,
	req resource.CreateRequest,
	resp *resource.CreateResponse,
) {
	var plan sandboxModel
	var config sandboxModel
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
	createTimeout, diags := plan.Timeouts.Create(ctx, 5*time.Minute)
	resp.Diagnostics.Append(diags...)
	if resp.Diagnostics.HasError() {
		return
	}
	ctx, cancel := context.WithTimeout(ctx, createTimeout)
	defer cancel()
	unlock := r.providerData.LockCreate(
		group.String() + "|sandboxes|" + stringValue(config.Name),
	)
	defer unlock()

	request, fingerprint, ports, diags := sandboxCreateRequest(ctx, config)
	resp.Diagnostics.Append(diags...)
	if resp.Diagnostics.HasError() {
		return
	}

	existing, err := apiClient.ListSandboxes(ctx, map[string]string{
		labelTerraformName: stringValue(config.Name),
	})
	if err != nil {
		resp.Diagnostics.AddError("Unable to check existing Sandboxes", err.Error())
		return
	}
	existing = filterSandboxesByLabel(existing, labelTerraformName, stringValue(config.Name))
	if len(existing) > 0 {
		resp.Diagnostics.AddError(
			"Sandbox name already exists",
			sandboxImportMessage(existing, endpoint, group),
		)
		return
	}

	sandbox, createErr := apiClient.CreateSandbox(ctx, request)
	if createErr != nil && !client.IsAmbiguousCreateError(createErr) {
		resp.Diagnostics.AddError("Unable to create Sandbox", createErr.Error())
		return
	}
	if createErr != nil || sandbox.ID == "" {
		recovered, recoveryErr := recoverSandbox(
			ctx,
			apiClient,
			stringValue(config.Name),
			fingerprint,
		)
		if recoveryErr != nil {
			if createErr != nil {
				resp.Diagnostics.AddError("Unable to create Sandbox", createErr.Error()+"; recovery failed: "+recoveryErr.Error())
			} else {
				resp.Diagnostics.AddError("Sandbox response did not contain an ID", recoveryErr.Error())
			}
			return
		}
		sandbox = recovered
		if createErr != nil {
			resp.Diagnostics.AddWarning(
				"Recovered Sandbox after an ambiguous create response",
				"The service created the Sandbox even though the create response failed. Terraform recovered it by reserved labels.",
			)
		}
	}

	if len(sandbox.Ports) == 0 && len(ports) > 0 {
		plan.Ports, diags = portMapFromRequests(ctx, ports)
		resp.Diagnostics.Append(diags...)
	}
	applySandboxResponse(ctx, &plan, sandbox, endpoint, group, false, &resp.Diagnostics)
	resp.Diagnostics.Append(resp.State.Set(ctx, &plan)...)
	if resp.Diagnostics.HasError() {
		return
	}

	sandbox, err = apiClient.WaitForSandbox(ctx, sandbox.ID, createTimeout)
	if err != nil {
		applySandboxResponse(ctx, &plan, sandbox, endpoint, group, false, &resp.Diagnostics)
		resp.Diagnostics.Append(resp.State.Set(ctx, &plan)...)
		resp.Diagnostics.AddError("Sandbox did not become running", err.Error())
		return
	}
	applySandboxResponse(ctx, &plan, sandbox, endpoint, group, false, &resp.Diagnostics)
	resp.Diagnostics.Append(resp.State.Set(ctx, &plan)...)
}

func (r *sandboxResource) Read(
	ctx context.Context,
	req resource.ReadRequest,
	resp *resource.ReadResponse,
) {
	var state sandboxModel
	resp.Diagnostics.Append(req.State.Get(ctx, &state)...)
	if resp.Diagnostics.HasError() {
		return
	}
	apiClient, endpoint, group, err := r.clientFor(state)
	if err != nil {
		resp.Diagnostics.AddError("Invalid Sandbox scope", err.Error())
		return
	}
	sandbox, err := apiClient.GetSandbox(ctx, stringValue(state.ID))
	if client.IsNotFound(err) {
		resp.State.RemoveResource(ctx)
		return
	}
	if err != nil {
		resp.Diagnostics.AddError("Unable to read Sandbox", err.Error())
		return
	}

	imported := state.Name.IsNull() || state.Name.IsUnknown()
	applySandboxResponse(ctx, &state, sandbox, endpoint, group, imported, &resp.Diagnostics)
	resp.Diagnostics.Append(resp.State.Set(ctx, &state)...)
}

func (r *sandboxResource) Update(
	ctx context.Context,
	req resource.UpdateRequest,
	resp *resource.UpdateResponse,
) {
	var plan sandboxModel
	var state sandboxModel
	resp.Diagnostics.Append(req.Plan.Get(ctx, &plan)...)
	resp.Diagnostics.Append(req.State.Get(ctx, &state)...)
	if resp.Diagnostics.HasError() {
		return
	}
	apiClient, endpoint, group, err := r.clientFor(plan)
	if err != nil {
		resp.Diagnostics.AddError("Invalid Sandbox scope", err.Error())
		return
	}
	updateTimeout, diags := plan.Timeouts.Update(ctx, 5*time.Minute)
	resp.Diagnostics.Append(diags...)
	if resp.Diagnostics.HasError() {
		return
	}
	ctx, cancel := context.WithTimeout(ctx, updateTimeout)
	defer cancel()

	if !plan.AutoSuspend.Equal(state.AutoSuspend) {
		policy, policyDiags := lifecycleFromObject(ctx, plan.AutoSuspend)
		resp.Diagnostics.Append(policyDiags...)
		if !resp.Diagnostics.HasError() {
			_, err = apiClient.SetLifecycle(ctx, stringValue(state.ID), policy)
			if err != nil {
				resp.Diagnostics.AddError("Unable to update Sandbox lifecycle", err.Error())
				return
			}
		}
	}
	if !plan.EgressPolicy.Equal(state.EgressPolicy) {
		policy, policyDiags := egressPolicyFromObject(ctx, plan.EgressPolicy)
		resp.Diagnostics.Append(policyDiags...)
		if resp.Diagnostics.HasError() {
			return
		}
		if policy == nil {
			policy = &client.EgressPolicy{DefaultAction: "Allow"}
		}
		_, err = apiClient.SetEgressPolicy(ctx, stringValue(state.ID), *policy)
		if err != nil {
			if !r.tryResumeForUpdate(ctx, apiClient, state, plan, err, updateTimeout, &resp.Diagnostics) {
				return
			}
			if _, err = apiClient.SetEgressPolicy(ctx, stringValue(state.ID), *policy); err != nil {
				resp.Diagnostics.AddError("Unable to update Sandbox egress policy after resume", err.Error())
				return
			}
		}
	}
	if !plan.Ports.Equal(state.Ports) {
		ports, portDiags := portsFromMap(ctx, plan.Ports)
		resp.Diagnostics.Append(portDiags...)
		if resp.Diagnostics.HasError() {
			return
		}
		updated, updateErr := apiClient.UpdatePorts(ctx, stringValue(state.ID), orderedPorts(ports))
		if updateErr != nil {
			if !r.tryResumeForUpdate(ctx, apiClient, state, plan, updateErr, updateTimeout, &resp.Diagnostics) {
				return
			}
			updated, updateErr = apiClient.UpdatePorts(ctx, stringValue(state.ID), orderedPorts(ports))
		}
		if updateErr != nil {
			resp.Diagnostics.AddError("Unable to update Sandbox ports", updateErr.Error())
			return
		}
		plan.Ports, portDiags = portMapFromAPI(ctx, plan.Ports, updated)
		resp.Diagnostics.Append(portDiags...)
	}

	sandbox, err := apiClient.GetSandbox(ctx, stringValue(state.ID))
	if err != nil {
		resp.Diagnostics.AddError("Unable to refresh Sandbox after update", err.Error())
		return
	}
	applySandboxResponse(ctx, &plan, sandbox, endpoint, group, false, &resp.Diagnostics)
	resp.Diagnostics.Append(resp.State.Set(ctx, &plan)...)
}

func (r *sandboxResource) Delete(
	ctx context.Context,
	req resource.DeleteRequest,
	resp *resource.DeleteResponse,
) {
	var state sandboxModel
	resp.Diagnostics.Append(req.State.Get(ctx, &state)...)
	if resp.Diagnostics.HasError() {
		return
	}
	if strings.EqualFold(stringValue(state.DeletionPolicy), "Retain") {
		resp.Diagnostics.AddWarning(
			"Sandbox retained",
			"Terraform removed the Sandbox from state without deleting it. Re-import it with: "+
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

	err = apiClient.DeleteSandbox(ctx, stringValue(state.ID))
	if err != nil && !client.IsNotFound(err) {
		resp.Diagnostics.AddError("Unable to delete Sandbox", err.Error())
		return
	}
	if err := apiClient.WaitForSandboxDeleted(ctx, stringValue(state.ID), deleteTimeout); err != nil {
		resp.Diagnostics.AddError("Sandbox deletion did not complete", err.Error())
	}
}

func (r *sandboxResource) ImportState(
	ctx context.Context,
	req resource.ImportStateRequest,
	resp *resource.ImportStateResponse,
) {
	endpoint, group, id, err := ids.ParseResourceURL(req.ID, "sandboxes")
	if err != nil {
		resp.Diagnostics.AddError("Invalid Sandbox import ID", err.Error())
		return
	}
	resp.Diagnostics.Append(resp.State.SetAttribute(ctx, path.Root("sandbox_group_id"), group.String())...)
	resp.Diagnostics.Append(resp.State.SetAttribute(ctx, path.Root("id"), id)...)
	resp.Diagnostics.Append(resp.State.SetAttribute(ctx, path.Root("resource_url"), req.ID)...)
	resp.Diagnostics.Append(resp.State.SetAttribute(ctx, path.Root("deletion_policy"), "Delete")...)
	resp.Diagnostics.Append(resp.State.SetAttribute(ctx, path.Root("allow_resume_for_updates"), false)...)
	if endpoint.Standard {
		resp.Diagnostics.Append(resp.State.SetAttribute(ctx, path.Root("location"), endpoint.Location)...)
	} else {
		resp.Diagnostics.Append(resp.State.SetAttribute(ctx, path.Root("endpoint"), endpoint.URL.String())...)
	}
}

func (r *sandboxResource) clientFor(model sandboxModel) (*client.Client, ids.Endpoint, ids.GroupID, error) {
	if r.providerData == nil {
		return nil, ids.Endpoint{}, ids.GroupID{}, fmt.Errorf("provider is not configured")
	}
	return r.providerData.Client(
		stringValue(model.SandboxGroupID),
		stringValue(model.Location),
		stringValue(model.Endpoint),
	)
}

func (r *sandboxResource) tryResumeForUpdate(
	ctx context.Context,
	apiClient *client.Client,
	state sandboxModel,
	plan sandboxModel,
	updateErr error,
	timeout time.Duration,
	diagnostics *diag.Diagnostics,
) bool {
	if !client.IsConflict(updateErr) {
		diagnostics.AddError("Unable to update Sandbox", updateErr.Error())
		return false
	}
	if !boolValue(plan.AllowResumeForUpdates) {
		diagnostics.AddError(
			"Sandbox update requires running state",
			updateErr.Error()+". Set allow_resume_for_updates = true to permit Terraform to resume it.",
		)
		return false
	}
	if err := apiClient.ResumeSandbox(ctx, stringValue(state.ID)); err != nil && !client.IsConflict(err) {
		diagnostics.AddError("Unable to resume Sandbox for update", err.Error())
		return false
	}
	if err := apiClient.WaitForSandboxRunning(ctx, stringValue(state.ID), timeout); err != nil {
		diagnostics.AddError("Sandbox did not resume for update", err.Error())
		return false
	}
	diagnostics.AddWarning(
		"Sandbox resumed for update",
		"Terraform resumed the Sandbox because the data-plane update required Running state. It will remain running.",
	)
	return true
}

func sandboxCreateRequest(
	ctx context.Context,
	config sandboxModel,
) (client.CreateSandboxRequest, string, map[string]client.PortRequest, diag.Diagnostics) {
	var diags diag.Diagnostics
	source, sourceDiags := sourceFromObject(ctx, config.Source)
	resources, resourceDiags := resourcesFromObject(ctx, config.Resources)
	labels, labelDiags := mapValue(ctx, config.Labels)
	environment, environmentDiags := mapValue(ctx, config.Environment)
	environmentWO, environmentWODiags := mapValue(ctx, config.EnvironmentWO)
	connections, connectionDiags := stringSet(ctx, config.Connections)
	entrypoint, entrypointDiags := stringList(ctx, config.Entrypoint)
	command, commandDiags := stringList(ctx, config.Command)
	ports, portDiags := portsFromMap(ctx, config.Ports)
	egress, egressDiags := egressPolicyFromObject(ctx, config.EgressPolicy)
	diags.Append(
		sourceDiags...,
	)
	diags.Append(resourceDiags...)
	diags.Append(labelDiags...)
	diags.Append(environmentDiags...)
	diags.Append(environmentWODiags...)
	diags.Append(connectionDiags...)
	diags.Append(entrypointDiags...)
	diags.Append(commandDiags...)
	diags.Append(portDiags...)
	diags.Append(egressDiags...)
	if diags.HasError() {
		return client.CreateSandboxRequest{}, "", nil, diags
	}

	for key, value := range environmentWO {
		environment[key] = value
	}
	kind, sourceValue, err := oneSource(source)
	if err != nil {
		diags.AddError("Invalid Sandbox source", err.Error())
		return client.CreateSandboxRequest{}, "", nil, diags
	}

	fingerprint, err := sandboxFingerprint(
		config,
		source,
		resources,
		labels,
		environmentWO,
		connections,
		entrypoint,
		command,
	)
	if err != nil {
		diags.AddError("Unable to fingerprint Sandbox configuration", err.Error())
		return client.CreateSandboxRequest{}, "", nil, diags
	}

	request := client.CreateSandboxRequest{
		Labels:                     mergeReservedLabels(labels, stringValue(config.Name), fingerprint),
		Environment:                environment,
		Connections:                connections,
		EgressPolicy:               egress,
		Ports:                      orderedPorts(ports),
		Entrypoint:                 entrypoint,
		Command:                    command,
		CustomerVNetConnectionName: stringValue(config.CustomerVNetConnectionName),
		VMMType:                    stringValue(config.VMMType),
	}
	if !config.SkipEgressProxy.IsNull() && !config.SkipEgressProxy.IsUnknown() {
		value := config.SkipEgressProxy.ValueBool()
		request.SkipEgressProxy = &value
	}

	switch kind {
	case "preset":
		request.PresetSandboxType = sourceValue
	case "private":
		request.SourcesRef = &client.SandboxSourcesRef{
			DiskImage: &client.DiskImageRef{ID: sourceValue},
		}
		request.Resources = &client.SandboxResources{
			CPU:    stringValue(resources.CPU),
			Memory: stringValue(resources.Memory),
			Disk:   stringValue(resources.Disk),
		}
	case "public":
		isPublic := true
		request.SourcesRef = &client.SandboxSourcesRef{
			DiskImage: &client.DiskImageRef{Name: sourceValue, IsPublic: &isPublic},
		}
		request.Resources = &client.SandboxResources{
			CPU:    stringValue(resources.CPU),
			Memory: stringValue(resources.Memory),
			Disk:   stringValue(resources.Disk),
		}
	}

	lifecycle, lifecycleDiags := lifecycleFromObject(ctx, config.AutoSuspend)
	diags.Append(lifecycleDiags...)
	request.Lifecycle = &lifecycle
	return request, fingerprint, ports, diags
}

func lifecycleFromObject(ctx context.Context, value types.Object) (client.LifecyclePolicy, diag.Diagnostics) {
	if value.IsNull() || value.IsUnknown() {
		return client.LifecyclePolicy{
			AutoSuspend: &client.AutoSuspendPolicy{
				Enabled:  true,
				Interval: 300,
				Mode:     "Memory",
			},
		}, nil
	}
	model, diags := autoSuspendFromObject(ctx, value)
	interval := int64(300)
	if !model.IntervalSeconds.IsNull() && !model.IntervalSeconds.IsUnknown() {
		interval = model.IntervalSeconds.ValueInt64()
	}
	mode := stringValue(model.Mode)
	if mode == "" {
		mode = "Memory"
	}
	return client.LifecyclePolicy{
		AutoSuspend: &client.AutoSuspendPolicy{
			Enabled:  boolValue(model.Enabled),
			Interval: interval,
			Mode:     mode,
		},
	}, diags
}

func sandboxFingerprint(
	config sandboxModel,
	source sandboxSourceModel,
	resources sandboxResourcesModel,
	labels map[string]string,
	environmentWO map[string]string,
	connections []string,
	entrypoint []string,
	command []string,
) (string, error) {
	woKeys := make([]string, 0, len(environmentWO))
	for key := range environmentWO {
		woKeys = append(woKeys, key)
	}
	sort.Strings(woKeys)
	normalEnvironment, _ := mapValue(context.Background(), config.Environment)
	payload := struct {
		GroupID string `json:"group_id"`
		Name    string `json:"name"`
		Source  struct {
			PublicDiskImage    string `json:"public_disk_image,omitempty"`
			PrivateDiskImageID string `json:"private_disk_image_id,omitempty"`
			Preset             string `json:"preset,omitempty"`
		} `json:"source"`
		Resources struct {
			CPU    string `json:"cpu,omitempty"`
			Memory string `json:"memory,omitempty"`
			Disk   string `json:"disk,omitempty"`
		} `json:"resources"`
		Labels                     map[string]string `json:"labels,omitempty"`
		Environment                map[string]string `json:"environment,omitempty"`
		EnvironmentWOKeys          []string          `json:"environment_wo_keys,omitempty"`
		EnvironmentWOVersion       int64             `json:"environment_wo_version,omitempty"`
		Connections                []string          `json:"connections,omitempty"`
		Entrypoint                 []string          `json:"entrypoint,omitempty"`
		Command                    []string          `json:"command,omitempty"`
		SkipEgressProxy            *bool             `json:"skip_egress_proxy,omitempty"`
		CustomerVNetConnectionName string            `json:"customer_vnet_connection_name,omitempty"`
		VMMType                    string            `json:"vmm_type,omitempty"`
	}{
		GroupID:                    stringValue(config.SandboxGroupID),
		Name:                       stringValue(config.Name),
		Labels:                     labels,
		Environment:                normalEnvironment,
		EnvironmentWOKeys:          woKeys,
		Connections:                connections,
		Entrypoint:                 entrypoint,
		Command:                    command,
		CustomerVNetConnectionName: stringValue(config.CustomerVNetConnectionName),
		VMMType:                    stringValue(config.VMMType),
	}
	payload.Source.PublicDiskImage = stringValue(source.PublicDiskImage)
	payload.Source.PrivateDiskImageID = stringValue(source.PrivateDiskImageID)
	payload.Source.Preset = stringValue(source.Preset)
	payload.Resources.CPU = stringValue(resources.CPU)
	payload.Resources.Memory = stringValue(resources.Memory)
	payload.Resources.Disk = stringValue(resources.Disk)
	if !config.EnvironmentWOVersion.IsNull() && !config.EnvironmentWOVersion.IsUnknown() {
		payload.EnvironmentWOVersion = config.EnvironmentWOVersion.ValueInt64()
	}
	if !config.SkipEgressProxy.IsNull() && !config.SkipEgressProxy.IsUnknown() {
		value := config.SkipEgressProxy.ValueBool()
		payload.SkipEgressProxy = &value
	}

	encoded, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}
	hash := sha256.Sum256(encoded)
	return hex.EncodeToString(hash[:16]), nil
}

func filterSandboxesByLabel(
	sandboxes []client.Sandbox,
	key string,
	value string,
) []client.Sandbox {
	var result []client.Sandbox
	for _, sandbox := range sandboxes {
		if sandbox.Labels[key] == value {
			result = append(result, sandbox)
		}
	}
	return result
}

func recoverSandbox(
	ctx context.Context,
	apiClient *client.Client,
	name string,
	fingerprint string,
) (client.Sandbox, error) {
	deadline := recoveryDeadline(ctx)
	for {
		sandboxes, err := apiClient.ListSandboxes(ctx, map[string]string{
			labelTerraformName:     name,
			labelCreateFingerprint: fingerprint,
		})
		if err != nil {
			return client.Sandbox{}, err
		}
		var matches []client.Sandbox
		for _, sandbox := range sandboxes {
			if sandbox.Labels[labelTerraformName] == name &&
				sandbox.Labels[labelCreateFingerprint] == fingerprint {
				matches = append(matches, sandbox)
			}
		}
		switch len(matches) {
		case 1:
			return matches[0], nil
		case 0:
			if time.Now().Before(deadline) {
				if err := waitRecoveryPoll(ctx); err != nil {
					return client.Sandbox{}, err
				}
				continue
			}
		default:
			return client.Sandbox{}, fmt.Errorf(
				"found %d Sandboxes with the same recovery labels; import the intended Sandbox explicitly",
				len(matches),
			)
		}
		return client.Sandbox{}, fmt.Errorf("no Sandbox appeared with the recovery labels")
	}
}

func sandboxImportMessage(
	sandboxes []client.Sandbox,
	endpoint ids.Endpoint,
	group ids.GroupID,
) string {
	values := make([]string, 0, len(sandboxes))
	for _, sandbox := range sandboxes {
		resourceURL, _ := ids.ResourceURL(endpoint, group, "sandboxes", sandbox.ID)
		values = append(values, sandbox.ID+" ("+resourceURL+")")
	}
	return "A provider-managed Sandbox with this name already exists. Import exactly one instead of creating another: " +
		strings.Join(values, ", ")
}

func applySandboxResponse(
	ctx context.Context,
	model *sandboxModel,
	sandbox client.Sandbox,
	endpoint ids.Endpoint,
	group ids.GroupID,
	imported bool,
	diagnostics *diag.Diagnostics,
) {
	if sandbox.ID != "" {
		model.ID = types.StringValue(sandbox.ID)
		resourceURL, err := ids.ResourceURL(endpoint, group, "sandboxes", sandbox.ID)
		if err == nil {
			model.ResourceURL = types.StringValue(resourceURL)
		}
	}
	model.State = nullableString(sandbox.State)
	model.Hostname = nullableString(sandbox.Hostname)
	model.ManagementURL = nullableString(sandbox.ManagementURL)
	model.CreatedAt = nullableString(sandbox.CreatedAt)
	model.Region = nullableString(sandbox.Region)
	if sandbox.StateDetails != nil {
		model.StoppedReason = nullableString(sandbox.StateDetails.StoppedReason)
		model.StoppedAt = nullableString(sandbox.StateDetails.StoppedAt)
	} else {
		model.StoppedReason = types.StringNull()
		model.StoppedAt = types.StringNull()
	}

	if imported {
		name := sandbox.Labels[labelTerraformName]
		if name == "" {
			name = sandbox.ID
		}
		model.Name = types.StringValue(name)
		source, sourceDiags := sourceObjectFromAPI(sandbox)
		resources, resourceDiags := resourcesObjectFromAPI(sandbox.Resources)
		diagnostics.Append(sourceDiags...)
		diagnostics.Append(resourceDiags...)
		model.Source = source
		model.Resources = resources
		if len(sandbox.Connections) > 0 {
			connections, connectionDiags := types.SetValueFrom(ctx, types.StringType, sandbox.Connections)
			diagnostics.Append(connectionDiags...)
			model.Connections = connections
		}
		if len(sandbox.Entrypoint) > 0 {
			model.Entrypoint = listFromStrings(sandbox.Entrypoint)
		}
		model.CustomerVNetConnectionName = nullableString(sandbox.CustomerVNetConnectionName)
		model.VMMType = nullableString(sandbox.VMMType)
	}

	userLabels := removeReservedLabels(sandbox.Labels)
	if len(userLabels) > 0 || !model.Labels.IsNull() {
		model.Labels = mapFromStrings(userLabels)
	}
	if len(sandbox.Ports) > 0 || !model.Ports.IsNull() {
		ports, portDiags := portMapFromAPI(ctx, model.Ports, sandbox.Ports)
		diagnostics.Append(portDiags...)
		model.Ports = ports
	}
}
