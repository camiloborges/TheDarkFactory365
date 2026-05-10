<#
.SYNOPSIS
    Idempotent provisioning script for the TheDarkFactory365 M365 tenant.

.DESCRIPTION
    Brings aiwhisperer.onmicrosoft.com (M365 Business Basic) to the target state
    required by all TheDarkFactory365 specifications. Safe to re-run — produces
    AlreadyExists/AlreadyCorrect for everything already in place.

.PARAMETER Latitude
    WGS84 decimal latitude of the home location (e.g. -36.8509).

.PARAMETER Longitude
    WGS84 decimal longitude of the home location (e.g. 174.7645).

.PARAMETER Timezone
    IANA timezone identifier (e.g. "Pacific/Auckland").

.PARAMETER LocationName
    Display name for the home location (e.g. "Home").

.PARAMETER City
    City name (e.g. "Auckland").

.PARAMETER GuestEmails
    Optional array of personal Microsoft account emails to grant Visitor access.

.PARAMETER WhatIf
    Prints what would happen without making any changes.

.EXAMPLE
    .\Invoke-DarkFactoryProvisioning.ps1 `
        -Latitude -36.8509 -Longitude 174.7645 `
        -Timezone "Pacific/Auckland" -LocationName "Home" -City "Auckland" `
        -GuestEmails @("spouse@gmail.com")
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateRange(-90.0, 90.0)]
    [double] $Latitude,

    [Parameter(Mandatory)]
    [ValidateRange(-180.0, 180.0)]
    [double] $Longitude,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $Timezone,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 255)]
    [string] $LocationName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 255)]
    [string] $City,

    [ValidateScript({
        foreach ($email in $_) {
            if ($email -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
                throw "Invalid email address format: $email"
            }
        }
        return $true
    })]
    [string[]] $GuestEmails = @(),

    [switch] $WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir    = $PSScriptRoot
$TenantDomain = 'aiwhisperer.onmicrosoft.com'
$AdminUrl     = 'https://aiwhisperer-admin.sharepoint.com'
$SiteUrl      = 'https://aiwhisperer.sharepoint.com/sites/DarkFactory'

# ─── Module imports ──────────────────────────────────────────────────────────
$modules = @(
    'DarkFactory.Report',
    'DarkFactory.AppCatalog',
    'DarkFactory.CSP',
    'DarkFactory.Site',
    'DarkFactory.List',
    'DarkFactory.Teams',
    'DarkFactory.Access',
    'DarkFactory.PowerPlatform'
)

foreach ($mod in $modules) {
    $modPath = Join-Path $ScriptDir "modules\$mod.psm1"
    if (-not (Test-Path $modPath)) {
        Write-Error "Required module not found: $modPath"
        exit 2
    }
    Import-Module $modPath -Force -ErrorAction Stop
}

Write-Host "DarkFactory Provisioning — $TenantDomain" -ForegroundColor Cyan
Write-Host ('=' * 55)

# ─── Connections ─────────────────────────────────────────────────────────────
if (-not $WhatIf) {
    try {
        Write-Host "Connecting to SharePoint Online Management Shell..." -ForegroundColor Gray
        Connect-SPOService -Url $AdminUrl -ErrorAction Stop

        Write-Host "Connecting via PnP PowerShell..." -ForegroundColor Gray
        Connect-PnPOnline -Url $AdminUrl -Interactive -ErrorAction Stop

        Write-Host "Connecting to Power Apps Administration..." -ForegroundColor Gray
        Add-PowerAppsAccount -ErrorAction Stop

        Write-Host "All connections established." -ForegroundColor Green
    } catch {
        Write-Error "Connection failed: $_"
        exit 2
    }
} else {
    Write-Host "[WhatIf] Skipping tenant connections — dry run mode" -ForegroundColor Yellow
}

# ─── Seed data ───────────────────────────────────────────────────────────────
$seedEntries = @(
    [PSCustomObject]@{ Key = 'Weather.Latitude';              Value = $Latitude.ToString();                           Category = 'Weather'; Description = 'WGS84 decimal latitude of the home location' }
    [PSCustomObject]@{ Key = 'Weather.Longitude';             Value = $Longitude.ToString();                          Category = 'Weather'; Description = 'WGS84 decimal longitude of the home location' }
    [PSCustomObject]@{ Key = 'Weather.Timezone';              Value = $Timezone;                                      Category = 'Weather'; Description = 'IANA timezone identifier, e.g. Pacific/Auckland' }
    [PSCustomObject]@{ Key = 'Weather.LocationName';          Value = $LocationName;                                  Category = 'Weather'; Description = 'Display name shown in the weather web part' }
    [PSCustomObject]@{ Key = 'Weather.City';                  Value = $City;                                          Category = 'Weather'; Description = 'City name for display purposes' }
    [PSCustomObject]@{ Key = 'Weather.ApiBaseUrl';            Value = 'https://api.open-meteo.com/v1/forecast';       Category = 'Weather'; Description = 'Open-Meteo API base URL — override for staging/testing' }
    [PSCustomObject]@{ Key = 'Weather.TemperatureUnit';       Value = 'celsius';                                      Category = 'Weather'; Description = 'Temperature unit: celsius or fahrenheit' }
    [PSCustomObject]@{ Key = 'Weather.RefreshIntervalMinutes';Value = '5';                                            Category = 'Weather'; Description = 'Web part auto-refresh interval in minutes' }
)

# ─── Provisioning ────────────────────────────────────────────────────────────
$results       = @()
$appCatalogUrl = ''
$powerPlatformUrl = ''

# App Catalog
try {
    $r = Invoke-AppCatalogProvisioning
    $results += $r
    if ($r.Status -in @('Created','AlreadyExists')) {
        $appCatalogUrl = if ($r.Status -eq 'Created') { 'https://aiwhisperer.sharepoint.com/sites/appcatalog' } else { $r.Detail }
    }
} catch {
    $results += New-ProvisioningResult -Resource 'App Catalog' -Status 'Failed' -Detail "$_"
}

# CSP
try {
    $results += Invoke-CSPProvisioning -Source 'https://api.open-meteo.com'
} catch {
    $results += New-ProvisioningResult -Resource 'CSP — api.open-meteo.com' -Status 'Failed' -Detail "$_"
}

# SharePoint site
try {
    $results += Invoke-SiteProvisioning -SiteUrl $SiteUrl
} catch {
    $results += New-ProvisioningResult -Resource 'DarkFactory site' -Status 'Failed' -Detail "$_"
}

# External sharing
try {
    $results += Invoke-ExternalSharingProvisioning -SiteUrl $SiteUrl
} catch {
    $results += New-ProvisioningResult -Resource 'External sharing' -Status 'Failed' -Detail "$_"
}

# Connect PnP to the DarkFactory site for list operations
if (-not $WhatIf) {
    try {
        Connect-PnPOnline -Url $SiteUrl -Interactive -ErrorAction Stop
    } catch {
        $results += New-ProvisioningResult -Resource 'PnP connection (DarkFactory site)' -Status 'Failed' -Detail "$_"
    }
}

# Config list
try {
    $results += Invoke-ListProvisioning -SiteUrl $SiteUrl
} catch {
    $results += New-ProvisioningResult -Resource 'DarkFactory-Settings list' -Status 'Failed' -Detail "$_"
}

# List permissions
try {
    $results += Invoke-ListPermissionsProvisioning -SiteUrl $SiteUrl
} catch {
    $results += New-ProvisioningResult -Resource 'DarkFactory-Settings permissions' -Status 'Failed' -Detail "$_"
}

# Seed data
try {
    $results += Invoke-ConfigSeedProvisioning -SiteUrl $SiteUrl -SeedEntries $seedEntries
} catch {
    $results += New-ProvisioningResult -Resource 'Config seed data' -Status 'Failed' -Detail "$_"
}

# Teams team + channel
try {
    $results += Invoke-TeamsProvisioning
} catch {
    $results += New-ProvisioningResult -Resource 'DarkFactory Teams team' -Status 'Failed' -Detail "$_"
}

# Guest access
if ($GuestEmails.Count -gt 0) {
    try {
        $results += Invoke-GuestAccessProvisioning -SiteUrl $SiteUrl -GuestEmails $GuestEmails
    } catch {
        $results += New-ProvisioningResult -Resource 'Guest access' -Status 'Failed' -Detail "$_"
    }
}

# Power Platform
try {
    $ppResult = Get-PowerPlatformEnvironmentUrl
    $results += $ppResult
    if ($ppResult.Status -eq 'AlreadyExists') {
        $powerPlatformUrl = $ppResult.Detail -replace '^Default environment: ', ''
    }
} catch {
    $results += New-ProvisioningResult -Resource 'Power Platform environment' -Status 'SkippedWithWarning' -Detail "$_"
}

# ─── Report ───────────────────────────────────────────────────────────────────
Write-Host ''
Write-Host ('=' * 55)
$exitCode = Write-ProvisioningReport -Results $results -TenantDomain $TenantDomain -AppCatalogUrl $appCatalogUrl -PowerPlatformUrl $powerPlatformUrl
exit $exitCode
