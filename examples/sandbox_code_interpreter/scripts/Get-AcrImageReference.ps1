$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true
Set-StrictMode -Version Latest

$queryText = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($queryText)) {
    throw "Terraform external data query was empty."
}
$query = $queryText | ConvertFrom-Json

if (-not (Get-Command "az" -ErrorAction SilentlyContinue)) {
    throw "Azure CLI was not found."
}

$output = @(
    az acr repository show `
        --name $query.registry_name `
        --image "$($query.repository):$($query.tag)" `
        --subscription $query.subscription_id `
        --query digest `
        --output tsv `
        --only-show-errors 2>&1
)
if ($LASTEXITCODE -ne 0) {
    throw "Unable to resolve the ACR image digest: $($output -join [Environment]::NewLine)"
}

$digest = $output |
    ForEach-Object { [string]$_ } |
    Where-Object { $_.Trim() -match '^sha256:[0-9a-fA-F]{64}$' } |
    Select-Object -Last 1
if ([string]::IsNullOrWhiteSpace($digest)) {
    throw "Azure CLI did not return a sha256 image digest."
}
$digest = $digest.Trim().ToLowerInvariant()

[ordered]@{
    digest              = $digest
    immutable_reference = "$($query.login_server)/$($query.repository)@$digest"
} | ConvertTo-Json -Compress
