<#
.SYNOPSIS
    Provisions SharePoint data required for the DarkFactory Rain Alert system.

.DESCRIPTION
    Idempotent script that:
    1. Adds Alert.* configuration rows to DarkFactory-Settings (skips if already present)
    2. Creates the DarkFactory-AlertState list with LastSentAt DateTime column
    3. Seeds ForecastRain and CurrentRain items into DarkFactory-AlertState

    Safe to re-run: each step checks for existing data before creating.
    Requires PnP.PowerShell module and an active connection to the DarkFactory site.

.PARAMETER SiteUrl
    URL of the DarkFactory SharePoint site. Defaults to https://aiwhisperer.sharepoint.com/sites/DarkFactory

.PARAMETER RecipientId
    Teams UPN of the private message recipient. Defaults to camilo@aiwhisperer.onmicrosoft.com

.EXAMPLE
    .\Invoke-AlertSeedData.ps1

.EXAMPLE
    .\Invoke-AlertSeedData.ps1 -SiteUrl "https://contoso.sharepoint.com/sites/DarkFactory" -RecipientId "admin@contoso.onmicrosoft.com"
#>
[CmdletBinding()]
param(
    [string]$SiteUrl    = 'https://aiwhisperer.sharepoint.com/sites/DarkFactory',
    [string]$RecipientId = 'camilo@aiwhisperer.onmicrosoft.com'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step { param([string]$Message) Write-Host "`n==> $Message" -ForegroundColor Cyan }
function Write-Done  { param([string]$Message) Write-Host "    OK: $Message" -ForegroundColor Green }
function Write-Skip  { param([string]$Message) Write-Host "    SKIP: $Message (already exists)" -ForegroundColor DarkGray }

# ── 1. Connect to SharePoint site ────────────────────────────────────────────
Write-Step "Connecting to SharePoint: $SiteUrl"
Connect-PnPOnline -Url $SiteUrl -Interactive
Write-Done "Connected"

# ── 2. Seed Alert.* rows in DarkFactory-Settings ─────────────────────────────
Write-Step "Seeding Alert.* rows in DarkFactory-Settings"

$alertSeeds = @(
    @{
        Title          = 'Alert.RecipientId'
        DFValue        = $RecipientId
        DFCategory     = 'Alerts'
        DFDescription  = 'Teams UPN of private message recipient'
    },
    @{
        Title          = 'Alert.ForecastSuppressionHours'
        DFValue        = '3'
        DFCategory     = 'Alerts'
        DFDescription  = 'Hours to suppress duplicate forecast rain alerts'
    },
    @{
        Title          = 'Alert.CurrentRainSuppressionHours'
        DFValue        = '1'
        DFCategory     = 'Alerts'
        DFDescription  = 'Hours to suppress duplicate current rain alerts'
    },
    @{
        Title          = 'Alert.PollingIntervalMinutes'
        DFValue        = '5'
        DFCategory     = 'Alerts'
        DFDescription  = 'Logic App recurrence interval (update trigger manually if changed)'
    }
)

foreach ($seed in $alertSeeds) {
    $caml = "<View><Query><Where><Eq><FieldRef Name='Title'/><Value Type='Text'>$($seed.Title)</Value></Eq></Where></Query></View>"
    $existing = Get-PnPListItem -List 'DarkFactory-Settings' -Query $caml
    if (-not $existing) {
        Add-PnPListItem -List 'DarkFactory-Settings' -Values $seed | Out-Null
        Write-Done "Added $($seed.Title)"
    } else {
        Write-Skip $seed.Title
    }
}

# ── 3. Create DarkFactory-AlertState list ────────────────────────────────────
Write-Step "Creating DarkFactory-AlertState list"

$alertStateList = Get-PnPList -Identity 'DarkFactory-AlertState' -ErrorAction SilentlyContinue
if (-not $alertStateList) {
    New-PnPList -Title 'DarkFactory-AlertState' -Template GenericList | Out-Null
    Write-Done "DarkFactory-AlertState list created"
} else {
    Write-Skip 'DarkFactory-AlertState list'
}

# Add LastSentAt column if not present (idempotent — safe on re-run or partial failure)
$lastSentAtField = Get-PnPField -List 'DarkFactory-AlertState' -Identity 'LastSentAt' -ErrorAction SilentlyContinue
if (-not $lastSentAtField) {
    Add-PnPField -List 'DarkFactory-AlertState' -DisplayName 'LastSentAt' -InternalName 'LastSentAt' -Type DateTime | Out-Null
    Write-Done "LastSentAt DateTime column added to DarkFactory-AlertState"
} else {
    Write-Skip 'LastSentAt column'
}

# ── 4. Seed ForecastRain and CurrentRain items ───────────────────────────────
Write-Step "Seeding alert state items"

foreach ($alertType in @('ForecastRain', 'CurrentRain')) {
    $caml = "<View><Query><Where><Eq><FieldRef Name='Title'/><Value Type='Text'>$alertType</Value></Eq></Where></Query></View>"
    $existing = Get-PnPListItem -List 'DarkFactory-AlertState' -Query $caml
    if (-not $existing) {
        Add-PnPListItem -List 'DarkFactory-AlertState' -Values @{ Title = $alertType } | Out-Null
        Write-Done "Seeded $alertType item (LastSentAt = null)"
    } else {
        Write-Skip "$alertType item"
    }
}

# ── Summary ──────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "============================================================" -ForegroundColor White
Write-Host " SharePoint data provisioning complete." -ForegroundColor White
Write-Host " Verify at: $SiteUrl/Lists/DarkFactory-AlertState" -ForegroundColor White
Write-Host "============================================================" -ForegroundColor White
