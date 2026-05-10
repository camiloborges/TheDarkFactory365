# Research: TheDarkFactory365 Tenant Infrastructure
**Branch**: `003-tenant-infra` | **Date**: 2026-05-10 | **Phase**: 0

---

## Risks

### RISK-001 (RESOLVED ✅): Platform Gate
**Finding**: Tenant confirmed as `aiwhisperer.onmicrosoft.com`, Microsoft 365 Business Basic, with Camilo Borges as Global Administrator.
**Status**: No blocker. All provisioning tooling is available on this subscription.

### RISK-002 (RESOLVED ✅): Power Platform Environment Creation
**Finding**: M365 Business Basic does not permit creating additional Power Platform environments. Only the default environment (automatically provisioned by Microsoft) is available.
**Resolution**: FR-009 revised — the provisioning script retrieves and records the default environment URL for downstream specs. No environment creation attempted.

### RISK-003 (RESOLVED ✅): CSP Cmdlet Identity
**Finding**: The independent consultant suggested `Add-PnPTenantContentSecurityPolicy` (PnP PowerShell 2.4+). Research confirms the correct cmdlet is `Add-SPOContentSecurityPolicy` from the **SharePoint Online Management Shell** (`Microsoft.Online.SharePoint.PowerShell`). There is no `Add-PnPTenantContentSecurityPolicy` cmdlet in PnP PowerShell.
**Additional nuance**: `Add-SPOContentSecurityPolicy -Source` adds entries to the `script-src` directive (trusted JavaScript loading sources), not `connect-src` (fetch/XHR API calls). The new SharePoint CSP enforcement rolling out in 2026 targets script loading specifically. Whether `fetch()` calls from SPFx web parts to Open-Meteo are blocked by the `connect-src` directive is to be verified during Spec 001 implementation — if they are not blocked, FR-008 is a no-op at the `connect-src` level but adding the source as a script-src entry is still a valid defensive posture.
**Resolution**: Use `Add-SPOContentSecurityPolicy -Source "https://api.open-meteo.com"` via SPO Management Shell. Document that this addresses script-src; connect-src may or may not need action until Spec 001 is live.

### RISK-004 (ACCEPTED): Microsoft365DSC Excluded — YAGNI
**Finding**: Microsoft365DSC was the original candidate for tenant-level declarative configuration. It requires an Azure AD app registration + certificate-based authentication + specific Microsoft Graph and SharePoint application permissions — significant one-time setup overhead for a personal single-admin tenant.
**Resolution**: Microsoft365DSC excluded from v1 under YAGNI (Constitution Principle VI). The tenant-level settings (App Catalog + CSP) are managed via SPO Management Shell, which uses the same interactive admin session as PnP PowerShell. Microsoft365DSC should be revisited only if drift detection becomes important (e.g., multiple admins, production workloads).

---

## Decisions

### D-001: Provisioning Toolchain
**Decision**: Two PowerShell modules used within a single orchestrating script:
1. **SharePoint Online Management Shell** (`Microsoft.Online.SharePoint.PowerShell`) — for App Catalog and CSP management
2. **PnP PowerShell** (`PnP.PowerShell`) — for SharePoint site, list, Teams team, permissions, external sharing
3. **Power Apps Administration PowerShell** (`Microsoft.PowerApps.Administration.PowerShell`) — for default environment URL discovery only

**Single entry point**: `Invoke-DarkFactoryProvisioning.ps1` orchestrates both, accepts parameters, generates the completion report.

**Rationale**: This is the minimal set of official Microsoft tools that covers all provisioning requirements. Microsoft365DSC excluded (YAGNI). Teams PowerShell module not needed — `New-PnPTeamsTeam` handles Teams creation without it.

**Alternatives considered**: Microsoft365DSC (rejected: setup complexity disproportionate to one-time personal use), Azure CLI (rejected: not the platform-native tool for M365).

### D-002: SharePoint CSP Management
**Decision**: Use `Add-SPOContentSecurityPolicy -Source "https://api.open-meteo.com"` (SPO Management Shell).

Idempotency check pattern:
```powershell
$existing = Get-SPOContentSecurityPolicy | Where-Object { $_ -eq "https://api.open-meteo.com" }
if (-not $existing) { Add-SPOContentSecurityPolicy -Source "https://api.open-meteo.com" }
```

CSP enforcement status check via `Get-PnPTenant` — check `-DelayContentSecurityPolicyEnforcement` property. If enforcement is delayed or disabled, report this as a warning rather than an error.

**Rationale**: `Add-SPOContentSecurityPolicy` is the official SharePoint Online Management Shell cmdlet for managing trusted script sources. The connect-src question (for fetch() calls) is deferred to Spec 001 verification.

### D-003: App Catalog Provisioning
**Decision**: Use `Get-PnPTenantAppCatalogUrl` to check for existing catalog. If absent, `Register-PnPAppCatalogSite` creates it.

```powershell
$catalogUrl = Get-PnPTenantAppCatalogUrl
if (-not $catalogUrl) {
    Register-PnPAppCatalogSite -Url "https://aiwhisperer.sharepoint.com/sites/appcatalog" `
        -Owner "camilo.borges@aiwhisperer.onmicrosoft.com" -TimeZoneId 17
    # 17 = Auckland; use Get-PnPTimeZoneId for other zones
}
```

**Propagation delay**: 15–30 minutes on first creation. The completion report MUST flag this: "App Catalog created — SPFx deployment requires waiting 30 minutes before running Spec 001 deployment."

**Rationale**: `Register-PnPAppCatalogSite` is confirmed to work on M365 Business Basic. The App Catalog URL (`/sites/appcatalog`) cannot be customised during programmatic creation.

### D-004: SharePoint Site and Teams Team Provisioning — Wait/Retry Patterns
**Decision**: M365 Group-backed site creation and Teams team creation are asynchronous. Both require explicit wait loops.

**Site wait pattern** (after `New-PnPSite -Type TeamSite`):
```powershell
$maxAttempts = 10; $attempt = 0
do {
    Start-Sleep -Seconds 15
    $site = try { Get-PnPSite -Url $siteUrl -ErrorAction Stop } catch { $null }
    $attempt++
} while (-not $site -and $attempt -lt $maxAttempts)
```

**Teams team wait pattern** (after `New-PnPTeamsTeam`):
- Wait 60 seconds minimum after creation before any channel operations
- Do NOT pass `-Members` or `-Owners` during initial `New-PnPTeamsTeam` call — add them afterward to reduce provisioning lag
- General channel is auto-created; checking for its existence: `Get-PnPTeamsChannel -Team $teamId | Where-Object { $_.DisplayName -eq "General" }`
- Do NOT attempt `New-PnPTeamsChannel -DisplayName "General"` — this errors if the channel already exists; check first

**Rationale**: Without wait loops, re-runs on a partially provisioned tenant produce false "not found" errors and duplicate resources. Confirmed pattern from PnP PowerShell GitHub issues #3964 and #4757.

### D-005: External Sharing for Guest Access
**Decision**: Two-level configuration required — tenant level and site level.

```powershell
# Tenant level (if not already set)
Set-PnPTenant -SharingCapability "ExternalUserAndGuestSharing" -EnableAzureADB2BIntegration $true

# Site level
Set-PnPTenantSite -Url $darkFactorySiteUrl -Sharing "ExternalUserAndGuestSharing"
```

Both settings are idempotent (setting the same value again is a no-op). Check current value before setting to produce accurate "AlreadyCorrect" report entries.

**Guest access grants**: Add guest accounts to the site Visitors group via `Add-PnPUser -LoginName "guest@external.com" -Group "DarkFactory Visitors"`.

**Rationale**: `ExternalUserAndGuestSharing` is required to allow B2B guest accounts (personal Microsoft accounts) to access the SharePoint site. B2B integration (`EnableAzureADB2BIntegration`) ensures guests get a proper AAD identity for SharePoint access rather than an email-code link.

### D-006: List Permission Idempotency
**Decision**: Check `HasUniqueRoleAssignments` before calling `BreakRoleInheritance` to avoid resetting existing permissions on re-run.

```powershell
$list = Get-PnPList -Identity "DarkFactory-Settings"
if (-not $list.HasUniqueRoleAssignments) {
    Set-PnPList -Identity "DarkFactory-Settings" -BreakRoleInheritance -CopyRoleAssignments $false
    # Then explicitly set: Owners=Full Control, Members=Read, Visitors=Read
}
```

**New family member caveat**: Adding a new member to the M365 Group does NOT automatically grant them list-level access after inheritance is broken. The provisioning script or the administrator must re-run the guest access step when new family members are added.

**Rationale**: Calling `BreakRoleInheritance` on a list that already has unique permissions resets all assignments. The `HasUniqueRoleAssignments` guard makes the step idempotent. (Confirmed by M365 consultant review.)

### D-007: Script Architecture — Completion Report
**Decision**: Each provisioning function returns a `[PSCustomObject]` with three properties: `Resource` (string), `Status` (enum: `Created` | `AlreadyExists` | `SkippedWithWarning` | `Failed`), `Message` (string). The orchestrator collects all results and outputs:
1. Console summary table (colored by status) on completion
2. `darkfactory-provisioning-report.txt` saved to current directory

**Rationale**: Per FR-011 and SC-005 — the administrator must be able to identify what happened without reading technical logs.

### D-008: Power Platform Default Environment
**Decision**: Use `Get-AdminPowerAppEnvironment -Default` from `Microsoft.PowerApps.Administration.PowerShell`.

```powershell
$defaultEnv = Get-AdminPowerAppEnvironment -Default
$envUrl = $defaultEnv.Properties.LinkedEnvironmentMetadata.InstanceUrl
```

Record in the completion report: `"Default Power Platform environment: $envUrl"`. No environment is created (FR-009 revised — Business Basic cannot create additional environments).

**Rationale**: This is the only Power Platform action available on Business Basic — reading the default environment URL for downstream spec reference.

### D-009: Required PowerShell Modules and Versions
| Module | Minimum Version | Install Command |
|---|---|---|
| `PnP.PowerShell` | 2.12+ (PowerShell 7.4+) | `Install-Module PnP.PowerShell -Scope CurrentUser` |
| `Microsoft.Online.SharePoint.PowerShell` | Latest | `Install-Module Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser` |
| `Microsoft.PowerApps.Administration.PowerShell` | Latest | `Install-Module Microsoft.PowerApps.Administration.PowerShell -Scope CurrentUser` |
| PowerShell | 7.4+ | winget install Microsoft.PowerShell |

### D-010: Authentication Strategy
**Decision**: Interactive browser-based authentication for all connections.
- PnP PowerShell: `Connect-PnPOnline -Url $adminUrl -Interactive`
- SPO Management Shell: `Connect-SPOService -Url $adminUrl`
- Power Apps module: `Add-PowerAppsAccount` (triggers interactive browser login)

All three connections are established at the start of the script. A service principal is NOT required (YAGNI for a single-admin personal tenant).

**Rationale**: Interactive auth uses the Global Administrator's existing MFA session. No app registration, no certificate management. Appropriate for a one-time personal provisioning script.
