# Quickstart: Rain Alert Automation
**Branch**: `002-rain-alert-automation` | **Date**: 2026-05-10

---

## Prerequisites

### Completed specs
- **Spec 001** — Weather Display System deployed (DarkFactory SPFx web part in App Catalog, `DarkFactory-Settings` list seeded with `Weather.*` keys)
- **Spec 003** — Tenant Infrastructure provisioned (DarkFactory SharePoint site, Teams team, and settings list exist)

### Azure subscription
The Logic App requires an Azure subscription linked to the `aiwhisperer.onmicrosoft.com` tenant.

```
1. Go to https://portal.azure.com
2. Sign in as the Global Administrator (Camilo Borges)
3. If no subscription exists: search "Subscriptions" → Add → Pay-As-You-Go
   (Estimated cost: < $2/month for this Logic App at 5-min polling)
4. Ensure the subscription is associated with the aiwhisperer.onmicrosoft.com directory
```

### Gather these values before deployment

| Value | Where to find |
|---|---|
| Administrator Teams UPN | Microsoft 365 admin centre → Users → your account → User principal name |
| Azure subscription ID | Azure portal → Subscriptions |
| Azure region | Choose region closest to you (e.g., `australiaeast` for New Zealand) |

---

## Deploy: Azure Resources

### 1. Create resource group

```bash
az login --tenant aiwhisperer.onmicrosoft.com
az group create --name rg-darkfactory --location australiaeast
```

### 2. Create Logic App (Consumption plan)

```bash
az logic workflow create \
  --resource-group rg-darkfactory \
  --name la-darkfactory-rain-alert \
  --location australiaeast \
  --definition @specs/002-rain-alert-automation/logic-app-definition.json
```

Or via Azure portal:
1. Search "Logic Apps" → Create
2. Resource group: `rg-darkfactory`
3. Name: `la-darkfactory-rain-alert`
4. Plan type: **Consumption**
5. Region: `Australia East` (or nearest)

### 3. Authorise connections (one-time)

In the Logic App designer:
1. Open the **SharePoint** connection → Sign in as the Global Administrator (Camilo Borges)
2. Open the **Microsoft Teams** connection → Sign in as the same account
3. Both connections are saved as Azure resources and reused on every run

---

## Deploy: SharePoint Data

### Extend DarkFactory-Settings with Alert.* keys

Connect to the DarkFactory site and add the four configuration rows:

```powershell
Connect-PnPOnline -Url "https://aiwhisperer.sharepoint.com/sites/DarkFactory" -Interactive

$alertSeeds = @(
    @{ Title = "Alert.RecipientId";                DFValue = "camilo@aiwhisperer.onmicrosoft.com"; DFCategory = "Alerts"; DFDescription = "Teams UPN of private message recipient" },
    @{ Title = "Alert.ForecastSuppressionHours";   DFValue = "3";    DFCategory = "Alerts"; DFDescription = "Hours to suppress duplicate forecast rain alerts" },
    @{ Title = "Alert.CurrentRainSuppressionHours"; DFValue = "1";   DFCategory = "Alerts"; DFDescription = "Hours to suppress duplicate current rain alerts" },
    @{ Title = "Alert.PollingIntervalMinutes";      DFValue = "5";   DFCategory = "Alerts"; DFDescription = "Logic App recurrence interval (update trigger manually if changed)" }
)

foreach ($seed in $alertSeeds) {
    $existing = Get-PnPListItem -List "DarkFactory-Settings" -Query "<View><Query><Where><Eq><FieldRef Name='Title'/><Value Type='Text'>$($seed.Title)</Value></Eq></Where></Query></View>"
    if (-not $existing) {
        Add-PnPListItem -List "DarkFactory-Settings" -Values $seed
        Write-Host "Added: $($seed.Title)"
    } else {
        Write-Host "Already exists: $($seed.Title)"
    }
}
```

### Create DarkFactory-AlertState list

```powershell
Connect-PnPOnline -Url "https://aiwhisperer.sharepoint.com/sites/DarkFactory" -Interactive

$list = Get-PnPList -Identity "DarkFactory-AlertState" -ErrorAction SilentlyContinue
if (-not $list) {
    New-PnPList -Title "DarkFactory-AlertState" -Template GenericList
    Add-PnPField -List "DarkFactory-AlertState" -DisplayName "LastSentAt" -InternalName "LastSentAt" -Type DateTime
    Write-Host "DarkFactory-AlertState list created"

    # Seed the two alert type items
    Add-PnPListItem -List "DarkFactory-AlertState" -Values @{ Title = "ForecastRain" }
    Add-PnPListItem -List "DarkFactory-AlertState" -Values @{ Title = "CurrentRain" }
    Write-Host "Alert state items seeded"
} else {
    Write-Host "DarkFactory-AlertState already exists"
}
```

---

## Enable the Logic App

After all connections are authorised and data is in place:

```
Azure portal → Logic Apps → la-darkfactory-rain-alert → Enable
```

The Recurrence trigger fires immediately on enable, then every 5 minutes.

---

## Verify Deployment

### Check the first run

```
Azure portal → la-darkfactory-rain-alert → Run history
```

The first run should show **Succeeded**. If it shows **Failed**, check the action that failed in the run detail view.

### Confirm settings were read

In the run detail, expand "Get items — DarkFactory-Settings". Confirm the response includes `Alert.RecipientId` and `Weather.Latitude`.

### Confirm alerting works

To force a test without waiting for rain:
1. Temporarily set `Alert.CurrentRainSuppressionHours` to `0` in DarkFactory-Settings
2. Wait for the next run (up to 5 minutes)
3. If it is currently raining, you will receive a Teams message
4. Restore `Alert.CurrentRainSuppressionHours` to `1`

Or: trigger the Logic App manually from the Azure portal (Run trigger → Run).

---

## Deployment Verification Checklist

- [ ] Logic App `la-darkfactory-rain-alert` exists in `rg-darkfactory`
- [ ] SharePoint and Teams connections show as **Connected** (green) in Logic App connections
- [ ] `DarkFactory-AlertState` list exists with `ForecastRain` and `CurrentRain` items
- [ ] `DarkFactory-Settings` contains all four `Alert.*` rows with correct values
- [ ] First Logic App run history shows **Succeeded**
- [ ] Run detail shows Open-Meteo API returned HTTP 200
- [ ] On a rain day: Teams private message received within 5 minutes of the polling cycle

---

## Troubleshooting

**Run shows Failed — "Invalid connection" for SharePoint or Teams**
The OAuth connection expired or was revoked. In the Logic App designer, re-authorise the affected connection by clicking Sign In and completing MFA.

**Run shows Failed — "HTTP 4xx" on Open-Meteo action**
Check the request URL in the run detail. If latitude/longitude values are empty, confirm `Weather.Latitude` and `Weather.Longitude` exist in `DarkFactory-Settings`.

**No Teams message on a rainy day**
Check if the suppression window is active: open `DarkFactory-AlertState` in SharePoint and check `LastSentAt` for `CurrentRain`. If the timestamp is within the last hour, the alert is suppressed by design. Wait for the window to expire and confirm the next run sends it.

**Teams message not received but run shows Succeeded**
The message may have been delivered to the wrong chat. Check that `Alert.RecipientId` in DarkFactory-Settings matches your exact Teams UPN. Also check Teams notification settings — "Other" or "Meeting chat" messages may be muted.

**Logic App charges higher than expected**
Enable the Logic Apps diagnostic logs in Azure Monitor to see per-action costs. The most expensive actions are the Teams and SharePoint managed connector calls (~$0.000125 each). At 5-minute polling with ~6 managed connector actions per run: 288 runs/day × 6 actions × $0.000125 = ~$0.22/day maximum.

---

## Cost Reference

| Component | Cost |
|---|---|
| Logic Apps Consumption triggers + built-in (HTTP) actions | Free (within free tier limit) |
| SharePoint managed connector actions | ~$0.000125/action |
| Teams managed connector actions | ~$0.000125/action |
| **Estimated monthly total** | **$0.50 – $2.00** |

Costs verified at [Azure Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/) — subject to change.
