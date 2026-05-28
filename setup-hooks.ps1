#Requires -Version 7
<#
.SYNOPSIS
    One-time setup: configure git to use the committed hooks in .githooks/.

.DESCRIPTION
    Runs `git config core.hooksPath .githooks` so that the pre-commit and
    pre-push secret scanning hooks are active for this repository clone.

    This must be run once per machine after cloning. It is NOT automatic —
    git does not run committed hooks without this opt-in step.

.PREREQUISITES
    Install gitleaks to enable active scanning:
      Windows : winget install gitleaks.gitleaks
      macOS   : brew install gitleaks
      Linux   : https://github.com/gitleaks/gitleaks#installing

    Without gitleaks, the hooks still run but emit a warning and allow the
    operation through. The GitHub Actions ci-secret-scan workflow is the
    safety net in that case.

.EXAMPLE
    pwsh setup-hooks.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# ── Configure git hooks path ────────────────────────────────────────────────
Push-Location $repoRoot
try {
    git config core.hooksPath .githooks
    Write-Host "Git hooks path set to .githooks/" -ForegroundColor Green
}
finally {
    Pop-Location
}

# ── macOS/Linux: ensure hooks are executable ────────────────────────────────
if ($IsLinux -or $IsMacOS) {
    Get-ChildItem -Path (Join-Path $repoRoot '.githooks') -File | ForEach-Object {
        & chmod +x $_.FullName
        Write-Host "chmod +x $($_.Name)" -ForegroundColor Gray
    }
}

# ── Check gitleaks ──────────────────────────────────────────────────────────
if (Get-Command gitleaks -ErrorAction SilentlyContinue) {
    $version = (gitleaks version 2>&1)
    Write-Host "gitleaks $version detected — scanning is active." -ForegroundColor Green
}
else {
    Write-Warning @'
gitleaks not found on PATH. Hooks will warn (not block) until it is installed.

Install gitleaks:
  Windows : winget install gitleaks.gitleaks
  macOS   : brew install gitleaks
  Linux   : https://github.com/gitleaks/gitleaks#installing

After installation, re-run this script or simply open a new terminal.
'@
}

Write-Host ""
Write-Host "Setup complete. Pre-commit and pre-push secret scanning is enabled." -ForegroundColor Cyan
Write-Host "The GitHub Actions ci-secret-scan workflow provides an additional CI gate."
