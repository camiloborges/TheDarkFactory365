#Requires -Version 7
<#
.SYNOPSIS
    Builds DarkFactoryActivityAdvisor.msapp from the pac canvas source files.

.DESCRIPTION
    Uses the Power Platform CLI (pac) to pack the canvas app source directory
    into a deployable .msapp file that can be imported into Power Apps.

.PREREQUISITES
    pac CLI installed and on PATH.
    Install via winget:   winget install Microsoft.PowerPlatformCLI
    Or download from:     https://aka.ms/PowerAppsCLI

.OUTPUTS
    DarkFactoryActivityAdvisor.msapp — import at make.powerapps.com

.NOTES
    After import you MUST reconnect the SharePoint data source:
      Power Apps Studio > Data > Add data > SharePoint
      > select your DarkFactory site > DarkFactory-ActivityRequests

    The DARKFACTORY_SP_SITE_URL placeholder in pkgs/DataSources/ is replaced
    when you reconnect the data source in Studio.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputPath = Join-Path $scriptDir 'DarkFactoryActivityAdvisor.msapp'

# ── Verify pac CLI ─────────────────────────────────────────────────────────────
if (-not (Get-Command pac -ErrorAction SilentlyContinue)) {
    Write-Error @'
Power Platform CLI (pac) not found on PATH.

Install via winget:
  winget install Microsoft.PowerPlatformCLI

Or download the MSI from:
  https://aka.ms/PowerAppsCLI

After installation, reopen your terminal and re-run this script.
'@
    exit 1
}

$pacVersion = (pac --version 2>&1) | Select-Object -First 1
Write-Host "pac version: $pacVersion" -ForegroundColor Gray

# ── Pack ───────────────────────────────────────────────────────────────────────
Write-Host "`nPacking canvas app source..." -ForegroundColor Cyan
Write-Host "  Sources : $scriptDir"
Write-Host "  Output  : $outputPath`n"

pac canvas pack --sources $scriptDir --msapp $outputPath

if ($LASTEXITCODE -ne 0) {
    Write-Error "pac canvas pack failed (exit $LASTEXITCODE). See output above."
    exit $LASTEXITCODE
}

# ── Success ────────────────────────────────────────────────────────────────────
Write-Host "`n✔ Build succeeded: $outputPath" -ForegroundColor Green
Write-Host @'

Next steps
──────────
1. Open https://make.powerapps.com and select your environment.
2. Apps > Import canvas app > Upload > select DarkFactoryActivityAdvisor.msapp
3. After import, open the app in Power Apps Studio.
4. Data (left panel) > Add data > SharePoint
   > select your DarkFactory site > DarkFactory-ActivityRequests > Connect
5. Save and Publish.

The app is now wired to your SharePoint list and ready to use.
'@
