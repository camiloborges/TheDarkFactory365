# Contract: SharePoint List — DarkFactory-ActivityRequests

**Owner**: Spec 003 provisioning extension (`src/tenant-infra/`)
**Consumers**: Power Apps canvas app, Logic App (Option A), Power Automate (Option B + notification flow)
**Date**: 2026-05-28

---

## List Identity

| Property | Value |
|---|---|
| List name | `DarkFactory-ActivityRequests` |
| Site | `DarkFactory` (existing, provisioned by Spec 003) |
| List template | Generic list (100) |
| Versioning | Disabled (not required for this use case) |

---

## Columns

| Internal name | Display name | Type | Required | Choices / Notes |
|---|---|---|---|---|
| `Title` | Title | Single line of text | Yes | Auto-set to `"{Activity} @ {Location}"` by canvas app |
| `Activity` | Activity | Single line of text | Yes | Free text; canvas app enforces the dropdown |
| `Location` | Location | Single line of text | Yes | City name |
| `RequestedDateTime` | Requested Date & Time | Date and Time | Yes | Date + time format |
| `Status` | Status | Choice | Yes | `Pending` (default), `Complete`, `Error` |
| `RiskLevel` | Risk Level | Choice | No | `Safe`, `Caution`, `Unsafe` — empty until assessment completes |
| `AssessmentReason` | Assessment Reason | Multiple lines of text (plain) | No | Empty until assessment completes |
| `RequestedBy` | Requested By | Person or Group | Yes | Set by canvas app using `User()` |

---

## Provisioning Script (PnP PowerShell pattern)

```powershell
# Guard: idempotent — skip if list already exists
if (-not (Get-PnPList -Identity "DarkFactory-ActivityRequests" -ErrorAction SilentlyContinue)) {
    New-PnPList -Title "DarkFactory-ActivityRequests" -Template GenericList

    Add-PnPField -List "DarkFactory-ActivityRequests" -DisplayName "Activity"          -InternalName "Activity"          -Type Text      -Required
    Add-PnPField -List "DarkFactory-ActivityRequests" -DisplayName "Location"          -InternalName "Location"          -Type Text      -Required
    Add-PnPField -List "DarkFactory-ActivityRequests" -DisplayName "RequestedDateTime" -InternalName "RequestedDateTime" -Type DateTime  -Required
    Add-PnPField -List "DarkFactory-ActivityRequests" -DisplayName "RiskLevel"         -InternalName "RiskLevel"         -Type Choice    -Choices @("Safe","Caution","Unsafe")
    Add-PnPField -List "DarkFactory-ActivityRequests" -DisplayName "AssessmentReason"  -InternalName "AssessmentReason"  -Type Note
    Add-PnPField -List "DarkFactory-ActivityRequests" -DisplayName "RequestedBy"       -InternalName "RequestedBy"       -Type User      -Required

    # Status column with default
    $statusChoices = @("Pending","Complete","Error")
    Add-PnPFieldFromXml -List "DarkFactory-ActivityRequests" -FieldXml @"
<Field Type="Choice" DisplayName="Status" Required="TRUE" Default="Pending" Name="Status">
  <CHOICES>
    <CHOICE>Pending</CHOICE>
    <CHOICE>Complete</CHOICE>
    <CHOICE>Error</CHOICE>
  </CHOICES>
</Field>
"@

    # Index Status for efficient trigger/query
    Set-PnPField -List "DarkFactory-ActivityRequests" -Identity "Status" -Values @{ Indexed = $true }

    Write-Host "[OK] DarkFactory-ActivityRequests list provisioned"
} else {
    Write-Host "[SKIP] DarkFactory-ActivityRequests already exists"
}
```

---

## Access Control

- Canvas app users: Contribute (read + add + edit own items)
- Logic App / PA service principal: Contribute (read + edit all items — needed to write back RiskLevel/AssessmentReason/Status)
- Site owners: Full control

---

## Canvas App Read Pattern

```
// PowerFx — load current user's last 5 requests
ClearCollect(
    colMyRequests,
    Sort(
        Filter(
            'DarkFactory-ActivityRequests',
            RequestedBy.Email = User().Email
        ),
        Created,
        SortOrder.Descending
    )
);
```

---

## Logic App / PA Write Pattern

On successful assessment, the automation updates three fields on the existing item:

```json
{
  "Status": { "Value": "Complete" },
  "RiskLevel": { "Value": "@{body('Parse_JSON')?['risk']}" },
  "AssessmentReason": "@{body('Parse_JSON')?['reason']}"
}
```

On failure:
```json
{
  "Status": { "Value": "Error" }
}
```
