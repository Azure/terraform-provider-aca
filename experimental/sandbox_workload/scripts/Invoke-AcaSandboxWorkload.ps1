[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot "AcaSandbox.Common.ps1")

$configurationJson = $env:ACA_SANDBOX_WORKLOAD_CONFIG_JSON
$environmentJson = $env:ACA_SANDBOX_WORKLOAD_ENVIRONMENT_JSON
if ([string]::IsNullOrWhiteSpace($configurationJson)) {
    throw "ACA_SANDBOX_WORKLOAD_CONFIG_JSON was not supplied by Terraform."
}
if ([string]::IsNullOrWhiteSpace($environmentJson)) {
    throw "ACA_SANDBOX_WORKLOAD_ENVIRONMENT_JSON was not supplied by Terraform."
}

$config = $configurationJson | ConvertFrom-Json
$workloadEnvironment = $environmentJson | ConvertFrom-Json
$aca = [string]$config.aca_cli_path

Assert-AcaPrerequisites -AcaCli $aca -SubscriptionId $config.subscription_id

$commonArguments = @(
    "--group", [string]$config.sandbox_group_name,
    "--resource-group", [string]$config.resource_group_name,
    "--subscription", [string]$config.subscription_id,
    "--region", [string]$config.location,
    "--output", "json"
)

$diskList = @(Invoke-AcaJson -AcaCli $aca -Arguments (@(
            "sandboxgroup", "disk", "list"
        ) + $commonArguments)) | Where-Object { $null -ne $_ }

$disk = $diskList |
    Where-Object { (Get-AcaResourceName -Resource $_) -ceq [string]$config.disk_name } |
    Sort-Object { [string](Get-PropertyValue -InputObject $_ -Name "id") } |
    Select-Object -First 1

$diskLabels = [pscustomobject][ordered]@{
    aca_image_fingerprint = [string]$config.image_fingerprint
    managed_by            = "terraform"
}

if ($disk -and -not (Test-ResourceLabels -Resource $disk -ExpectedLabels $diskLabels)) {
    throw "Disk '$($config.disk_name)' already exists but was not created for immutable image fingerprint $($config.image_fingerprint). Choose a different disk_name; existing disks are never changed or deleted."
}

if (-not $disk) {
    Write-Host "Importing immutable image into Sandbox disk '$($config.disk_name)'."
    $createArguments = @(
        "sandboxgroup", "disk", "create",
        "--name", [string]$config.disk_name,
        "--image", [string]$config.image_reference,
        "--label", "aca_image_fingerprint=$($config.image_fingerprint)",
        "--label", "managed_by=terraform"
    )
    if (-not [string]::IsNullOrWhiteSpace([string]$config.disk_import_identity)) {
        $createArguments += @("--identity", [string]$config.disk_import_identity)
    }
    $createArguments += $commonArguments

    $authenticationFailurePattern = "(?i)(\b401\b|\b403\b|unauthorized|forbidden|authentication failed|authorization failed|access denied|invalid credential|credential.{0,40}(invalid|expired)|token.{0,40}(invalid|expired)|managed identity.{0,80}(unauthorized|forbidden|access denied|failed to authenticate))"
    $managedIdentityError = $null
    $retryDeadline = [DateTime]::UtcNow.AddSeconds(
        [int]$config.registry_auth_retry_timeout_seconds
    )
    $retryDelaySeconds = 10

    do {
        try {
            $disk = Invoke-AcaCreateOnce -AcaCli $aca -Arguments $createArguments
            $managedIdentityError = $null
            break
        }
        catch {
            $managedIdentityError = $_
            $diskList = @(Invoke-AcaJson -AcaCli $aca -Arguments (@(
                        "sandboxgroup", "disk", "list"
                    ) + $commonArguments)) | Where-Object { $null -ne $_ }
            $disk = $diskList |
                Where-Object {
                    (Get-AcaResourceName -Resource $_) -ceq [string]$config.disk_name -and
                    (Test-ResourceLabels -Resource $_ -ExpectedLabels $diskLabels)
                } |
                Sort-Object { [string](Get-PropertyValue -InputObject $_ -Name "id") } |
                Select-Object -First 1
            if ($disk) {
                $managedIdentityError = $null
                break
            }

            $canRetry = (
                $managedIdentityError.Exception.Message -match $authenticationFailurePattern -and
                [DateTime]::UtcNow.AddSeconds($retryDelaySeconds) -le $retryDeadline
            )
            if (-not $canRetry) {
                break
            }

            Write-Host "Sandbox Group registry authorization is not ready; retrying managed-identity disk import in $retryDelaySeconds seconds."
            Start-Sleep -Seconds $retryDelaySeconds
            $retryDelaySeconds = [Math]::Min(30, $retryDelaySeconds * 2)
        }
    } while ($true)

    if ($managedIdentityError) {
        if (-not [bool]$config.allow_registry_fallback) {
            throw "Sandbox disk import failed and registry-token fallback is disabled. Verify the Sandbox Group identity has AcrPull. Original error: $($managedIdentityError.Exception.Message)"
        }

        if ($managedIdentityError.Exception.Message -notmatch $authenticationFailurePattern) {
            throw "Managed-identity disk import failed for a non-authentication reason; registry-token fallback was not attempted. Original error: $($managedIdentityError.Exception.Message)"
        }
        if ([string]::IsNullOrWhiteSpace([string]$config.registry_name)) {
            throw "registry_name is required for the explicitly enabled registry-token fallback."
        }
        if (-not (Get-Command "az" -ErrorAction SilentlyContinue)) {
            throw "Azure CLI is required for the explicitly enabled ACR token fallback."
        }

        $azureStatus = Invoke-CapturedNative -FilePath "az" -Arguments @(
            "account", "show",
            "--subscription", [string]$config.subscription_id,
            "--output", "none",
            "--only-show-errors"
        )
        if ($azureStatus.ExitCode -ne 0) {
            throw "Azure CLI is not authenticated for subscription $($config.subscription_id). The module never performs interactive login."
        }

        Write-Warning "Using the explicitly enabled ACR token fallback. aca 1.0.0-beta.1 accepts the token only as a process argument, which is a residual local process-inspection risk."
        $tokenResult = Invoke-CapturedNative -FilePath "az" -Arguments @(
            "acr", "login",
            "--name", [string]$config.registry_name,
            "--subscription", [string]$config.subscription_id,
            "--expose-token",
            "--query", "accessToken",
            "--output", "tsv",
            "--only-show-errors"
        )
        if ($tokenResult.ExitCode -ne 0) {
            throw "Azure CLI could not obtain a short-lived ACR access token: $($tokenResult.Output -join [Environment]::NewLine)"
        }
        $registryToken = ($tokenResult.Output -join "").Trim()
        if ([string]::IsNullOrWhiteSpace($registryToken)) {
            throw "Azure CLI returned an empty ACR access token."
        }

        $fallbackArguments = @(
            "sandboxgroup", "disk", "create",
            "--name", [string]$config.disk_name,
            "--image", [string]$config.image_reference,
            "--username", "00000000-0000-0000-0000-000000000000",
            "--token", $registryToken,
            "--label", "aca_image_fingerprint=$($config.image_fingerprint)",
            "--label", "managed_by=terraform"
        ) + $commonArguments
        $disk = Invoke-AcaCreateOnce -AcaCli $aca -Arguments $fallbackArguments
        $registryToken = $null
    }
}
else {
    Write-Host "Reusing Sandbox disk '$($config.disk_name)'."
}

$diskId = [string](Get-PropertyValue -InputObject $disk -Name "id")
if ([string]::IsNullOrWhiteSpace($diskId)) {
    $lookupDeadline = [DateTime]::UtcNow.AddSeconds(
        [Math]::Min(60, [int]$config.disk_ready_timeout_seconds)
    )
    do {
        Start-Sleep -Seconds 5
        $diskList = @(Invoke-AcaJson -AcaCli $aca -Arguments (@(
                    "sandboxgroup", "disk", "list"
                ) + $commonArguments)) | Where-Object { $null -ne $_ }
        $disk = $diskList |
            Where-Object {
                (Get-AcaResourceName -Resource $_) -ceq [string]$config.disk_name -and
                (Test-ResourceLabels -Resource $_ -ExpectedLabels $diskLabels)
            } |
            Sort-Object { [string](Get-PropertyValue -InputObject $_ -Name "id") } |
            Select-Object -First 1
        $diskId = [string](Get-PropertyValue -InputObject $disk -Name "id")
    } while ([string]::IsNullOrWhiteSpace($diskId) -and [DateTime]::UtcNow -lt $lookupDeadline)

    if ([string]::IsNullOrWhiteSpace($diskId)) {
        throw "Sandbox disk '$($config.disk_name)' was accepted for creation but did not become discoverable with an ID."
    }
}

$deadline = [DateTime]::UtcNow.AddSeconds([int]$config.disk_ready_timeout_seconds)
do {
    $status = Get-PropertyValue -InputObject $disk -Name "status"
    $state = [string](Get-PropertyValue -InputObject $status -Name "state")
    if ([string]::IsNullOrWhiteSpace($state) -or $state -in @("Ready", "Succeeded")) {
        break
    }
    if ($state -in @("Failed", "Error", "Canceled", "Cancelled")) {
        throw "Sandbox disk '$($config.disk_name)' entered terminal state '$state'."
    }
    if ([DateTime]::UtcNow -ge $deadline) {
        throw "Timed out waiting for Sandbox disk '$($config.disk_name)' to become ready. Last state: '$state'."
    }

    Start-Sleep -Seconds 10
    $disk = Invoke-AcaJson -AcaCli $aca -Arguments (@(
            "sandboxgroup", "disk", "get",
            "--id", $diskId
        ) + $commonArguments)
} while ($true)

$sandboxList = @(Invoke-AcaJson -AcaCli $aca -Arguments (@(
            "sandbox", "list"
        ) + $commonArguments)) | Where-Object { $null -ne $_ }
$sandbox = $sandboxList |
    Where-Object { Test-ResourceLabels -Resource $_ -ExpectedLabels $config.selector_labels } |
    Sort-Object { [string](Get-PropertyValue -InputObject $_ -Name "id") } |
    Select-Object -First 1

if ($sandbox) {
    Write-Host "Reusing Sandbox '$([string](Get-PropertyValue -InputObject $sandbox -Name "id"))' for configuration $($config.config_fingerprint)."
    return
}

$resources = [ordered]@{
    cpu    = [string]$config.resources.cpu
    memory = [string]$config.resources.memory
}
if (-not [string]::IsNullOrWhiteSpace([string](Get-PropertyValue -InputObject $config.resources -Name "disk"))) {
    $resources.disk = [string]$config.resources.disk
}

$manifest = [ordered]@{
    diskId      = $diskId
    resources   = $resources
    environment = ConvertTo-OrderedProperties -InputObject $workloadEnvironment
    labels      = ConvertTo-OrderedProperties -InputObject $config.selector_labels
    lifecycle   = [ordered]@{
        autoSuspendPolicy = [ordered]@{
            enabled  = [bool]$config.lifecycle_policy.auto_suspend_enabled
            interval = [int]$config.lifecycle_policy.auto_suspend_interval_seconds
            mode     = [string]$config.lifecycle_policy.auto_suspend_mode
        }
        autoDeletePolicy  = [ordered]@{
            enabled                 = $false
            deleteIntervalInSeconds = 0
        }
    }
    egressPolicy = [ordered]@{
        defaultAction = [string]$config.egress_policy.default_action
        hostRules     = @($config.egress_policy.host_rules)
        rules         = @($config.egress_policy.rules)
    }
    ports        = @(
        foreach ($portProperty in $config.ports.PSObject.Properties | Sort-Object Name) {
            [ordered]@{
                name = $portProperty.Name
                port = [int]$portProperty.Value.port
                auth = [ordered]@{
                    anonymous = [bool]$portProperty.Value.anonymous
                }
            }
        }
    )
}
if (@($config.entrypoint).Count -gt 0) {
    $manifest.entrypoint = @($config.entrypoint)
}
if (@($config.command).Count -gt 0) {
    $manifest.cmd = @($config.command)
}

$manifestPath = Join-Path (Get-Location).Path (
    ".aca-sandbox-workload-{0}-{1}.json" -f $PID, [Guid]::NewGuid().ToString("N")
)
try {
    $manifestJson = $manifest | ConvertTo-Json -Depth 20
    [IO.File]::WriteAllText(
        $manifestPath,
        $manifestJson,
        [Text.UTF8Encoding]::new($false)
    )

    Invoke-AcaCommand -AcaCli $aca -Arguments @(
        "sandbox", "validate",
        "--file", $manifestPath,
        "--sandbox-group", [string]$config.sandbox_group_name,
        "--resource-group", [string]$config.resource_group_name,
        "--subscription", [string]$config.subscription_id,
        "--region", [string]$config.location,
        "--output", "json"
    ) | Out-Null

    Invoke-AcaCommand -AcaCli $aca -Arguments @(
        "sandbox", "apply",
        "--file", $manifestPath,
        "--group", [string]$config.sandbox_group_name,
        "--resource-group", [string]$config.resource_group_name,
        "--subscription", [string]$config.subscription_id,
        "--region", [string]$config.location,
        "--output", "json"
    ) | Out-Null
}
finally {
    Remove-Item -LiteralPath $manifestPath -Force -ErrorAction SilentlyContinue
}

Write-Host "Created a new Sandbox for configuration $($config.config_fingerprint). Existing data-plane resources were preserved."
