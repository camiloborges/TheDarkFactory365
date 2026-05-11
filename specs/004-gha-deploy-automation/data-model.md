# Data Model: GitHub Actions Deployment Automation
**Branch**: `004-gha-deploy-automation` | **Date**: 2026-05-11

---

## Workflow Entities

### CI Workflow (`ci-spfx.yml`)

The pull request validation workflow. Runs on every PR that touches the SPFx web part.

| Property | Value |
|---|---|
| Trigger | `pull_request` on paths `src/dark-factory-weather/**` |
| Runner | `ubuntu-latest` |
| Artefact produced | `spfx-package` (`.sppkg` file, retained 7 days) |

**Jobs**:
| Job ID | Runs when | Steps |
|---|---|---|
| `build-and-test` | Always (PR on relevant paths) | Install Node deps → Run unit tests → Build production bundle → Upload `.sppkg` artefact |

---

### Deploy Workflow (`deploy.yml`)

The deployment workflow. Runs on push to `main` or manual trigger.

| Property | Value |
|---|---|
| Trigger | `push` to `main` on paths `src/dark-factory-weather/**`, `src/rain-alert/**`; `workflow_dispatch` (no path filter) |
| Runner | `ubuntu-latest` |
| Environment | `production` (required for deploy jobs — enables required reviewers if configured) |

**Jobs**:
| Job ID | Condition | Needs | Steps |
|---|---|---|---|
| `detect-changes` | Always | — | Run `dorny/paths-filter@v3` → output booleans per path group |
| `build-spfx` | `spfx` changed OR `workflow_dispatch` | `detect-changes` | Install deps → Build SPFx → Upload artefact |
| `deploy-spfx` | `spfx` changed OR `workflow_dispatch` | `build-spfx` | Download artefact → Install PnP.PowerShell → Connect → `Add-PnPApp` → `Publish-PnPApp` → Print confirmation |
| `deploy-logic-app` | `logic-app` changed OR `workflow_dispatch` | `detect-changes` | Azure login (OIDC) → Query `connectionRuntimeUrl` values → Populate params → `az logic workflow update` → Print post-deploy reminder |
| `deploy-sharepoint-seed` | `sharepoint-seed` changed OR `workflow_dispatch` | `detect-changes` | Install PnP.PowerShell → Connect → Run `Invoke-AlertSeedData.ps1` → Print summary |

---

## Service Principal Entity

The single Entra ID app registration used by all deployment jobs.

| Attribute | Value |
|---|---|
| Display name | `TheDarkFactory365-Deploy` |
| Authentication | Certificate (PnP.PowerShell) + OIDC federated credential (az CLI) |
| Azure RBAC | Contributor on `rg-darkfactory` resource group |
| SharePoint API | `Sites.Selected` (application permission, admin consented) |
| Site grants | FullControl on tenant App Catalog site; FullControl on `DarkFactory` site |

---

## GitHub Secrets and Variables

### Secrets (masked in all log output)

| Secret name | Content | Used by |
|---|---|---|
| `AZURE_CLIENT_ID` | Entra app registration client ID (GUID) | `azure/login@v2`, `Connect-PnPOnline` |
| `AZURE_TENANT_ID` | Entra tenant ID (GUID) | `azure/login@v2`, `Connect-PnPOnline` |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID (GUID) | `azure/login@v2` |
| `SP_CERT_BASE64` | Base64-encoded PFX private key | `Connect-PnPOnline` |
| `SP_CERT_PASSWORD` | PFX password (empty string if not set) | `Connect-PnPOnline` |

### Variables (non-sensitive, visible in logs)

| Variable name | Default value | Used by |
|---|---|---|
| `SHAREPOINT_SITE_URL` | `https://aiwhisperer.sharepoint.com/sites/DarkFactory` | `deploy-spfx`, `deploy-sharepoint-seed` |
| `AZURE_RESOURCE_GROUP` | `rg-darkfactory` | `deploy-logic-app` |
| `LOGIC_APP_NAME` | `la-darkfactory-rain-alert` | `deploy-logic-app` |
| `SHAREPOINT_CONNECTION_NAME` | `connection-sharepoint-darkfactory` | `deploy-logic-app` |
| `TEAMS_CONNECTION_NAME` | `connection-teams-darkfactory` | `deploy-logic-app` |

---

## Path Filter Groups

Defines which workflow jobs run for a given push to `main`.

| Filter name | Paths watched | Triggers job(s) |
|---|---|---|
| `spfx` | `src/dark-factory-weather/**` | `build-spfx`, `deploy-spfx` |
| `logic-app` | `src/rain-alert/logic-app-definition.json`, `src/rain-alert/deploy/**` | `deploy-logic-app` |
| `sharepoint-seed` | `src/rain-alert/deploy/Invoke-AlertSeedData.ps1`, `specs/003-tenant-infra/**` | `deploy-sharepoint-seed` |

On `workflow_dispatch`, the path filter is bypassed and all jobs run.

---

## Artefact Entity

The compiled SPFx package produced by `build-spfx` and consumed by `deploy-spfx`.

| Attribute | Value |
|---|---|
| Artefact name | `spfx-package` |
| Contents | `src/dark-factory-weather/sharepoint/solution/*.sppkg` |
| Retention | 7 days |
| Produced by | `build-spfx` job |
| Consumed by | `deploy-spfx` job (same workflow run) |

---

## Post-Deploy Reminder (Logic App)

Printed as a workflow step summary after `deploy-logic-app` succeeds. Not a failure — informational only.

```
Logic App workflow definition deployed successfully.

MANUAL STEPS REQUIRED (one-time setup only):
  1. Azure portal → la-darkfactory-rain-alert → API connections
     → Authorise 'connection-sharepoint-darkfactory' (sign in as admin)
     → Authorise 'connection-teams-darkfactory' (sign in as admin)
  2. Azure portal → la-darkfactory-rain-alert → Enable

These steps are required only once. Subsequent deployments do not need re-authorisation
unless the OAuth token expires (after 90 days of inactivity).
```
