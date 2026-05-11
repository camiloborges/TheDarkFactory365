<#
.SYNOPSIS
    Idempotent provisioning script for the TheDarkFactory365 M365 tenant.

.DESCRIPTION
    Brings aiwhisperer.onmicrosoft.com (M365 Business Basic) to the target state
    required by all TheDarkFactory365 specifications. Safe to re-run — produces
    AlreadyExists/AlreadyCorrect for everything already in place.

    All static configuration (tenant URLs, resource names, group names, seed data)
    is loaded from config.psd1. Runtime values (home location, guest emails) are
    supplied as parameters.

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

.PARAMETER ConfigPath
    Path to the configuration file. Defaults to config.psd1 in the script directory.

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

    [ValidateScript({
        if (-not (Test-Path $_)) { throw "Config file not found: $_" }
        return $true
    })]
    [string] $ConfigPath = (Join-Path $PSScriptRoot 'config.psd1'),

    [switch] $WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─── Load configuration ──────────────────────────────────────────────────────
$cfg = Import-PowerShellDataFile -Path $ConfigPath -ErrorAction Stop

$TenantDomain = $cfg.Tenant.Domain
$AdminUrl     = $cfg.Tenant.AdminUrl
$SiteUrl      = $cfg.Site.Url

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
    $modPath = Join-Path $PSScriptRoot "modules\$mod.psm1"
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
$locationEntries = @(
    [PSCustomObject]@{ Key = 'Weather.Latitude';     Value = $Latitude.ToString();  Category = 'Weather'; Description = 'WGS84 decimal latitude of the home location' }
    [PSCustomObject]@{ Key = 'Weather.Longitude';    Value = $Longitude.ToString(); Category = 'Weather'; Description = 'WGS84 decimal longitude of the home location' }
    [PSCustomObject]@{ Key = 'Weather.Timezone';     Value = $Timezone;             Category = 'Weather'; Description = 'IANA timezone identifier, e.g. Pacific/Auckland' }
    [PSCustomObject]@{ Key = 'Weather.LocationName'; Value = $LocationName;         Category = 'Weather'; Description = 'Display name shown in the weather web part' }
    [PSCustomObject]@{ Key = 'Weather.City';         Value = $City;                 Category = 'Weather'; Description = 'City name for display purposes' }
)

$fixedEntries = $cfg.SeedData.Fixed | ForEach-Object {
    [PSCustomObject]@{ Key = $_.Key; Value = $_.Value; Category = $_.Category; Description = $_.Description }
}

$seedEntries = $locationEntries + $fixedEntries

# ─── Provisioning ────────────────────────────────────────────────────────────
$results          = @()
$appCatalogUrl    = ''
$powerPlatformUrl = ''

# App Catalog
try {
    $r = Invoke-AppCatalogProvisioning `
        -AppCatalogUrl $cfg.AppCatalog.Url `
        -Owner        $cfg.AppCatalog.Owner `
        -TimeZoneId   $cfg.AppCatalog.TimeZoneId
    $results += $r
    if ($r.Status -in @('Created', 'AlreadyExists')) {
        $appCatalogUrl = if ($r.Status -eq 'Created') { $cfg.AppCatalog.Url } else { $r.Detail }
    }
} catch {
    $results += New-ProvisioningResult -Resource 'App Catalog' -Status 'Failed' -Detail "$_"
}

# CSP — loop through all configured sources
foreach ($source in $cfg.CSP.Sources) {
    try {
        $results += Invoke-CSPProvisioning -Source $source
    } catch {
        $results += New-ProvisioningResult -Resource "CSP — $source" -Status 'Failed' -Detail "$_"
    }
}

# SharePoint site
try {
    $results += Invoke-SiteProvisioning `
        -SiteUrl   $SiteUrl `
        -SiteTitle $cfg.Site.Title `
        -SiteAlias $cfg.Site.Alias
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
    $results += Invoke-ListProvisioning `
        -SiteUrl    $SiteUrl `
        -ListName   $cfg.ConfigList.Name `
        -Categories $cfg.ConfigList.Categories
} catch {
    $results += New-ProvisioningResult -Resource 'DarkFactory-Settings list' -Status 'Failed' -Detail "$_"
}

# List permissions
try {
    $results += Invoke-ListPermissionsProvisioning `
        -SiteUrl      $SiteUrl `
        -ListName     $cfg.ConfigList.Name `
        -OwnersGroup  $cfg.Site.Groups.Owners `
        -MembersGroup $cfg.Site.Groups.Members `
        -VisitorsGroup $cfg.Site.Groups.Visitors
} catch {
    $results += New-ProvisioningResult -Resource 'DarkFactory-Settings permissions' -Status 'Failed' -Detail "$_"
}

# Seed data
try {
    $results += Invoke-ConfigSeedProvisioning `
        -SiteUrl     $SiteUrl `
        -ListName    $cfg.ConfigList.Name `
        -SeedEntries $seedEntries
} catch {
    $results += New-ProvisioningResult -Resource 'Config seed data' -Status 'Failed' -Detail "$_"
}

# Teams team + channel
try {
    $results += Invoke-TeamsProvisioning `
        -TeamName    $cfg.Teams.Name `
        -ChannelName $cfg.Teams.Channel
} catch {
    $results += New-ProvisioningResult -Resource 'DarkFactory Teams team' -Status 'Failed' -Detail "$_"
}

# Guest access
if ($GuestEmails.Count -gt 0) {
    try {
        $results += Invoke-GuestAccessProvisioning `
            -SiteUrl       $SiteUrl `
            -GuestEmails   $GuestEmails `
            -VisitorsGroup $cfg.Site.Groups.Visitors
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
$exitCode = Write-ProvisioningReport `
    -Results          $results `
    -TenantDomain     $TenantDomain `
    -AppCatalogUrl    $appCatalogUrl `
    -PowerPlatformUrl $powerPlatformUrl
exit $exitCode
