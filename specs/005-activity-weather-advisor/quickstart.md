# Quickstart: Outdoor Activity Weather Advisor

**Feature**: 005-activity-weather-advisor
**Date**: 2026-05-28

---

## Prerequisites

- .NET 8 SDK installed
- Azure OpenAI resource with a `gpt-4o-mini` deployment (or OpenAI API key)
- Power Apps environment with SharePoint connector access
- SharePoint site provisioned by Spec 003 (`DarkFactory-ActivityRequests` list created — see step 1)
- Logic App `la-darkfactory-activity-advisor` deployed (Option A) — see step 3

---

## Step 1 — Provision SharePoint list

Run the extended provisioning script to create `DarkFactory-ActivityRequests`:

```powershell
cd src/tenant-infra
./Invoke-DarkFactoryProvisioning.ps1
```

The script is idempotent — safe to re-run if the list already exists. Verify in SharePoint: navigate to the DarkFactory site > Site Contents > confirm `DarkFactory-ActivityRequests` is visible with the correct columns.

Add settings to `DarkFactory-Settings`:
| Key | Value |
|---|---|
| `ActivityAdvisor.AgentEndpoint` | `http://localhost:3978` (local) or ACA URL (deployed) |
| `ActivityAdvisor.NotificationRecipient` | Your work email address |

---

## Step 2 — Run the SK Agent locally

```bash
cd src/sk-weather-agent

# Copy and fill in credentials
cp appsettings.json appsettings.local.json
# Edit appsettings.local.json:
# - Set AIServices.AzureOpenAI.DeploymentName, Endpoint, ApiKey
# - Set ActivityAdvisor.ApiKey to any test string, e.g. "dev-key-123"
```

Set user secrets (preferred over editing appsettings):
```bash
dotnet user-secrets set "AIServices:AzureOpenAI:DeploymentName" "gpt-4o-mini"
dotnet user-secrets set "AIServices:AzureOpenAI:Endpoint" "https://your-resource.openai.azure.com/"
dotnet user-secrets set "AIServices:AzureOpenAI:ApiKey" "your-key"
dotnet user-secrets set "ActivityAdvisor:ApiKey" "dev-key-123"
```

Start the agent:
```bash
dotnet run
# → Now listening on: http://localhost:3978
```

---

## Step 3 — Test the assess-activity endpoint

```bash
# Quick smoke test (should return { risk, reason })
curl -X POST http://localhost:3978/api/assess-activity \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: dev-key-123" \
  -d '{"activity":"Trail Run","location":"Wellington","datetime":"2026-05-29T08:00:00"}'

# Expected response:
# { "risk": "Safe"|"Caution"|"Unsafe", "reason": "..." }
```

Error case — unknown city:
```bash
curl -X POST http://localhost:3978/api/assess-activity \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: dev-key-123" \
  -d '{"activity":"Hiking","location":"Atlantis","datetime":"2026-05-29T10:00:00"}'

# Expected: HTTP 502, { "error": "geocoding_failed", "message": "..." }
```

---

## Step 4 — Deploy Option A Logic App

```powershell
cd src/activity-advisor

# Set parameters
$params = @{
    SharePointSiteUrl        = "https://yourtenant.sharepoint.com/sites/darkfactory"
    ActivityAdvisorApiKey    = "your-production-api-key"
    AgentEndpointUrl         = "https://sk-weather-agent.{hash}.australiaeast.azurecontainerapps.io"
}

# Deploy
az deployment group create `
  --resource-group rg-darkfactory `
  --template-file deploy/activity-advisor-logic-app.json `
  --parameters @deploy/activity-advisor-parameters.json
```

After deployment:
1. Open the Logic App in Azure Portal
2. Navigate to API connections — authorise the SharePoint connection
3. Enable the Logic App (it is deployed disabled by default)

---

## Step 5 — Import and connect the canvas app

1. Open [make.powerapps.com](https://make.powerapps.com)
2. Navigate to Apps > Import canvas app
3. Upload `src/activity-advisor/canvas-app/DarkFactoryActivityAdvisor.msapp`
4. Connect the SharePoint data source to your DarkFactory site
5. Save and publish

Test: Open the app, submit a request (e.g. "Trail Run", "Wellington", tomorrow 08:00). Verify:
- New item appears in `DarkFactory-ActivityRequests` with `Status = Pending`
- Within 3 minutes, item updates to `Status = Complete` with RiskLevel and AssessmentReason
- Teams message arrives for the submitting user

---

## Step 6 — Import the Teams notification flow

> Option B (Power Automate HTTP flow) is marked `[UNTESTED — requires PA Premium]`. The notification flow uses standard connectors only and is testable on any M365 plan.

1. Open Power Automate > My flows > Import
2. Upload `src/activity-advisor/flows/darkfactory-activity-notification.zip`
3. Connect the SharePoint and Teams connections
4. Turn on the flow

---

## Verification checklist

- [ ] `DarkFactory-ActivityRequests` list exists with all 8 columns
- [ ] `DarkFactory-Settings` has `ActivityAdvisor.AgentEndpoint` and `ActivityAdvisor.NotificationRecipient`
- [ ] `POST /api/assess-activity` returns `{ risk, reason }` for "Wellington" with real forecast data (not stub text)
- [ ] Logic App triggers within 60 seconds of a new "Pending" item
- [ ] Canvas app blocks submission with empty fields
- [ ] Teams notification arrives within 2 minutes of Status → Complete
- [ ] `[UNTESTED]` Option B flow YAML is deployed but not verified end-to-end

---

## Troubleshooting

| Symptom | Check |
|---|---|
| `geocoding_failed` for a valid city | Verify the city name matches Open-Meteo's database. Try the geocoding API directly: `https://geocoding-api.open-meteo.com/v1/search?name=Wellington&count=1` |
| Logic App stuck on "Pending" items | Confirm the LA SharePoint connection is authorised and the Logic App is enabled |
| Teams notification not arriving | Check the notification flow run history in Power Automate. Verify the `RequestedBy` field is a valid M365 user |
| SK agent returns `assessment_failed` | Check the Azure OpenAI deployment name matches `appsettings.json`. Check Azure OpenAI service quotas |
| Canvas app can't connect to SharePoint | Re-add the SharePoint data source — ensure it points to the correct DarkFactory site URL |
