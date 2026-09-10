Set-StrictMode -Version Latest

function Invoke-CapturedNative {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $previousPreference = $PSNativeCommandUseErrorActionPreference
    try {
        $PSNativeCommandUseErrorActionPreference = $false
        $output = @(& $FilePath @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $PSNativeCommandUseErrorActionPreference = $previousPreference
    }

    [pscustomobject]@{
        ExitCode = $exitCode
        Output   = $output
    }
}

function ConvertFrom-AcaMixedJson {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object[]]$InputLines)

    $text = ($InputLines | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw "ACA command output was empty."
    }

    $starts = for ($index = 0; $index -lt $text.Length; $index++) {
        if ($text[$index] -eq '{' -or $text[$index] -eq '[') {
            $index
        }
    }
    $ends = for ($index = $text.Length - 1; $index -ge 0; $index--) {
        if ($text[$index] -eq '}' -or $text[$index] -eq ']') {
            $index
        }
    }

    foreach ($start in $starts) {
        foreach ($end in $ends) {
            if ($end -lt $start) {
                continue
            }

            try {
                $value = $text.Substring($start, $end - $start + 1) |
                    ConvertFrom-Json -ErrorAction Stop
                Write-Output $value
                return
            }
            catch {
                continue
            }
        }
    }

    throw "ACA command output did not contain a complete JSON object or array."
}

function Invoke-AcaJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$AcaCli,
        [Parameter(Mandatory)][string[]]$Arguments,
        [int]$Attempts = 6,
        [int]$DelaySeconds = 10
    )

    $lastResult = $null
    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        $lastResult = Invoke-CapturedNative -FilePath $AcaCli -Arguments $Arguments
        if ($lastResult.ExitCode -eq 0) {
            try {
                return ConvertFrom-AcaMixedJson -InputLines $lastResult.Output
            }
            catch {
                if ($attempt -eq $Attempts) {
                    throw
                }
            }
        }

        if ($attempt -lt $Attempts) {
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    throw "ACA command failed after $Attempts attempts: $($lastResult.Output -join [Environment]::NewLine)"
}

function Invoke-AcaCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$AcaCli,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $result = Invoke-CapturedNative -FilePath $AcaCli -Arguments $Arguments
    if ($result.ExitCode -ne 0) {
        throw "ACA command failed: $($result.Output -join [Environment]::NewLine)"
    }
    return $result.Output
}

function Invoke-AcaCreateOnce {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$AcaCli,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $result = Invoke-CapturedNative -FilePath $AcaCli -Arguments $Arguments
    if ($result.ExitCode -ne 0) {
        throw "ACA command failed: $($result.Output -join [Environment]::NewLine)"
    }

    try {
        return ConvertFrom-AcaMixedJson -InputLines $result.Output
    }
    catch {
        return $null
    }
}

function Assert-AcaPrerequisites {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$AcaCli,
        [Parameter(Mandatory)][string]$SubscriptionId
    )

    if (-not (Get-Command $AcaCli -ErrorAction SilentlyContinue)) {
        throw "ACA CLI '$AcaCli' was not found. Install aca 1.0.0-beta.1 before running Terraform."
    }

    $version = Invoke-CapturedNative -FilePath $AcaCli -Arguments @("--version")
    $versionText = ($version.Output -join " ").Trim()
    if ($version.ExitCode -ne 0 -or $versionText -notmatch '(^|\s)aca\s+1\.0\.0-beta\.1(\s|$)') {
        throw "This experimental module requires aca 1.0.0-beta.1; found '$versionText'."
    }

    $auth = Invoke-CapturedNative -FilePath $AcaCli -Arguments @(
        "auth", "status",
        "--subscription", $SubscriptionId,
        "--output", "json"
    )
    if ($auth.ExitCode -ne 0) {
        throw "ACA CLI is not authenticated for subscription $SubscriptionId. Authenticate before Terraform and verify with 'aca auth status --subscription $SubscriptionId'. The module never performs interactive login."
    }
}

function Get-PropertyValue {
    [CmdletBinding()]
    param(
        [AllowNull()][object]$InputObject,
        [Parameter(Mandatory)][string]$Name
    )

    if ($null -eq $InputObject) {
        return $null
    }
    if ($InputObject -is [System.Collections.IDictionary]) {
        return $InputObject[$Name]
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Get-AcaResourceName {
    [CmdletBinding()]
    param([AllowNull()][object]$Resource)

    $name = [string](Get-PropertyValue -InputObject $Resource -Name "name")
    if (-not [string]::IsNullOrWhiteSpace($name)) {
        return $name
    }

    $labels = Get-PropertyValue -InputObject $Resource -Name "labels"
    return [string](Get-PropertyValue -InputObject $labels -Name "name")
}

function Test-ResourceLabels {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Resource,
        [Parameter(Mandatory)][object]$ExpectedLabels
    )

    $resourceLabels = Get-PropertyValue -InputObject $Resource -Name "labels"
    if ($null -eq $resourceLabels) {
        return $false
    }

    foreach ($property in $ExpectedLabels.PSObject.Properties) {
        $actual = Get-PropertyValue -InputObject $resourceLabels -Name $property.Name
        if ([string]$actual -cne [string]$property.Value) {
            return $false
        }
    }
    return $true
}

function ConvertTo-OrderedProperties {
    [CmdletBinding()]
    param([AllowNull()][object]$InputObject)

    $result = [ordered]@{}
    if ($null -eq $InputObject) {
        return $result
    }

    foreach ($property in $InputObject.PSObject.Properties | Sort-Object Name) {
        $result[$property.Name] = $property.Value
    }
    return $result
}

function Join-EndpointPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Endpoint,
        [Parameter(Mandatory)][string]$Path
    )

    if ([string]::IsNullOrEmpty($Path)) {
        return $Endpoint.TrimEnd("/")
    }
    return "$($Endpoint.TrimEnd("/"))/$($Path.TrimStart("/"))"
}
