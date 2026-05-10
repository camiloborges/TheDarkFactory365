# Contract: Provisioning Script Interface
**Script**: `Invoke-DarkFactoryProvisioning.ps1` | **Date**: 2026-05-10

---

## Parameters

```powershell
param(
    # Home location — all required, no defaults (runtime values specific to each run)
    [Parameter(Mandatory)][double] $Latitude,
    [Parameter(Mandatory)][double] $Longitude,
    [Parameter(Mandatory)][string] $Timezone,       # IANA, e.g. "Pacific/Auckland"
    [Parameter(Mandatory)][string] $LocationName,   # e.g. "Home"
    [Parameter(Mandatory)][string] $City,           # e.g. "Auckland"

    # Guest accounts (optional — omit if no family members yet)
    [string[]] $GuestEmails = @(),

    # Config file path — all static values (tenant URLs, resource names, seed data)
    # Defaults to config.psd1 in the script directory; override to target a different tenant
    [string] $ConfigPath = (Join-Path $PSScriptRoot 'config.psd1'),

    # Dry run — prints what would happen; makes no changes
    [switch] $WhatIf
)
```

### Parameter Validation Rules

| Parameter | Constraint |
|---|---|
| `Latitude` | Must be a valid decimal in range -90.0 to +90.0 |
| `Longitude` | Must be a valid decimal in range -180.0 to +180.0 |
| `Timezone` | Must be a valid IANA timezone identifier (validated against `[TimeZoneInfo]` on Windows) |
| `LocationName` | Non-empty string, max 255 characters |
| `City` | Non-empty string, max 255 characters |
| `GuestEmails` | Each entry must be a valid email address format |
| `ConfigPath` | Path must exist; defaults to `config.psd1` in the script directory |

### Configuration File

All static values are declared in `config.psd1` (PowerShell Data File) alongside the script:

```
tenant-infra/
├── Invoke-DarkFactoryProvisioning.ps1
└── config.psd1     ← edit this to change tenant, resource names, or add CSP sources
```

`config.psd1` sections:
- `Tenant` — domain, admin URL
- `Site` — title, alias, URL, SharePoint group names
- `AppCatalog` — URL, owner, time zone
- `ConfigList` — list name, category choices
- `Teams` — team name, channel name
- `CSP.Sources` — array of domains to add to the CSP allowlist (add new specs' APIs here)
- `SeedData.Fixed` — non-location seed entries written to `DarkFactory-Settings`

### Example Invocations

```powershell
# Full provisioning with 2 guest accounts (uses default config.psd1)
.\Invoke-DarkFactoryProvisioning.ps1 `
    -Latitude -36.8509 `
    -Longitude 174.7645 `
    -Timezone "Pacific/Auckland" `
    -LocationName "Home" `
    -City "Auckland" `
    -GuestEmails @("spouse@gmail.com", "partner@outlook.com")

# Dry run — shows what would happen without making changes
.\Invoke-DarkFactoryProvisioning.ps1 `
    -Latitude -36.8509 -Longitude 174.7645 `
    -Timezone "Pacific/Auckland" -LocationName "Home" -City "Auckland" `
    -WhatIf

# No guest accounts
.\Invoke-DarkFactoryProvisioning.ps1 `
    -Latitude -36.8509 -Longitude 174.7645 `
    -Timezone "Pacific/Auckland" -LocationName "Home" -City "Auckland"

# Target a different config file (e.g., staging tenant)
.\Invoke-DarkFactoryProvisioning.ps1 `
    -Latitude -36.8509 -Longitude 174.7645 `
    -Timezone "Pacific/Auckland" -LocationName "Home" -City "Auckland" `
    -ConfigPath ".\config.staging.psd1"
```

---

## Output: Console

On completion, the script prints a formatted table to the console:

```
DarkFactory Provisioning Report — 2026-05-10 14:32:01 UTC
Tenant: aiwhisperer.onmicrosoft.com
=======================================================

Resource                        Status            Detail
-------------------------------- ----------------- -------------------------------------------
App Catalog                      AlreadyExists     https://aiwhisperer.sharepoint.com/sites/appcatalog
CSP — api.open-meteo.com         Created           Added to trusted sources
DarkFactory site                 Created           https://aiwhisperer.sharepoint.com/sites/DarkFactory
External sharing (tenant)        AlreadyCorrect    SharingCapability = ExternalUserAndGuestSharing
External sharing (site)          Created           Set to ExternalUserAndGuestSharing
DarkFactory-Settings list        Created           4 columns added
List permissions                 Created           Unique permissions set (Owners=FC, Members/Visitors=Read)
Seed: Weather.Latitude           Created           -36.8509
Seed: Weather.Longitude          Created           174.7645
Seed: Weather.Timezone           Created           Pacific/Auckland
Seed: Weather.LocationName       Created           Home
Seed: Weather.City               Created           Auckland
Seed: Weather.ApiBaseUrl         Created           https://api.open-meteo.com/v1/forecast
Seed: Weather.TemperatureUnit    Created           celsius
Seed: Weather.RefreshIntervalMinutes Created       5
DarkFactory Teams team           Created           ⚠ Waiting 60s for M365 Group provisioning...
General channel                  AlreadyExists     Auto-created with team
Guest: spouse@gmail.com          Created           Added to DarkFactory Visitors group
Guest: partner@outlook.com       SkippedWithWarning Account not found in tenant — invite first
Power Platform environment       AlreadyExists     https://orgXXXXXX.crm6.dynamics.com

=======================================================
Summary: 15 Created | 3 AlreadyExists/Correct | 1 SkippedWithWarning | 0 Failed
Overall: PartialSuccess (1 warning — review above)

⚠ NOTE: App Catalog was already provisioned. No propagation delay.
Report saved to: .\darkfactory-provisioning-report.txt
```

---

## Output: Report File

`darkfactory-provisioning-report.txt` is saved in the current working directory. It contains the same content as the console output in plain text format, plus:

```
App Catalog URL: https://aiwhisperer.sharepoint.com/sites/appcatalog
Power Platform Default Environment: https://orgXXXXXX.crm6.dynamics.com
```

These two URLs are recorded for use in downstream specs (Spec 001 App Catalog deployment, Spec 002 Power Automate/Logic Apps).

---

## Exit Codes

| Code | Meaning |
|---|---|
| 0 | Success — all resources provisioned or already exist |
| 1 | PartialSuccess — at least one `SkippedWithWarning` result; administrator should review |
| 2 | Failed — at least one `Failed` result; provisioning incomplete |

---

## Idempotency Contract

The script guarantees:
- Re-running against a fully provisioned tenant produces only `AlreadyExists` / `AlreadyCorrect` results and exit code 0
- Re-running NEVER overwrites existing list items (config keys), NEVER resets list permissions if already broken, NEVER duplicates the Teams team or channels
- If a resource was partially created (e.g., site exists but list does not), the script continues from the point of failure and completes remaining resources
