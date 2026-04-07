<#
.SYNOPSIS
    Generates Terraform state migration commands for migrating a feature from AzAPI overlay to native AzureRM.

.DESCRIPTION
    When the AzureRM provider adds native support for a feature that was previously
    handled by an AzAPI overlay, this script generates the state commands needed to
    remove the overlay resource from Terraform state.

    It reads the capability registry to determine which features are migratable and
    outputs the appropriate `terraform state rm` commands.

.PARAMETER Feature
    The feature name from capability_registry.yaml (e.g., "advanced_ingress").

.PARAMETER Module
    The module name (e.g., "container_app", "container_app_environment", "jobs").

.PARAMETER ModuleInstanceName
    The Terraform module instance name as used in state (e.g., "app", "env").
    Defaults to the module name.

.PARAMETER DryRun
    If specified, prints commands without executing them. This is the default behavior.

.EXAMPLE
    .\migrate-feature.ps1 -Feature "advanced_ingress" -Module "container_app"

.EXAMPLE
    .\migrate-feature.ps1 -Feature "peer_authentication" -Module "container_app_environment" -ModuleInstanceName "env"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Feature,

    [Parameter(Mandatory = $true)]
    [string]$Module,

    [Parameter(Mandatory = $false)]
    [string]$ModuleInstanceName,

    [switch]$DryRun = $true
)

$ErrorActionPreference = "Stop"

# Resolve paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$RegistryPath = Join-Path $RepoRoot "internal" "capability_registry.yaml"

if (-not (Test-Path $RegistryPath)) {
    Write-Error "Capability registry not found at: $RegistryPath"
    exit 1
}

# Feature-to-resource mapping (AzAPI overlay resource names by module)
$OverlayResourceMap = @{
    "container_app" = @{
        "advanced_ingress" = "azapi_update_resource.advanced_ingress"
        "kind_functionapp" = "azapi_update_resource.kind_functionapp"
        "dapr_app_health"  = "azapi_update_resource.dapr_app_health"
    }
    "container_app_environment" = @{
        "peer_authentication" = "azapi_update_resource.peer_authentication"
    }
    "jobs" = @{
        "jobs_event_trigger_advanced" = "azapi_update_resource.event_trigger_advanced"
    }
}

# Validate module
if (-not $OverlayResourceMap.ContainsKey($Module)) {
    Write-Error "Unknown module: $Module. Valid modules: $($OverlayResourceMap.Keys -join ', ')"
    exit 1
}

# Validate feature
$ModuleOverlays = $OverlayResourceMap[$Module]
if (-not $ModuleOverlays.ContainsKey($Feature)) {
    Write-Error "Unknown feature '$Feature' for module '$Module'. Valid features: $($ModuleOverlays.Keys -join ', ')"
    exit 1
}

$ResourceAddress = $ModuleOverlays[$Feature]

if (-not $ModuleInstanceName) {
    $ModuleInstanceName = $Module
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " AzAPI -> AzureRM Migration: $Feature" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Module:   $Module" -ForegroundColor White
Write-Host "Feature:  $Feature" -ForegroundColor White
Write-Host "Resource: $ResourceAddress" -ForegroundColor White
Write-Host ""

# Generate state commands
Write-Host "--- State Migration Commands ---" -ForegroundColor Yellow
Write-Host ""

# The overlay uses count, so the resource address includes [0]
$StateAddress = "module.$ModuleInstanceName.$ResourceAddress[0]"

Write-Host "# Step 1: Remove the AzAPI overlay resource from state" -ForegroundColor Green
Write-Host "terraform state rm '$StateAddress'"
Write-Host ""

Write-Host "# Step 2: Verify no unexpected changes" -ForegroundColor Green
Write-Host "terraform plan"
Write-Host ""

Write-Host "# Step 3: Apply to reconcile state (if plan shows updates to base resource)" -ForegroundColor Green
Write-Host "terraform apply"
Write-Host ""

# If using for_each (root module pattern for container_apps/jobs)
if ($Module -eq "container_app" -or $Module -eq "jobs") {
    Write-Host "--- For root module with for_each ---" -ForegroundColor Yellow
    Write-Host ""
    Write-Host '# If you use the root module with for_each (e.g., var.container_apps map),' -ForegroundColor Green
    Write-Host '# the state address includes the map key:' -ForegroundColor Green
    Write-Host "terraform state rm 'module.${ModuleInstanceName}[`"<app_key>`"].${ResourceAddress}[0]'"
    Write-Host ""
    Write-Host '# Example for an app keyed as "api":' -ForegroundColor Green
    Write-Host "terraform state rm 'module.${ModuleInstanceName}[`"api`"].${ResourceAddress}[0]'"
    Write-Host ""
}

Write-Host "--- Post-Migration ---" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Update internal/capability_registry.yaml:" -ForegroundColor White
Write-Host "   - Set provider: azurerm" -ForegroundColor Gray
Write-Host "   - Set native_in_azurerm: true" -ForegroundColor Gray
Write-Host "   - Set preview: false" -ForegroundColor Gray
Write-Host "   - Clear feature_flag (or mark deprecated)" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Update module code:" -ForegroundColor White
Write-Host "   - Add feature to main.tf base resource" -ForegroundColor Gray
Write-Host "   - Remove overlay from main_azapi.tf" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Validate:" -ForegroundColor White
Write-Host "   terraform fmt -check -recursive" -ForegroundColor Gray
Write-Host "   terraform validate" -ForegroundColor Gray
Write-Host "   terraform test" -ForegroundColor Gray
Write-Host ""
