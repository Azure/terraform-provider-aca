[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true
Set-StrictMode -Version Latest

$configurationJson = $env:ACA_EXAMPLE_IMAGE_BUILD_JSON
if ([string]::IsNullOrWhiteSpace($configurationJson)) {
    throw "ACA_EXAMPLE_IMAGE_BUILD_JSON was not supplied by Terraform."
}
$config = $configurationJson | ConvertFrom-Json

if (-not (Get-Command "az" -ErrorAction SilentlyContinue)) {
    throw "Azure CLI was not found. This example requires an existing non-interactive Azure CLI authentication context."
}

az account show `
    --subscription $config.subscription_id `
    --output none `
    --only-show-errors
if ($LASTEXITCODE -ne 0) {
    throw "Azure CLI is not authenticated for subscription $($config.subscription_id). This example never performs interactive login."
}

$previousPreference = $PSNativeCommandUseErrorActionPreference
try {
    $PSNativeCommandUseErrorActionPreference = $false
    $existingTags = @(
        az acr repository show-tags `
            --name $config.registry_name `
            --repository $config.repository `
            --subscription $config.subscription_id `
            --output tsv `
            --only-show-errors 2>$null
    )
    $tagLookupExitCode = $LASTEXITCODE
}
finally {
    $PSNativeCommandUseErrorActionPreference = $previousPreference
}

if ($tagLookupExitCode -eq 0 -and $existingTags -contains [string]$config.tag) {
    Write-Host "Reusing ACR image $($config.repository):$($config.tag)."
    return
}

Write-Host "Building content-addressed ACR image $($config.repository):$($config.tag)."
az acr build `
    --registry $config.registry_name `
    --subscription $config.subscription_id `
    --image "$($config.repository):$($config.tag)" `
    --file (Join-Path $config.source_directory "Dockerfile") `
    --no-logs `
    --only-show-errors `
    $config.source_directory
if ($LASTEXITCODE -ne 0) {
    throw "ACR build failed for $($config.repository):$($config.tag)."
}
