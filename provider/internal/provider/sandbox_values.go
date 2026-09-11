package provider

import (
	"context"
	"fmt"

	"github.com/hashicorp/terraform-plugin-framework/attr"
	"github.com/hashicorp/terraform-plugin-framework/diag"
	"github.com/hashicorp/terraform-plugin-framework/types"

	"github.com/Azure/terraform-provider-aca/provider/internal/client"
)

func sourceAttrTypes() map[string]attr.Type {
	return map[string]attr.Type{
		"public_disk_image":     types.StringType,
		"private_disk_image_id": types.StringType,
		"preset":                types.StringType,
	}
}

func resourcesAttrTypes() map[string]attr.Type {
	return map[string]attr.Type{
		"cpu":    types.StringType,
		"memory": types.StringType,
		"disk":   types.StringType,
	}
}

func portAuthAttrTypes() map[string]attr.Type {
	return map[string]attr.Type{
		"anonymous": types.BoolType,
		"entra_id":  types.ObjectType{AttrTypes: portEntraIDAttrTypes()},
	}
}

func portEntraIDAttrTypes() map[string]attr.Type {
	return map[string]attr.Type{
		"enabled": types.BoolType,
		"emails":  types.SetType{ElemType: types.StringType},
	}
}

func portIPRuleAttrTypes() map[string]attr.Type {
	return map[string]attr.Type{
		"name":         types.StringType,
		"action":       types.StringType,
		"priority":     types.Int64Type,
		"source_cidrs": types.SetType{ElemType: types.StringType},
	}
}

func portIPAccessControlAttrTypes() map[string]attr.Type {
	return map[string]attr.Type{
		"default_action": types.StringType,
		"rules": types.ListType{
			ElemType: types.ObjectType{AttrTypes: portIPRuleAttrTypes()},
		},
	}
}

func portAttrTypes() map[string]attr.Type {
	return map[string]attr.Type{
		"port":              types.Int64Type,
		"protocol":          types.StringType,
		"activation_mode":   types.StringType,
		"auth":              types.ObjectType{AttrTypes: portAuthAttrTypes()},
		"ip_access_control": types.ObjectType{AttrTypes: portIPAccessControlAttrTypes()},
		"host_port":         types.Int64Type,
		"url":               types.StringType,
	}
}

func sourceObjectFromAPI(sandbox client.Sandbox) (types.Object, diag.Diagnostics) {
	model := sandboxSourceModel{
		PublicDiskImage:    types.StringNull(),
		PrivateDiskImageID: types.StringNull(),
		Preset:             types.StringNull(),
	}
	if sandbox.PresetSandboxType != "" {
		model.Preset = types.StringValue(sandbox.PresetSandboxType)
	} else if sandbox.SourcesRef != nil && sandbox.SourcesRef.DiskImage != nil {
		image := sandbox.SourcesRef.DiskImage
		if image.ID != "" {
			model.PrivateDiskImageID = types.StringValue(image.ID)
		} else if image.Name != "" {
			model.PublicDiskImage = types.StringValue(image.Name)
		}
	}
	return types.ObjectValueFrom(context.Background(), sourceAttrTypes(), model)
}

func resourcesObjectFromAPI(resources *client.SandboxResources) (types.Object, diag.Diagnostics) {
	if resources == nil {
		return types.ObjectNull(resourcesAttrTypes()), nil
	}
	model := sandboxResourcesModel{
		CPU:    types.StringValue(resources.CPU),
		Memory: types.StringValue(resources.Memory),
		Disk:   types.StringNull(),
	}
	if resources.Disk != "" {
		model.Disk = types.StringValue(resources.Disk)
	}
	return types.ObjectValueFrom(context.Background(), resourcesAttrTypes(), model)
}

func portMapFromRequests(
	ctx context.Context,
	ports map[string]client.PortRequest,
) (types.Map, diag.Diagnostics) {
	models := make(map[string]portModel, len(ports))
	for key, port := range ports {
		model, diags := portModelFromRequest(ctx, port)
		if diags.HasError() {
			return types.MapNull(types.ObjectType{AttrTypes: portAttrTypes()}), diags
		}
		models[key] = model
	}
	return types.MapValueFrom(ctx, types.ObjectType{AttrTypes: portAttrTypes()}, models)
}

func portMapFromAPI(
	ctx context.Context,
	prior types.Map,
	ports []client.SandboxPort,
) (types.Map, diag.Diagnostics) {
	if len(ports) == 0 && !prior.IsNull() && !prior.IsUnknown() {
		return prior, nil
	}

	priorByPort := map[int64]struct {
		key   string
		model portModel
	}{}
	if !prior.IsNull() && !prior.IsUnknown() {
		var priorModels map[string]portModel
		diags := prior.ElementsAs(ctx, &priorModels, false)
		if diags.HasError() {
			return types.MapNull(types.ObjectType{AttrTypes: portAttrTypes()}), diags
		}
		for key, model := range priorModels {
			priorByPort[model.Port.ValueInt64()] = struct {
				key   string
				model portModel
			}{key: key, model: model}
		}
	}

	result := make(map[string]portModel, len(ports))
	var diags diag.Diagnostics
	for _, port := range ports {
		if priorValue, ok := priorByPort[port.Port]; ok {
			model := priorValue.model
			model.HostPort = nullableInt64(port.HostPort)
			model.URL = nullableString(port.URL)
			if model.Protocol.IsNull() && port.Protocol != "" {
				model.Protocol = types.StringValue(port.Protocol)
			}
			result[priorValue.key] = model
			continue
		}

		model := portModel{
			Port:            types.Int64Value(port.Port),
			Protocol:        nullableString(port.Protocol),
			ActivationMode:  types.StringNull(),
			Auth:            types.ObjectNull(portAuthAttrTypes()),
			IPAccessControl: types.ObjectNull(portIPAccessControlAttrTypes()),
			HostPort:        nullableInt64(port.HostPort),
			URL:             nullableString(port.URL),
		}
		result[portKey(port.Port)] = model
	}

	value, valueDiags := types.MapValueFrom(
		ctx,
		types.ObjectType{AttrTypes: portAttrTypes()},
		result,
	)
	diags.Append(valueDiags...)
	return value, diags
}

func portModelFromRequest(ctx context.Context, port client.PortRequest) (portModel, diag.Diagnostics) {
	var diags diag.Diagnostics
	model := portModel{
		Port:            types.Int64Value(port.Port),
		Protocol:        nullableString(port.Protocol),
		ActivationMode:  nullableString(port.ActivationMode),
		Auth:            types.ObjectNull(portAuthAttrTypes()),
		IPAccessControl: types.ObjectNull(portIPAccessControlAttrTypes()),
		HostPort:        types.Int64Null(),
		URL:             types.StringNull(),
	}

	if port.Auth != nil {
		authModel := portAuthModel{
			Anonymous: types.BoolNull(),
			EntraID:   types.ObjectNull(portEntraIDAttrTypes()),
		}
		if port.Auth.Anonymous != nil {
			authModel.Anonymous = types.BoolValue(*port.Auth.Anonymous)
		}
		if port.Auth.EntraID != nil {
			emails, emailDiags := types.SetValueFrom(ctx, types.StringType, port.Auth.EntraID.Emails)
			diags.Append(emailDiags...)
			entraModel := portEntraIDModel{
				Enabled: types.BoolValue(port.Auth.EntraID.Enabled),
				Emails:  emails,
			}
			entra, entraDiags := types.ObjectValueFrom(ctx, portEntraIDAttrTypes(), entraModel)
			diags.Append(entraDiags...)
			authModel.EntraID = entra
		}
		auth, authDiags := types.ObjectValueFrom(ctx, portAuthAttrTypes(), authModel)
		diags.Append(authDiags...)
		model.Auth = auth
	}

	if port.IPAccessControl != nil {
		rules := make([]portIPRuleModel, 0, len(port.IPAccessControl.Rules))
		for _, rule := range port.IPAccessControl.Rules {
			cidrs, cidrDiags := types.SetValueFrom(ctx, types.StringType, rule.SourceCIDRs)
			diags.Append(cidrDiags...)
			rules = append(rules, portIPRuleModel{
				Name:        types.StringValue(rule.Name),
				Action:      types.StringValue(rule.Action),
				Priority:    types.Int64Value(rule.Priority),
				SourceCIDRs: cidrs,
			})
		}
		ruleList, ruleDiags := types.ListValueFrom(
			ctx,
			types.ObjectType{AttrTypes: portIPRuleAttrTypes()},
			rules,
		)
		diags.Append(ruleDiags...)
		accessModel := portIPAccessControlModel{
			DefaultAction: types.StringValue(port.IPAccessControl.DefaultAction),
			Rules:         ruleList,
		}
		access, accessDiags := types.ObjectValueFrom(ctx, portIPAccessControlAttrTypes(), accessModel)
		diags.Append(accessDiags...)
		model.IPAccessControl = access
	}
	return model, diags
}

func nullableString(value string) types.String {
	if value == "" {
		return types.StringNull()
	}
	return types.StringValue(value)
}

func nullableInt64(value int64) types.Int64 {
	if value == 0 {
		return types.Int64Null()
	}
	return types.Int64Value(value)
}

func oneSource(model sandboxSourceModel) (string, string, error) {
	values := []struct {
		kind  string
		value string
	}{
		{kind: "public", value: stringValue(model.PublicDiskImage)},
		{kind: "private", value: stringValue(model.PrivateDiskImageID)},
		{kind: "preset", value: stringValue(model.Preset)},
	}
	var selected []struct {
		kind  string
		value string
	}
	for _, value := range values {
		if value.value != "" {
			selected = append(selected, value)
		}
	}
	if len(selected) != 1 {
		return "", "", fmt.Errorf("configure exactly one of public_disk_image, private_disk_image_id, or preset")
	}
	return selected[0].kind, selected[0].value, nil
}
