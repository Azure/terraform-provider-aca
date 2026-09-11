package provider

import (
	"context"
	"fmt"
	"net"
	"sort"
	"strconv"

	"github.com/hashicorp/terraform-plugin-framework/diag"
	"github.com/hashicorp/terraform-plugin-framework/types"
	"github.com/hashicorp/terraform-plugin-framework/types/basetypes"

	"github.com/Azure/terraform-provider-aca/provider/internal/client"
)

type sandboxSourceModel struct {
	PublicDiskImage    types.String `tfsdk:"public_disk_image"`
	PrivateDiskImageID types.String `tfsdk:"private_disk_image_id"`
	Preset             types.String `tfsdk:"preset"`
}

type sandboxResourcesModel struct {
	CPU    types.String `tfsdk:"cpu"`
	Memory types.String `tfsdk:"memory"`
	Disk   types.String `tfsdk:"disk"`
}

type autoSuspendModel struct {
	Enabled         types.Bool   `tfsdk:"enabled"`
	IntervalSeconds types.Int64  `tfsdk:"interval_seconds"`
	Mode            types.String `tfsdk:"mode"`
}

type egressHostRuleModel struct {
	Pattern types.String `tfsdk:"pattern"`
	Action  types.String `tfsdk:"action"`
}

type egressSecretRefModel struct {
	SecretID  types.String `tfsdk:"secret_id"`
	SecretKey types.String `tfsdk:"secret_key"`
	Format    types.String `tfsdk:"format"`
}

type egressManagedIdentityRefModel struct {
	IdentityType       types.String `tfsdk:"identity_type"`
	Resource           types.String `tfsdk:"resource"`
	IdentityResourceID types.String `tfsdk:"identity_resource_id"`
	Format             types.String `tfsdk:"format"`
}

type egressHeaderValueRefModel struct {
	SecretRef          types.Object `tfsdk:"secret_ref"`
	ManagedIdentityRef types.Object `tfsdk:"managed_identity_ref"`
}

type egressHeaderModel struct {
	Operation types.String `tfsdk:"operation"`
	Name      types.String `tfsdk:"name"`
	Value     types.String `tfsdk:"value"`
	ValueRef  types.Object `tfsdk:"value_ref"`
}

type egressRuleMatchModel struct {
	Host    types.String `tfsdk:"host"`
	Path    types.String `tfsdk:"path"`
	Methods types.Set    `tfsdk:"methods"`
}

type egressRuleActionModel struct {
	Type    types.String `tfsdk:"type"`
	Host    types.String `tfsdk:"host"`
	Path    types.String `tfsdk:"path"`
	Scheme  types.String `tfsdk:"scheme"`
	Headers types.List   `tfsdk:"headers"`
}

type egressRuleModel struct {
	Name   types.String `tfsdk:"name"`
	Match  types.Object `tfsdk:"match"`
	Action types.Object `tfsdk:"action"`
}

type egressPolicyModel struct {
	DefaultAction     types.String `tfsdk:"default_action"`
	HostRules         types.List   `tfsdk:"host_rules"`
	Rules             types.List   `tfsdk:"rules"`
	TrafficInspection types.String `tfsdk:"traffic_inspection"`
}

type portEntraIDModel struct {
	Enabled types.Bool `tfsdk:"enabled"`
	Emails  types.Set  `tfsdk:"emails"`
}

type portAuthModel struct {
	Anonymous types.Bool   `tfsdk:"anonymous"`
	EntraID   types.Object `tfsdk:"entra_id"`
}

type portIPRuleModel struct {
	Name        types.String `tfsdk:"name"`
	Action      types.String `tfsdk:"action"`
	Priority    types.Int64  `tfsdk:"priority"`
	SourceCIDRs types.Set    `tfsdk:"source_cidrs"`
}

type portIPAccessControlModel struct {
	DefaultAction types.String `tfsdk:"default_action"`
	Rules         types.List   `tfsdk:"rules"`
}

type portModel struct {
	Port            types.Int64  `tfsdk:"port"`
	Protocol        types.String `tfsdk:"protocol"`
	ActivationMode  types.String `tfsdk:"activation_mode"`
	Auth            types.Object `tfsdk:"auth"`
	IPAccessControl types.Object `tfsdk:"ip_access_control"`
	HostPort        types.Int64  `tfsdk:"host_port"`
	URL             types.String `tfsdk:"url"`
}

func sourceFromObject(ctx context.Context, value types.Object) (sandboxSourceModel, diag.Diagnostics) {
	var result sandboxSourceModel
	if value.IsNull() || value.IsUnknown() {
		return result, nil
	}
	diags := value.As(ctx, &result, basetypes.ObjectAsOptions{})
	return result, diags
}

func resourcesFromObject(ctx context.Context, value types.Object) (sandboxResourcesModel, diag.Diagnostics) {
	var result sandboxResourcesModel
	if value.IsNull() || value.IsUnknown() {
		return result, nil
	}
	diags := value.As(ctx, &result, basetypes.ObjectAsOptions{})
	return result, diags
}

func autoSuspendFromObject(ctx context.Context, value types.Object) (autoSuspendModel, diag.Diagnostics) {
	var result autoSuspendModel
	if value.IsNull() || value.IsUnknown() {
		return result, nil
	}
	diags := value.As(ctx, &result, basetypes.ObjectAsOptions{})
	return result, diags
}

func egressPolicyFromObject(ctx context.Context, value types.Object) (*client.EgressPolicy, diag.Diagnostics) {
	if value.IsNull() || value.IsUnknown() {
		return nil, nil
	}
	var model egressPolicyModel
	diags := value.As(ctx, &model, basetypes.ObjectAsOptions{})
	if diags.HasError() {
		return nil, diags
	}

	policy := &client.EgressPolicy{
		DefaultAction:     stringValue(model.DefaultAction),
		TrafficInspection: stringValue(model.TrafficInspection),
	}

	if !model.HostRules.IsNull() && !model.HostRules.IsUnknown() {
		var hostRules []egressHostRuleModel
		diags.Append(model.HostRules.ElementsAs(ctx, &hostRules, false)...)
		for _, rule := range hostRules {
			policy.HostRules = append(policy.HostRules, client.EgressHostRule{
				Pattern: stringValue(rule.Pattern),
				Action:  stringValue(rule.Action),
			})
		}
	}

	if !model.Rules.IsNull() && !model.Rules.IsUnknown() {
		var rules []egressRuleModel
		diags.Append(model.Rules.ElementsAs(ctx, &rules, false)...)
		for _, rule := range rules {
			wire, ruleDiags := egressRuleToWire(ctx, rule)
			diags.Append(ruleDiags...)
			policy.Rules = append(policy.Rules, wire)
		}
	}
	return policy, diags
}

func egressRuleToWire(ctx context.Context, model egressRuleModel) (client.EgressRule, diag.Diagnostics) {
	var diags diag.Diagnostics
	result := client.EgressRule{Name: stringValue(model.Name)}

	if !model.Match.IsNull() && !model.Match.IsUnknown() {
		var match egressRuleMatchModel
		diags.Append(model.Match.As(ctx, &match, basetypes.ObjectAsOptions{})...)
		methods, methodDiags := stringSet(ctx, match.Methods)
		diags.Append(methodDiags...)
		result.Match = &client.EgressRuleMatch{
			Host:    stringValue(match.Host),
			Path:    stringValue(match.Path),
			Methods: methods,
		}
	}

	if !model.Action.IsNull() && !model.Action.IsUnknown() {
		var action egressRuleActionModel
		diags.Append(model.Action.As(ctx, &action, basetypes.ObjectAsOptions{})...)
		wire := &client.EgressRuleAction{
			Type:   stringValue(action.Type),
			Host:   stringValue(action.Host),
			Path:   stringValue(action.Path),
			Scheme: stringValue(action.Scheme),
		}
		if !action.Headers.IsNull() && !action.Headers.IsUnknown() {
			var headers []egressHeaderModel
			diags.Append(action.Headers.ElementsAs(ctx, &headers, false)...)
			for _, header := range headers {
				valueRef, valueRefDiags := egressHeaderValueRefToWire(ctx, header.ValueRef)
				diags.Append(valueRefDiags...)
				wire.Headers = append(wire.Headers, client.EgressHeader{
					Operation: stringValue(header.Operation),
					Name:      stringValue(header.Name),
					Value:     stringValue(header.Value),
					ValueRef:  valueRef,
				})
			}
		}
		result.Action = wire
	}
	return result, diags
}

func egressHeaderValueRefToWire(
	ctx context.Context,
	value types.Object,
) (*client.EgressHeaderValueRef, diag.Diagnostics) {
	if value.IsNull() || value.IsUnknown() {
		return nil, nil
	}
	var model egressHeaderValueRefModel
	diags := value.As(ctx, &model, basetypes.ObjectAsOptions{})
	result := &client.EgressHeaderValueRef{}

	if !model.SecretRef.IsNull() && !model.SecretRef.IsUnknown() {
		var secret egressSecretRefModel
		diags.Append(model.SecretRef.As(ctx, &secret, basetypes.ObjectAsOptions{})...)
		result.SecretRef = &client.EgressSecretRef{
			SecretID:  stringValue(secret.SecretID),
			SecretKey: stringValue(secret.SecretKey),
			Format:    stringValue(secret.Format),
		}
	}
	if !model.ManagedIdentityRef.IsNull() && !model.ManagedIdentityRef.IsUnknown() {
		var identity egressManagedIdentityRefModel
		diags.Append(model.ManagedIdentityRef.As(ctx, &identity, basetypes.ObjectAsOptions{})...)
		result.ManagedIdentityRef = &client.EgressManagedIdentityRef{
			IdentityType:       stringValue(identity.IdentityType),
			Resource:           stringValue(identity.Resource),
			IdentityResourceID: stringValue(identity.IdentityResourceID),
			Format:             stringValue(identity.Format),
		}
	}
	return result, diags
}

func portsFromMap(ctx context.Context, value types.Map) (map[string]client.PortRequest, diag.Diagnostics) {
	result := map[string]client.PortRequest{}
	if value.IsNull() || value.IsUnknown() {
		return result, nil
	}
	var models map[string]portModel
	diags := value.ElementsAs(ctx, &models, false)
	for key, model := range models {
		request, requestDiags := portToWire(ctx, model)
		diags.Append(requestDiags...)
		result[key] = request
	}
	return result, diags
}

func portToWire(ctx context.Context, model portModel) (client.PortRequest, diag.Diagnostics) {
	var diags diag.Diagnostics
	result := client.PortRequest{
		Port:           model.Port.ValueInt64(),
		Protocol:       stringValue(model.Protocol),
		ActivationMode: stringValue(model.ActivationMode),
	}
	if !model.Auth.IsNull() && !model.Auth.IsUnknown() {
		var auth portAuthModel
		diags.Append(model.Auth.As(ctx, &auth, basetypes.ObjectAsOptions{})...)
		wire := &client.PortAuth{}
		if !auth.Anonymous.IsNull() && !auth.Anonymous.IsUnknown() {
			value := auth.Anonymous.ValueBool()
			wire.Anonymous = &value
		}
		if !auth.EntraID.IsNull() && !auth.EntraID.IsUnknown() {
			var entra portEntraIDModel
			diags.Append(auth.EntraID.As(ctx, &entra, basetypes.ObjectAsOptions{})...)
			emails, emailDiags := stringSet(ctx, entra.Emails)
			diags.Append(emailDiags...)
			wire.EntraID = &client.PortAuthEntraID{
				Enabled: boolValue(entra.Enabled),
				Emails:  emails,
			}
		}
		result.Auth = wire
	}
	if !model.IPAccessControl.IsNull() && !model.IPAccessControl.IsUnknown() {
		var access portIPAccessControlModel
		diags.Append(model.IPAccessControl.As(ctx, &access, basetypes.ObjectAsOptions{})...)
		wire := &client.PortIPAccessControl{DefaultAction: stringValue(access.DefaultAction)}
		if !access.Rules.IsNull() && !access.Rules.IsUnknown() {
			var rules []portIPRuleModel
			diags.Append(access.Rules.ElementsAs(ctx, &rules, false)...)
			for _, rule := range rules {
				cidrs, cidrDiags := stringSet(ctx, rule.SourceCIDRs)
				diags.Append(cidrDiags...)
				wire.Rules = append(wire.Rules, client.PortIPRule{
					Name:        stringValue(rule.Name),
					Action:      stringValue(rule.Action),
					Priority:    rule.Priority.ValueInt64(),
					SourceCIDRs: cidrs,
				})
			}
		}
		result.IPAccessControl = wire
	}
	return result, diags
}

func orderedPorts(values map[string]client.PortRequest) []client.PortRequest {
	keys := make([]string, 0, len(values))
	for key := range values {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	result := make([]client.PortRequest, 0, len(keys))
	for _, key := range keys {
		result = append(result, values[key])
	}
	return result
}

func validatePorts(ctx context.Context, value types.Map) diag.Diagnostics {
	var diags diag.Diagnostics
	ports, conversionDiags := portsFromMap(ctx, value)
	diags.Append(conversionDiags...)
	if diags.HasError() {
		return diags
	}

	seenPorts := map[int64]string{}
	for logicalName, port := range ports {
		if previous, exists := seenPorts[port.Port]; exists {
			diags.AddError(
				"Duplicate Sandbox port",
				fmt.Sprintf("Ports %q and %q both configure port %d.", previous, logicalName, port.Port),
			)
		}
		seenPorts[port.Port] = logicalName

		if port.Auth != nil && port.Auth.Anonymous != nil && *port.Auth.Anonymous && port.Auth.EntraID != nil {
			diags.AddError(
				"Conflicting port authentication",
				fmt.Sprintf("Port %q cannot enable anonymous and Entra ID authentication together.", logicalName),
			)
		}
		if port.IPAccessControl == nil {
			continue
		}
		if len(port.IPAccessControl.Rules) > 10 {
			diags.AddError("Too many port IP rules", fmt.Sprintf("Port %q has more than 10 IP access rules.", logicalName))
		}
		seenNames := map[string]struct{}{}
		seenPriorities := map[int64]struct{}{}
		for _, rule := range port.IPAccessControl.Rules {
			lowerName := stringsLower(rule.Name)
			if _, exists := seenNames[lowerName]; exists {
				diags.AddError("Duplicate port IP rule name", fmt.Sprintf("Port %q repeats rule name %q.", logicalName, rule.Name))
			}
			seenNames[lowerName] = struct{}{}
			if _, exists := seenPriorities[rule.Priority]; exists {
				diags.AddError("Duplicate port IP rule priority", fmt.Sprintf("Port %q repeats priority %d.", logicalName, rule.Priority))
			}
			seenPriorities[rule.Priority] = struct{}{}
			if len(rule.SourceCIDRs) == 0 || len(rule.SourceCIDRs) > 10 {
				diags.AddError("Invalid port IP CIDR count", fmt.Sprintf("Rule %q must have between 1 and 10 CIDRs.", rule.Name))
			}
			for _, value := range rule.SourceCIDRs {
				ip, network, err := net.ParseCIDR(value)
				if err != nil || !ip.Equal(network.IP) {
					diags.AddError("Invalid source CIDR", fmt.Sprintf("%q is not a canonical network CIDR.", value))
				}
			}
		}
	}
	return diags
}

func stringsLower(value string) string {
	result := make([]rune, 0, len(value))
	for _, r := range value {
		if r >= 'A' && r <= 'Z' {
			r += 'a' - 'A'
		}
		result = append(result, r)
	}
	return string(result)
}

func stringSet(ctx context.Context, value types.Set) ([]string, diag.Diagnostics) {
	var result []string
	if value.IsNull() || value.IsUnknown() {
		return result, nil
	}
	diags := value.ElementsAs(ctx, &result, false)
	sort.Strings(result)
	return result, diags
}

func portKey(port int64) string {
	return strconv.FormatInt(port, 10)
}
