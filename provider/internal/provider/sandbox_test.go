package provider

import (
	"context"
	"testing"

	"github.com/hashicorp/terraform-plugin-framework/types"
)

func TestSandboxFingerprintExcludesWriteOnlyValues(t *testing.T) {
	t.Parallel()

	source, sourceDiags := types.ObjectValueFrom(context.Background(), sourceAttrTypes(), sandboxSourceModel{
		PublicDiskImage:    types.StringValue("ubuntu"),
		PrivateDiskImageID: types.StringNull(),
		Preset:             types.StringNull(),
	})
	resources, resourceDiags := types.ObjectValueFrom(context.Background(), resourcesAttrTypes(), sandboxResourcesModel{
		CPU:    types.StringValue("1000m"),
		Memory: types.StringValue("2048Mi"),
		Disk:   types.StringNull(),
	})
	if sourceDiags.HasError() || resourceDiags.HasError() {
		t.Fatalf("building test values failed: %v %v", sourceDiags, resourceDiags)
	}

	base := sandboxModel{
		SandboxGroupID:       types.StringValue("/subscriptions/sub/resourceGroups/rg/providers/Microsoft.App/sandboxGroups/group"),
		Name:                 types.StringValue("example"),
		Source:               source,
		Resources:            resources,
		Environment:          types.MapNull(types.StringType),
		EnvironmentWOVersion: types.Int64Value(1),
	}
	sourceModel, _ := sourceFromObject(context.Background(), source)
	resourceModel, _ := resourcesFromObject(context.Background(), resources)
	first, err := sandboxFingerprint(
		base,
		sourceModel,
		resourceModel,
		nil,
		map[string]string{"TOKEN": "first"},
		nil,
		nil,
		nil,
	)
	if err != nil {
		t.Fatalf("sandboxFingerprint() error = %v", err)
	}
	second, err := sandboxFingerprint(
		base,
		sourceModel,
		resourceModel,
		nil,
		map[string]string{"TOKEN": "second"},
		nil,
		nil,
		nil,
	)
	if err != nil {
		t.Fatalf("sandboxFingerprint() error = %v", err)
	}
	if first != second {
		t.Fatalf("fingerprint changed with secret value: %q != %q", first, second)
	}

	base.EnvironmentWOVersion = types.Int64Value(2)
	third, err := sandboxFingerprint(
		base,
		sourceModel,
		resourceModel,
		nil,
		map[string]string{"TOKEN": "second"},
		nil,
		nil,
		nil,
	)
	if err != nil {
		t.Fatalf("sandboxFingerprint() error = %v", err)
	}
	if first == third {
		t.Fatal("fingerprint did not change with environment_wo_version")
	}
}

func TestSandboxFingerprintIncludesSourceAndResources(t *testing.T) {
	t.Parallel()

	base := sandboxModel{
		SandboxGroupID: types.StringValue("/subscriptions/sub/resourceGroups/rg/providers/Microsoft.App/sandboxGroups/group"),
		Name:           types.StringValue("example"),
		Environment:    types.MapNull(types.StringType),
	}
	publicSource := sandboxSourceModel{
		PublicDiskImage:    types.StringValue("ubuntu"),
		PrivateDiskImageID: types.StringNull(),
		Preset:             types.StringNull(),
	}
	privateSource := sandboxSourceModel{
		PublicDiskImage:    types.StringNull(),
		PrivateDiskImageID: types.StringValue("disk-id"),
		Preset:             types.StringNull(),
	}
	resources := sandboxResourcesModel{
		CPU:    types.StringValue("1000m"),
		Memory: types.StringValue("2048Mi"),
		Disk:   types.StringNull(),
	}

	first, err := sandboxFingerprint(base, publicSource, resources, nil, nil, nil, nil, nil)
	if err != nil {
		t.Fatalf("sandboxFingerprint() error = %v", err)
	}
	second, err := sandboxFingerprint(base, privateSource, resources, nil, nil, nil, nil, nil)
	if err != nil {
		t.Fatalf("sandboxFingerprint() error = %v", err)
	}
	if first == second {
		t.Fatal("fingerprint did not change with Sandbox source")
	}

	resources.CPU = types.StringValue("2000m")
	third, err := sandboxFingerprint(base, publicSource, resources, nil, nil, nil, nil, nil)
	if err != nil {
		t.Fatalf("sandboxFingerprint() error = %v", err)
	}
	if first == third {
		t.Fatal("fingerprint did not change with Sandbox resources")
	}
}

func TestValidatePortsRejectsHostCIDR(t *testing.T) {
	t.Parallel()

	cidrs, _ := types.SetValueFrom(context.Background(), types.StringType, []string{"10.0.0.5/8"})
	rules, _ := types.ListValueFrom(
		context.Background(),
		types.ObjectType{AttrTypes: portIPRuleAttrTypes()},
		[]portIPRuleModel{{
			Name:        types.StringValue("office"),
			Action:      types.StringValue("Allow"),
			Priority:    types.Int64Value(10),
			SourceCIDRs: cidrs,
		}},
	)
	access, _ := types.ObjectValueFrom(
		context.Background(),
		portIPAccessControlAttrTypes(),
		portIPAccessControlModel{
			DefaultAction: types.StringValue("Deny"),
			Rules:         rules,
		},
	)
	ports, _ := types.MapValueFrom(
		context.Background(),
		types.ObjectType{AttrTypes: portAttrTypes()},
		map[string]portModel{
			"web": {
				Port:            types.Int64Value(8080),
				Protocol:        types.StringValue("Http"),
				ActivationMode:  types.StringNull(),
				Auth:            types.ObjectNull(portAuthAttrTypes()),
				IPAccessControl: access,
				HostPort:        types.Int64Null(),
				URL:             types.StringNull(),
			},
		},
	)

	diagnostics := validatePorts(context.Background(), ports)
	if !diagnostics.HasError() {
		t.Fatal("validatePorts() expected an error")
	}
}
