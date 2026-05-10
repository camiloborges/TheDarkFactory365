# Quickstart: TheDarkFactory365 Tenant Infrastructure
**Branch**: `003-tenant-infra` | **Date**: 2026-05-10

---

## Prerequisites

### Tenant and account
- `aiwhisperer.onmicrosoft.com` Microsoft 365 Business Basic tenant
- You are the **Global Administrator** of the tenant
- Windows machine running **PowerShell 7.4+** (`winget install Microsoft.PowerShell`)

### Install required PowerShell modules (one-time)

```powershell
# PnP PowerShell (2.12+)
Install-Module PnP.PowerShell -Scope CurrentUser -Force

# SharePoint Online Management Shell
Install-Module Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser -Force

# Power Apps Administration
Install-Module Microsoft.PowerApps.Administration.PowerShell -Scope CurrentUser -Force
```

Verify:
```powershell
Get-Module PnP.PowerShell -ListAvailable | Select-Object Name, Version
```

---

## Before You Run

Gather these values — you will need them as script parameters:

| Parameter | Your value |
|---|---|
| Home latitude | e.g. `-36.8509` (negative = South) |
| Home longitude | e.g. `174.7645` (positive = East) |
| IANA timezone | e.g. `Pacific/Auckland` — find yours at [iana.org/time-zones](https://www.iana.org/time-zones) |
| Location display name | e.g. `Home` |
| City | e.g. `Auckland` |
| Family guest emails | Personal Microsoft account emails (e.g. `spouse@gmail.com`) |

**Invite guest accounts first** (if any): Guest accounts must be invited to the tenant before or after provisioning. To invite:
```powershell
Connect-MgGraph -Scopes "User.Invite.All"
New-MgInvitation -InvitedUserEmailAddress "spouse@gmail.com" `
    -InviteRedirectUrl "https://aiwhisperer.sharepoint.com/sites/DarkFactory" `
    -SendInvitationMessage $true
```

---

## Run the Provisioning Script

```powershell
# Clone or navigate to the tenant-infra/ directory
cd tenant-infra/

# Full provisioning run
.\Invoke-DarkFactoryProvisioning.ps1 `
    -Latitude -36.8509 `
    -Longitude 174.7645 `
    -Timezone "Pacific/Auckland" `
    -LocationName "Home" `
    -City "Auckland" `
    -GuestEmails @("spouse@gmail.com")
```

The script will open **three browser windows** (one per module connection) — sign in as the Global Administrator in each. MFA will be prompted as required.

**Dry run first** (recommended on first use):
```powershell
.\Invoke-DarkFactoryProvisioning.ps1 `
    -Latitude -36.8509 -Longitude 174.7645 `
    -Timezone "Pacific/Auckland" -LocationName "Home" -City "Auckland" `
    -WhatIf
```

---

## After the Run

Review `darkfactory-provisioning-report.txt` in the current directory.

### If App Catalog was newly created
The completion report will include: `⚠ App Catalog created — wait 30 minutes before Spec 001 SPFx deployment.`

Wait 30 minutes, then verify the App Catalog is accessible:
```powershell
Connect-PnPOnline -Url "https://aiwhisperer.sharepoint.com/sites/appcatalog" -Interactive
Get-PnPSite
```

### If a guest account was skipped
The guest must accept their invitation first. Once they have, re-run the script — it will add them and skip all already-provisioned resources.

---

## Verify Provisioning

Run these checks manually to confirm everything is correct:

```powershell
Connect-PnPOnline -Url "https://aiwhisperer.sharepoint.com/sites/DarkFactory" -Interactive

# DarkFactory-Settings list exists with correct columns
Get-PnPList -Identity "DarkFactory-Settings" | Select-Object Title, ItemCount
Get-PnPField -List "DarkFactory-Settings" | Select-Object InternalName, TypeDisplayName

# Seed keys are present
Get-PnPListItem -List "DarkFactory-Settings" | ForEach-Object { "$($_.FieldValues.Title) = $($_.FieldValues.DFValue)" }

# List has broken inheritance
(Get-PnPList -Identity "DarkFactory-Settings").HasUniqueRoleAssignments

# External sharing enabled
Get-PnPTenantSite -Url "https://aiwhisperer.sharepoint.com/sites/DarkFactory" | Select-Object SharingCapability
```

```powershell
Connect-PnPOnline -Url "https://aiwhisperer-admin.sharepoint.com" -Interactive

# App Catalog
Get-PnPTenantAppCatalogUrl

# CSP allowlist
Get-SPOContentSecurityPolicy
```

---

## Deployment Verification Checklist

- [ ] App Catalog URL returned by `Get-PnPTenantAppCatalogUrl`
- [ ] `api.open-meteo.com` appears in `Get-SPOContentSecurityPolicy` output
- [ ] `https://aiwhisperer.sharepoint.com/sites/DarkFactory` loads in browser
- [ ] `DarkFactory-Settings` list exists with 8 seed entries
- [ ] List `HasUniqueRoleAssignments` = `True`
- [ ] DarkFactory Teams team visible in Teams client
- [ ] General channel visible under DarkFactory team
- [ ] Guest accounts can open `https://aiwhisperer.sharepoint.com/sites/DarkFactory` in a private browser window
- [ ] `darkfactory-provisioning-report.txt` shows 0 Failed results
- [ ] Power Platform default environment URL recorded in report

---

## Troubleshooting

**"Access Denied" connecting to admin URL**
Confirm your account has the Global Administrator or SharePoint Administrator role at `https://admin.microsoft.com`.

**Teams team not appearing after provisioning**
M365 Group provisioning can take 2–5 minutes. Wait and refresh the Teams client. If still missing after 10 minutes, re-run the script — it will detect the missing team and create it.

**Guest account showing as SkippedWithWarning**
The guest email is not yet in the tenant directory. Send a B2B invitation (see "Before You Run"), wait for acceptance, then re-run.

**App Catalog SPFx deployment fails with "catalog not ready"**
Wait 30 minutes from App Catalog creation time, then retry. This is a Microsoft propagation delay — not a script error.
