$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot "AcaSandbox.Common.ps1")

$queryText = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($queryText)) {
    throw "Terraform external data query was empty."
}
$query = $queryText | ConvertFrom-Json
$aca = [string]$query.aca_cli_path

Assert-AcaPrerequisites -AcaCli $aca -SubscriptionId $query.subscription_id

$commonArguments = @(
    "--group", [string]$query.sandbox_group_name,
    "--resource-group", [string]$query.resource_group_name,
    "--subscription", [string]$query.subscription_id,
    "--region", [string]$query.location,
    "--output", "json"
)

$expectedDiskLabels = [pscustomobject][ordered]@{
    aca_image_fingerprint = [string]$query.image_fingerprint
    managed_by            = "terraform"
}
$diskList = @(Invoke-AcaJson -AcaCli $aca -Arguments (@(
            "sandboxgroup", "disk", "list"
        ) + $commonArguments)) | Where-Object { $null -ne $_ }
$disk = $diskList |
    Where-Object {
        (Get-AcaResourceName -Resource $_) -ceq [string]$query.disk_name -and
        (Test-ResourceLabels -Resource $_ -ExpectedLabels $expectedDiskLabels)
    } |
    Sort-Object { [string](Get-PropertyValue -InputObject $_ -Name "id") } |
    Select-Object -First 1
if (-not $disk) {
    throw "No matching Sandbox disk '$($query.disk_name)' exists for image fingerprint $($query.image_fingerprint)."
}

$selectorLabels = $query.selector_labels_json | ConvertFrom-Json
$sandboxList = @(Invoke-AcaJson -AcaCli $aca -Arguments (@(
            "sandbox", "list"
        ) + $commonArguments)) | Where-Object { $null -ne $_ }
$sandbox = $sandboxList |
    Where-Object { Test-ResourceLabels -Resource $_ -ExpectedLabels $selectorLabels } |
    Sort-Object { [string](Get-PropertyValue -InputObject $_ -Name "id") } |
    Select-Object -First 1
if (-not $sandbox) {
    throw "No Sandbox exists for configuration fingerprint $($query.config_fingerprint)."
}

$sandboxId = [string](Get-PropertyValue -InputObject $sandbox -Name "id")
$sandboxPorts = @(Get-PropertyValue -InputObject $sandbox -Name "ports")
if ($sandboxPorts.Count -eq 0) {
    $sandbox = Invoke-AcaJson -AcaCli $aca -Arguments (@(
            "sandbox", "get",
            "--id", $sandboxId
        ) + $commonArguments)
    $sandboxPorts = @(Get-PropertyValue -InputObject $sandbox -Name "ports")
}

$requestedPorts = $query.ports_json | ConvertFrom-Json
$portUrls = [ordered]@{}
foreach ($requested in $requestedPorts.PSObject.Properties | Sort-Object Name) {
    $matchingPort = $sandboxPorts |
        Where-Object {
            $returnedName = [string](Get-PropertyValue -InputObject $_ -Name "name")
            $returnedNumber = [int](Get-PropertyValue -InputObject $_ -Name "port")
            ($returnedName -ceq $requested.Name) -or
            ($returnedNumber -eq [int]$requested.Value.port)
        } |
        Select-Object -First 1

    $url = [string](Get-PropertyValue -InputObject $matchingPort -Name "url")
    if ([string]::IsNullOrWhiteSpace($url)) {
        throw "Sandbox '$sandboxId' did not return an endpoint URL for named port '$($requested.Name)' ($($requested.Value.port))."
    }
    if ($url -notmatch '^https?://') {
        $url = "https://$url"
    }
    $portUrls[$requested.Name] = $url.TrimEnd("/")
}

$primaryPortUrl = [string]$portUrls[[string]$query.primary_port_name]
if ([string]::IsNullOrWhiteSpace($primaryPortUrl)) {
    throw "Primary port '$($query.primary_port_name)' was not resolved."
}

[ordered]@{
    sandbox_id          = $sandboxId
    disk_id             = [string](Get-PropertyValue -InputObject $disk -Name "id")
    disk_name           = [string]$query.disk_name
    port_urls_json      = ($portUrls | ConvertTo-Json -Compress)
    primary_port_url    = $primaryPortUrl
    mcp_url             = Join-EndpointPath -Endpoint $primaryPortUrl -Path ([string]$query.mcp_path)
    health_url          = Join-EndpointPath -Endpoint $primaryPortUrl -Path ([string]$query.health_path)
    selector_labels_json = ($selectorLabels | ConvertTo-Json -Compress)
    config_fingerprint  = [string]$query.config_fingerprint
} | ConvertTo-Json -Compress
