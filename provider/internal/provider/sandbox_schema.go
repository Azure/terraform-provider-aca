package provider

import (
	"context"
	"regexp"

	"github.com/hashicorp/terraform-plugin-framework-timeouts/resource/timeouts"
	"github.com/hashicorp/terraform-plugin-framework-validators/int64validator"
	"github.com/hashicorp/terraform-plugin-framework-validators/listvalidator"
	"github.com/hashicorp/terraform-plugin-framework-validators/stringvalidator"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/booldefault"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/boolplanmodifier"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/int64planmodifier"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/listplanmodifier"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/mapplanmodifier"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/objectplanmodifier"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/planmodifier"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/setplanmodifier"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/stringdefault"
	"github.com/hashicorp/terraform-plugin-framework/schema/validator"
	"github.com/hashicorp/terraform-plugin-framework/types"
)

var portRuleNamePattern = regexp.MustCompile(`^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$`)

func sandboxResourceSchema(ctx context.Context) schema.Schema {
	return schema.Schema{
		MarkdownDescription: "Manages an ACA Sandbox data-plane resource.",
		Attributes: map[string]schema.Attribute{
			"sandbox_group_id": requiredReplaceString("ARM resource ID of the SandboxGroup."),
			"location":         optionalReplaceString("Canonical Azure location used to derive the regional data-plane endpoint."),
			"endpoint":         optionalReplaceString("Explicit Sandbox data-plane endpoint. Conflicts with location."),
			"name":             requiredReplaceString("Logical name, unique among provider-managed Sandboxes in the SandboxGroup."),
			"source": schema.SingleNestedAttribute{
				Required:    true,
				Description: "Sandbox source. Configure exactly one of public_disk_image, private_disk_image_id, or preset.",
				Attributes: map[string]schema.Attribute{
					"public_disk_image":     schema.StringAttribute{Optional: true},
					"private_disk_image_id": schema.StringAttribute{Optional: true},
					"preset":                schema.StringAttribute{Optional: true},
				},
				PlanModifiers: []planmodifier.Object{objectplanmodifier.RequiresReplace()},
			},
			"resources": schema.SingleNestedAttribute{
				Optional:    true,
				Description: "Sandbox CPU, memory, and optional disk allocation.",
				Attributes: map[string]schema.Attribute{
					"cpu":    schema.StringAttribute{Required: true},
					"memory": schema.StringAttribute{Required: true},
					"disk":   schema.StringAttribute{Optional: true},
				},
				PlanModifiers: []planmodifier.Object{objectplanmodifier.RequiresReplace()},
			},
			"labels": schema.MapAttribute{
				Optional:      true,
				ElementType:   types.StringType,
				Description:   "User labels. Provider-reserved labels cannot be overridden.",
				PlanModifiers: []planmodifier.Map{mapplanmodifier.RequiresReplace()},
			},
			"environment": schema.MapAttribute{
				Optional:      true,
				ElementType:   types.StringType,
				Description:   "Non-sensitive environment variables. Changes replace the Sandbox.",
				PlanModifiers: []planmodifier.Map{mapplanmodifier.RequiresReplace()},
			},
			"environment_wo": schema.MapAttribute{
				Optional:    true,
				Sensitive:   true,
				WriteOnly:   true,
				ElementType: types.StringType,
				Description: "Sensitive write-only environment variables.",
			},
			"environment_wo_version": schema.Int64Attribute{
				Optional:      true,
				Description:   "Non-sensitive version that triggers replacement when write-only environment values rotate.",
				PlanModifiers: []planmodifier.Int64{int64planmodifier.RequiresReplace()},
			},
			"connections": schema.SetAttribute{
				Optional:      true,
				ElementType:   types.StringType,
				Description:   "Sandbox connection names.",
				PlanModifiers: []planmodifier.Set{setplanmodifier.RequiresReplace()},
			},
			"auto_suspend":  autoSuspendSchema(),
			"egress_policy": egressPolicySchema(),
			"ports":         portsSchema(),
			"entrypoint": schema.ListAttribute{
				Optional:      true,
				ElementType:   types.StringType,
				PlanModifiers: []planmodifier.List{listplanmodifier.RequiresReplace()},
			},
			"command": schema.ListAttribute{
				Optional:      true,
				ElementType:   types.StringType,
				PlanModifiers: []planmodifier.List{listplanmodifier.RequiresReplace()},
			},
			"skip_egress_proxy": schema.BoolAttribute{
				Optional:      true,
				PlanModifiers: []planmodifier.Bool{boolplanmodifier.RequiresReplace()},
			},
			"customer_vnet_connection_name": optionalReplaceString(
				"SandboxGroup VNet connection used by the Sandbox.",
			),
			"vmm_type": optionalReplaceString("Advanced virtual machine monitor type."),
			"allow_resume_for_updates": schema.BoolAttribute{
				Optional:    true,
				Computed:    true,
				Default:     booldefault.StaticBool(false),
				Description: "Allow Terraform to resume a stopped Sandbox when an update requires Running state.",
			},
			"deletion_policy": schema.StringAttribute{
				Optional:    true,
				Computed:    true,
				Default:     stringdefault.StaticString("Delete"),
				Description: "Delete removes the remote Sandbox; Retain only removes Terraform state.",
				Validators: []validator.String{
					stringvalidator.OneOf("Delete", "Retain"),
				},
			},
			"id":             schema.StringAttribute{Computed: true, Description: "Service-generated Sandbox ID."},
			"resource_url":   schema.StringAttribute{Computed: true, Description: "Canonical data-plane resource URL."},
			"state":          schema.StringAttribute{Computed: true, Description: "Current operational state."},
			"stopped_reason": schema.StringAttribute{Computed: true, Description: "Reason the Sandbox stopped."},
			"stopped_at":     schema.StringAttribute{Computed: true, Description: "UTC time at which the Sandbox stopped."},
			"hostname":       schema.StringAttribute{Computed: true, Description: "Sandbox hostname."},
			"management_url": schema.StringAttribute{Computed: true, Sensitive: true, Description: "Sandbox management URL."},
			"created_at":     schema.StringAttribute{Computed: true, Description: "Sandbox creation time."},
			"region":         schema.StringAttribute{Computed: true, Description: "Service-reported Sandbox region."},
			"timeouts": timeouts.Attributes(ctx, timeouts.Opts{
				Create: true,
				Update: true,
				Delete: true,
			}),
		},
		Version: 1,
	}
}

func autoSuspendSchema() schema.SingleNestedAttribute {
	return schema.SingleNestedAttribute{
		Optional:    true,
		Description: "Automatic Sandbox suspension policy.",
		Attributes: map[string]schema.Attribute{
			"enabled": schema.BoolAttribute{
				Required: true,
			},
			"interval_seconds": schema.Int64Attribute{
				Optional: true,
				Validators: []validator.Int64{
					int64validator.AtLeast(0),
				},
			},
			"mode": schema.StringAttribute{
				Optional: true,
				Validators: []validator.String{
					stringvalidator.OneOf("Memory", "Disk"),
				},
			},
		},
	}
}

func egressPolicySchema() schema.SingleNestedAttribute {
	return schema.SingleNestedAttribute{
		Optional:    true,
		Description: "Complete Sandbox egress policy.",
		Attributes: map[string]schema.Attribute{
			"default_action": schema.StringAttribute{
				Required: true,
				Validators: []validator.String{
					stringvalidator.OneOf("Allow", "Deny"),
				},
			},
			"host_rules": schema.ListNestedAttribute{
				Optional: true,
				NestedObject: schema.NestedAttributeObject{Attributes: map[string]schema.Attribute{
					"pattern": schema.StringAttribute{Required: true},
					"action": schema.StringAttribute{
						Required: true,
						Validators: []validator.String{
							stringvalidator.OneOf("Allow", "Deny"),
						},
					},
				}},
			},
			"rules": schema.ListNestedAttribute{
				Optional: true,
				NestedObject: schema.NestedAttributeObject{Attributes: map[string]schema.Attribute{
					"name": schema.StringAttribute{Optional: true},
					"match": schema.SingleNestedAttribute{
						Required: true,
						Attributes: map[string]schema.Attribute{
							"host":    schema.StringAttribute{Required: true},
							"path":    schema.StringAttribute{Optional: true},
							"methods": schema.SetAttribute{Optional: true, ElementType: types.StringType},
						},
					},
					"action": schema.SingleNestedAttribute{
						Required: true,
						Attributes: map[string]schema.Attribute{
							"type": schema.StringAttribute{
								Required: true,
								Validators: []validator.String{
									stringvalidator.OneOf("Allow", "Deny", "Transform", "Rewrite"),
								},
							},
							"host":   schema.StringAttribute{Optional: true},
							"path":   schema.StringAttribute{Optional: true},
							"scheme": schema.StringAttribute{Optional: true},
							"headers": schema.ListNestedAttribute{
								Optional: true,
								NestedObject: schema.NestedAttributeObject{Attributes: map[string]schema.Attribute{
									"operation": schema.StringAttribute{
										Required: true,
										Validators: []validator.String{
											stringvalidator.OneOf("Set", "Insert", "Remove"),
										},
									},
									"name":  schema.StringAttribute{Required: true},
									"value": schema.StringAttribute{Optional: true, Sensitive: true},
									"value_ref": schema.SingleNestedAttribute{
										Optional: true,
										Attributes: map[string]schema.Attribute{
											"secret_ref": schema.SingleNestedAttribute{
												Optional: true,
												Attributes: map[string]schema.Attribute{
													"secret_id":  schema.StringAttribute{Required: true},
													"secret_key": schema.StringAttribute{Optional: true},
													"format":     schema.StringAttribute{Optional: true},
												},
											},
											"managed_identity_ref": schema.SingleNestedAttribute{
												Optional: true,
												Attributes: map[string]schema.Attribute{
													"identity_type": schema.StringAttribute{
														Required: true,
														Validators: []validator.String{
															stringvalidator.OneOf("SystemAssigned", "UserAssigned"),
														},
													},
													"resource":             schema.StringAttribute{Required: true},
													"identity_resource_id": schema.StringAttribute{Optional: true},
													"format":               schema.StringAttribute{Optional: true},
												},
											},
										},
									},
								}},
							},
						},
					},
				}},
			},
			"traffic_inspection": schema.StringAttribute{
				Optional: true,
				Validators: []validator.String{
					stringvalidator.OneOf("Legacy", "Full", "Partial", "None"),
				},
			},
		},
	}
}

func portsSchema() schema.MapNestedAttribute {
	return schema.MapNestedAttribute{
		Optional:    true,
		Computed:    true,
		Description: "Named Sandbox port mappings. Logical keys are Terraform-only.",
		NestedObject: schema.NestedAttributeObject{Attributes: map[string]schema.Attribute{
			"port": schema.Int64Attribute{
				Required: true,
				Validators: []validator.Int64{
					int64validator.Between(1, 65535),
				},
			},
			"protocol": schema.StringAttribute{
				Optional: true,
				Validators: []validator.String{
					stringvalidator.OneOf("Http", "Http2"),
				},
			},
			"activation_mode": schema.StringAttribute{
				Optional: true,
				Validators: []validator.String{
					stringvalidator.OneOf("Manual", "OnDemand"),
				},
			},
			"auth": schema.SingleNestedAttribute{
				Optional: true,
				Attributes: map[string]schema.Attribute{
					"anonymous": schema.BoolAttribute{Optional: true},
					"entra_id": schema.SingleNestedAttribute{
						Optional: true,
						Attributes: map[string]schema.Attribute{
							"enabled": schema.BoolAttribute{Optional: true},
							"emails":  schema.SetAttribute{Optional: true, ElementType: types.StringType},
						},
					},
				},
			},
			"ip_access_control": schema.SingleNestedAttribute{
				Optional: true,
				Attributes: map[string]schema.Attribute{
					"default_action": schema.StringAttribute{
						Required: true,
						Validators: []validator.String{
							stringvalidator.OneOf("Allow", "Deny"),
						},
					},
					"rules": schema.ListNestedAttribute{
						Optional: true,
						Validators: []validator.List{
							listvalidator.SizeAtMost(10),
						},
						NestedObject: schema.NestedAttributeObject{Attributes: map[string]schema.Attribute{
							"name": schema.StringAttribute{
								Required: true,
								Validators: []validator.String{
									stringvalidator.RegexMatches(portRuleNamePattern, "must be 1-63 alphanumeric/hyphen characters"),
								},
							},
							"action": schema.StringAttribute{
								Required: true,
								Validators: []validator.String{
									stringvalidator.OneOf("Allow", "Deny"),
								},
							},
							"priority": schema.Int64Attribute{
								Required: true,
								Validators: []validator.Int64{
									int64validator.Between(0, 1000),
								},
							},
							"source_cidrs": schema.SetAttribute{
								Required:    true,
								ElementType: types.StringType,
							},
						}},
					},
				},
			},
			"host_port": schema.Int64Attribute{Computed: true},
			"url":       schema.StringAttribute{Computed: true},
		}},
		PlanModifiers: []planmodifier.Map{mapplanmodifier.UseStateForUnknown()},
	}
}
