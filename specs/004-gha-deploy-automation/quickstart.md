# Quickstart: GitHub Actions Deployment Automation
**Branch**: `004-gha-deploy-automation` | **Date**: 2026-05-11

---

## Prerequisites

Before this pipeline can run, the following must already exist:

- **Spec 003** provisioned: `rg-darkfactory` resource group, `la-darkfactory-rain-alert` Logic App, `DarkFactory` SharePoint site, App Catalog
- **Spec 001** App Catalog entry: The SPFx app must have been uploaded at least once (the pipeline uses `-Overwrite` but needs an initial entry to update)
- An **Azure subscription** associated with `aiwhisperer.onmicrosoft.com`
- **Global Administrator** or **SharePoint Administrator** access for granting API permissions

---

## One-Time Setup: Service Principal

This setup is performed once by the administrator. All steps run on a local machine with `az` CLI, PnP.PowerShell, and OpenSSL (or PowerShell 7) installed.

### Step 1: Create the Entra App Registration

```powershell
# Create app registration
$app = az ad app create --display-name "TheDarkFactory365-Deploy" | ConvertFrom-Json
$clientId = $app.appId
Write-Host "Client ID: $clientId"

# Create the service principal
az ad sp create --id $clientId
```

### Step 2: Generate a Self-Signed Certificate

```powershell
# Using PnP.PowerShell
Connect-PnPOnline -Url "https://aiwhisperer.sharepoint.com" -Interactive
$cert = New-PnPAzureCertificate `
    -CommonName "TheDarkFactory365-Deploy" `
    -OutPfx ".\TheDarkFactory365-Deploy.pfx" `
    -OutCer ".\TheDarkFactory365-Deploy.cer" `
    -ValidYears 2

Write-Host "Certificate thumbprint: $($cert.Thumbprint)"
```

### Step 3: Upload Certificate to App Registration

```powershell
az ad app credential reset `
    --id $clientId `
    --cert "@TheDarkFactory365-Deploy.cer" `
    --append
```

### Step 4: Configure OIDC Federated Credential (for az CLI)

```powershell
$fedCred = @{
    name        = "github-main"
    issuer      = "https://token.actions.githubusercontent.com"
    subject     = "repo:camiloborges/TheDarkFactory365:ref:refs/heads/main"
    audiences   = @("api://AzureADTokenExchange")
    description = "GitHub Actions deploy from main branch"
} | ConvertTo-Json -Compress

az ad app federated-credential create --id $clientId --parameters $fedCred
```

### Step 5: Grant Azure RBAC

```powershell
$subscriptionId = az account show --query id -o tsv
$spObjectId = az ad sp show --id $clientId --query id -o tsv

az role assignment create `
    --role "Contributor" `
    --assignee-object-id $spObjectId `
    --scope "/subscriptions/$subscriptionId/resourceGroups/rg-darkfactory"
```

### Step 6: Grant SharePoint App-Only Permissions

```powershell
# Register the app for SharePoint app-only access
# This opens a browser for admin consent
Register-PnPAzureADApp `
    -ApplicationName "TheDarkFactory365-Deploy" `
    -Tenant "aiwhisperer.onmicrosoft.com" `
    -CertificatePath ".\TheDarkFactory365-Deploy.pfx" `
    -SharePointApplicationPermissions "Sites.Selected" `
    -Interactive

# Connect as the app and grant site-level permissions
$tenantUrl = "https://aiwhisperer.sharepoint.com"
$appCatalogUrl = "$tenantUrl/sites/appcatalog"  # adjust to your App Catalog URL
$siteUrl       = "https://aiwhisperer.sharepoint.com/sites/DarkFactory"

Connect-PnPOnline -Url $tenantUrl -Interactive  # connect as admin

Grant-PnPAzureADAppSitePermission `
    -AppId $clientId `
    -DisplayName "TheDarkFactory365-Deploy" `
    -Site $appCatalogUrl `
    -Permissions "FullControl"

Grant-PnPAzureADAppSitePermission `
    -AppId $clientId `
    -DisplayName "TheDarkFactory365-Deploy" `
    -Site $siteUrl `
    -Permissions "FullControl"
```

### Step 7: Add GitHub Secrets and Variables

In the GitHub repository settings → Secrets and Variables → Actions:

**Secrets** (Settings → Secrets → New repository secret):

| Name | Value |
|---|---|
| `AZURE_CLIENT_ID` | `$clientId` from Step 1 |
| `AZURE_TENANT_ID` | Your Entra tenant ID (from `az account show --query tenantId`) |
| `AZURE_SUBSCRIPTION_ID` | Your Azure subscription ID |
| `SP_CERT_BASE64` | `[Convert]::ToBase64String([IO.File]::ReadAllBytes(".\TheDarkFactory365-Deploy.pfx"))` |
| `SP_CERT_PASSWORD` | PFX password (leave empty if none was set) |

**Variables** (Settings → Variables → New repository variable):

| Name | Value |
|---|---|
| `SHAREPOINT_SITE_URL` | `https://aiwhisperer.sharepoint.com/sites/DarkFactory` |
| `AZURE_RESOURCE_GROUP` | `rg-darkfactory` |
| `LOGIC_APP_NAME` | `la-darkfactory-rain-alert` |
| `SHAREPOINT_CONNECTION_NAME` | `connection-sharepoint-darkfactory` |
| `TEAMS_CONNECTION_NAME` | `connection-teams-darkfactory` |

---

## Verifying the Setup

### Test CI (PR check)

1. Create a test branch: `git checkout -b test-ci-pipeline`
2. Make a trivial change in `dark-factory-weather/` (e.g., add a space to a comment)
3. Push and open a PR
4. Confirm the `CI / build-and-test` check appears and passes
5. Close the PR without merging

### Test Deployment (SPFx)

1. Merge a change to `dark-factory-weather/` into `main`
2. In GitHub → Actions → `Deploy`, watch the run
3. Confirm `deploy-spfx` succeeds
4. Check the App Catalog at `https://aiwhisperer.sharepoint.com/sites/appcatalog/_layouts/15/tenantAppCatalog.aspx/manageApps` — the app version should match the new build

### Test Manual Trigger

1. GitHub → Actions → `Deploy` → `Run workflow` → `Run workflow` (from `main`)
2. All three deploy jobs should run
3. Check the Logic App deployment summary for the post-deploy reminder message

---

## Manual Gates (intentional — cannot be automated)

These steps must be performed once after the initial infrastructure deployment:

1. **Authorise Logic App connections**: Azure portal → `la-darkfactory-rain-alert` → API connections → sign in as admin for both SharePoint and Teams connections
2. **Enable Logic App**: Azure portal → `la-darkfactory-rain-alert` → Enable

The pipeline will print a reminder after every `deploy-logic-app` run until these steps are confirmed done.

---

## Troubleshooting

**`AZURE_CLIENT_ID` not found / login failed**
Confirm the secret name matches exactly. `azure/login@v2` is case-sensitive for secret references.

**`Connect-PnPOnline: Access denied`**
The service principal's SharePoint `Sites.Selected` permission may not have been admin-consented, or the site-level `Grant-PnPAzureADAppSitePermission` grant was not run. Re-run Step 6.

**`az logic workflow update` returns 404**
The resource group or Logic App does not exist. Run `Deploy-AlertInfrastructure.ps1` first (Spec 002 quickstart).

**`Add-PnPApp` fails with "App Catalog not found"**
The tenant App Catalog site does not exist or the service principal was not granted access to it. Verify Step 6 included the App Catalog URL and that Spec 003 has been provisioned.

**OIDC error: "subject does not match"**
The `workflow_dispatch` was triggered from a branch other than `main`. The federated credential subject is `ref:refs/heads/main`. Either trigger from `main` or add a second federated credential for the branch you are using.

**Certificate error: "Could not load certificate"**
`SP_CERT_BASE64` may be truncated (GitHub has a 64KB limit for secret values). Re-encode: `[Convert]::ToBase64String([IO.File]::ReadAllBytes(".\TheDarkFactory365-Deploy.pfx"))` and set the full output as the secret.
