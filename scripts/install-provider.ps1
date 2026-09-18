#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [string]$ProviderVersion,
    [string]$ProviderRepository,
    [string]$TerraformPlatform,
    [string]$MirrorRoot,
    [string]$TerraformConfigPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $ProviderVersion) {
    $ProviderVersion = if ($env:ACA_TF_PROVIDER_VERSION) {
        $env:ACA_TF_PROVIDER_VERSION
    } else {
        '0.5.0-preview'
    }
}
if (-not $ProviderRepository) {
    $ProviderRepository = if ($env:ACA_TF_PROVIDER_REPOSITORY) {
        $env:ACA_TF_PROVIDER_REPOSITORY
    } else {
        'Azure/terraform-provider-aca'
    }
}
if (-not $TerraformPlatform) {
    $TerraformPlatform = $env:ACA_TF_PLATFORM
}
if (-not $TerraformPlatform) {
    $TerraformVersion = terraform version -json | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        throw 'Terraform is required to detect the provider platform.'
    }
    $TerraformPlatform = $TerraformVersion.platform
}

$SupportedPlatforms = @(
    'windows_amd64',
    'windows_arm64',
    'linux_amd64',
    'linux_arm64',
    'darwin_amd64',
    'darwin_arm64'
)
if ($TerraformPlatform -notin $SupportedPlatforms) {
    throw "Unsupported Terraform platform: $TerraformPlatform"
}

if (-not $MirrorRoot) {
    $MirrorRoot = if ($env:ACA_TF_MIRROR_ROOT) {
        $env:ACA_TF_MIRROR_ROOT
    } else {
        Join-Path $PWD '.terraform-provider-mirror'
    }
}
if (-not $TerraformConfigPath) {
    $TerraformConfigPath = if ($env:ACA_TF_CONFIG_PATH) {
        $env:ACA_TF_CONFIG_PATH
    } else {
        Join-Path $PWD 'terraform.rc'
    }
}

$MirrorRoot = [IO.Path]::GetFullPath($MirrorRoot)
$TerraformConfigPath = [IO.Path]::GetFullPath($TerraformConfigPath)
$Archive = "terraform-provider-aca_${ProviderVersion}_${TerraformPlatform}.zip"
$Checksums = "terraform-provider-aca_${ProviderVersion}_SHA256SUMS"
$ReleaseUrl = if ($env:ACA_TF_PROVIDER_RELEASE_URL) {
    $env:ACA_TF_PROVIDER_RELEASE_URL.TrimEnd('/')
} else {
    "https://github.com/${ProviderRepository}/releases/download/provider-v${ProviderVersion}"
}
$Target = Join-Path $MirrorRoot 'registry.terraform.io'
$Target = Join-Path $Target 'azure'
$Target = Join-Path $Target 'aca'
$Target = Join-Path $Target $ProviderVersion
$Target = Join-Path $Target $TerraformPlatform
$TempDirectory = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $TempDirectory | Out-Null

try {
    $ArchivePath = Join-Path $TempDirectory $Archive
    $ChecksumsPath = Join-Path $TempDirectory $Checksums
    Invoke-WebRequest -Uri "$ReleaseUrl/$Archive" -OutFile $ArchivePath
    Invoke-WebRequest -Uri "$ReleaseUrl/$Checksums" -OutFile $ChecksumsPath

    $ChecksumLine = Get-Content $ChecksumsPath |
        Where-Object { $_ -match "\s+(?:\./)?$([regex]::Escape($Archive))$" } |
        Select-Object -First 1
    if (-not $ChecksumLine) {
        throw "Checksum for $Archive was not found."
    }

    $Expected = ($ChecksumLine -split '\s+')[0].ToLowerInvariant()
    $Actual = (Get-FileHash -Algorithm SHA256 $ArchivePath).Hash.ToLowerInvariant()
    if ($Actual -ne $Expected) {
        throw 'Provider archive checksum verification failed.'
    }

    New-Item -ItemType Directory -Force -Path $Target | Out-Null
    Expand-Archive -Path $ArchivePath -DestinationPath $Target -Force

    $Extension = if ($TerraformPlatform.StartsWith('windows_')) { '.exe' } else { '' }
    $ProviderBinary = Join-Path $Target "terraform-provider-aca_v${ProviderVersion}${Extension}"
    if (-not (Test-Path -LiteralPath $ProviderBinary -PathType Leaf)) {
        throw "Provider archive did not contain $ProviderBinary."
    }

    $RunningOnWindows = [IO.Path]::DirectorySeparatorChar -eq '\'
    if (-not $RunningOnWindows) {
        chmod +x -- $ProviderBinary
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to make $ProviderBinary executable."
        }
    }
} finally {
    Remove-Item -Path $TempDirectory -Recurse -Force
}

$ConfigDirectory = Split-Path -Parent $TerraformConfigPath
New-Item -ItemType Directory -Force -Path $ConfigDirectory | Out-Null
$MirrorConfigPath = $MirrorRoot.Replace('\', '/').Replace('"', '\"')
$Config = @"
provider_installation {
  filesystem_mirror {
    path    = "$MirrorConfigPath"
    include = ["registry.terraform.io/azure/aca"]
  }
  direct {
    exclude = ["registry.terraform.io/azure/aca"]
  }
}
"@
$Utf8WithoutBom = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText($TerraformConfigPath, $Config, $Utf8WithoutBom)

Write-Host "Installed registry.terraform.io/azure/aca v$ProviderVersion for $TerraformPlatform."
Write-Host "Set TF_CLI_CONFIG_FILE=$TerraformConfigPath before running terraform init."
