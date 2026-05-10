# Data Model: TheDarkFactory365 Tenant Infrastructure
**Branch**: `003-tenant-infra` | **Date**: 2026-05-10

All models are PowerShell classes / PSCustomObjects. No database. State is the tenant itself.

---

## ProvisioningStatus (Enum)

```powershell
# Used as [string] values in PSCustomObjects throughout
$ProvisioningStatus = @{
    Created             = 'Created'             # Resource did not exist; now created
    AlreadyExists       = 'AlreadyExists'       # Resource found; no action taken
    AlreadyCorrect      = 'AlreadyCorrect'      # Setting was already at desired value
    SkippedWithWarning  = 'SkippedWithWarning'  # Could not complete; non-fatal
    Failed              = 'Failed'              # Error; provisioning incomplete for this resource
}
```

---

## ProvisioningResult

```powershell
# Returned by every provisioning function
[PSCustomObject]@{
    Resource    = [string]   # Human-readable name, e.g. "App Catalog", "DarkFactory-Settings list"
    Status      = [string]   # One of the ProvisioningStatus values above
    Detail      = [string]   # Specific detail: URL created, key skipped, error message, etc.
}
```

---

## ProvisioningReport

```powershell
# Assembled by the orchestrator from all ProvisioningResult objects
[PSCustomObject]@{
    RunAt           = [datetime]             # UTC timestamp of provisioning run
    TenantDomain    = [string]               # e.g. "aiwhisperer.onmicrosoft.com"
    Results         = [ProvisioningResult[]] # All results in execution order
    CreatedCount    = [int]                  # Count of Status = Created
    SkippedCount    = [int]                  # Count of Status = AlreadyExists + AlreadyCorrect
    WarningCount    = [int]                  # Count of Status = SkippedWithWarning
    FailedCount     = [int]                  # Count of Status = Failed
    AppCatalogUrl   = [string]               # Resolved App Catalog URL (existing or newly created)
    PowerPlatformUrl = [string]              # Default Power Platform environment InstanceUrl
    OverallStatus   = [string]              # 'Success' | 'PartialSuccess' | 'Failed'
}
```

---

## ProvisioningParameters

```powershell
# Script input parameters — passed to Invoke-DarkFactoryProvisioning.ps1
[PSCustomObject]@{
    # Required — home location (no defaults)
    Latitude        = [double]   # WGS84 decimal, e.g. -36.8509
    Longitude       = [double]   # WGS84 decimal, e.g. 174.7645
    Timezone        = [string]   # IANA timezone, e.g. "Pacific/Auckland"
    LocationName    = [string]   # Display name, e.g. "Home"
    City            = [string]   # City name, e.g. "Auckland"

    # Optional — family member guest accounts to grant Visitor access
    GuestEmails     = [string[]] # Personal Microsoft account emails, e.g. @("spouse@gmail.com")

    # Optional — dry run (no changes made; report shows what would happen)
    WhatIf          = [switch]
}
```

---

## ConfigSeedEntry

```powershell
# One row to be written to the DarkFactory-Settings SharePoint list
[PSCustomObject]@{
    Key         = [string]   # Maps to list 'Title' column (unique key)
    Value       = [string]   # Maps to list 'DFValue' column
    Category    = [string]   # 'Weather' | 'Alerts' | 'General'
    Description = [string]   # Human-readable description for the list 'DFDescription' column
}
```

**Spec 001 seed entries generated from parameters:**

| Key | Source | Category |
|---|---|---|
| `Weather.Latitude` | `-Latitude` parameter | Weather |
| `Weather.Longitude` | `-Longitude` parameter | Weather |
| `Weather.Timezone` | `-Timezone` parameter | Weather |
| `Weather.LocationName` | `-LocationName` parameter | Weather |
| `Weather.City` | `-City` parameter | Weather |
| `Weather.ApiBaseUrl` | Fixed: `https://api.open-meteo.com/v1/forecast` | Weather |
| `Weather.TemperatureUnit` | Fixed: `celsius` | Weather |
| `Weather.RefreshIntervalMinutes` | Fixed: `5` | Weather |

Location keys (first 5) are sourced from script parameters. The remaining 3 are fixed values known at script authoring time.

---

## TenantResources (target state declaration)

The desired state the provisioning script enforces:

| Resource | Type | Target state |
|---|---|---|
| App Catalog | SharePoint site | `https://aiwhisperer.sharepoint.com/sites/appcatalog` exists |
| CSP allowlist | Tenant setting | `https://api.open-meteo.com` present in trusted sources |
| DarkFactory site | SharePoint team site | `https://aiwhisperer.sharepoint.com/sites/DarkFactory` exists |
| External sharing (tenant) | Tenant setting | `ExternalUserAndGuestSharing` enabled |
| External sharing (site) | Site setting | `ExternalUserAndGuestSharing` enabled on DarkFactory site |
| DarkFactory-Settings | SharePoint list | Exists on DarkFactory site with Title/DFValue/DFDescription/DFCategory columns |
| List permissions | SharePoint list | Unique permissions: Owners=Full Control, Members=Read, Visitors=Read |
| Seed keys | List items | All 8 Spec 001 keys present (location from params, others fixed) |
| DarkFactory team | Teams team | `DarkFactory` team exists |
| General channel | Teams channel | `General` channel exists in DarkFactory team |
| Guest access | Site permissions | Each `GuestEmails` entry in DarkFactory Visitors group |
| Power Platform | Default environment | URL recorded in report |

---

## State Transitions

```
Script invoked
      │
      ▼
Connect (3 modules)
      │
      ├─► App Catalog: Exists? ──No──► Register ──► Wait (15 min) ──► Report[Created + propagation warning]
      │                 │Yes                                            │
      │                 └────────────────────────────────────────────► Report[AlreadyExists]
      │
      ├─► CSP: api.open-meteo.com present? ──No──► Add ──► Report[Created]
      │                                      │Yes            │
      │                                      └──────────────► Report[AlreadyExists]
      │
      ├─► DarkFactory site: Exists? ──No──► New-PnPSite ──► Wait loop ──► Report[Created]
      │                      │Yes                                           │
      │                      └─────────────────────────────────────────────► Report[AlreadyExists]
      │
      ├─► External sharing (tenant + site): check ──► Set if needed ──► Report
      │
      ├─► DarkFactory-Settings list: Exists? ──No──► New-PnPList + columns ──► Report[Created]
      │
      ├─► List permissions: HasUniqueRoleAssignments? ──No──► BreakInheritance + set ──► Report[Created]
      │                                                 │Yes ──► Report[AlreadyExists]
      │
      ├─► Seed keys: for each key, Exists? ──No──► Add-PnPListItem ──► Report[Created]
      │                             │Yes ──► Report[AlreadyExists]
      │
      ├─► Teams team: Exists? ──No──► New-PnPTeamsTeam ──► Wait 60s ──► Report[Created]
      │               │Yes ──► Report[AlreadyExists]
      │
      ├─► General channel: Exists? ──No──► New-PnPTeamsChannel ──► Report[Created]
      │                    │Yes ──► Report[AlreadyExists]
      │
      ├─► Guest access: for each email, in Visitors? ──No──► Add-PnPUser ──► Report[Created | SkippedWithWarning]
      │
      └─► Power Platform: Get-AdminPowerAppEnvironment -Default ──► Record URL ──► Report[AlreadyExists]

Generate ProvisioningReport → Console table + report file
```
