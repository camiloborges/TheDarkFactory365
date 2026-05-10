# Research: GitHub Actions Deployment Automation
**Branch**: `004-gha-deploy-automation` | **Date**: 2026-05-11

---

## D-001: Azure CLI Authentication Method

**Decision**: OIDC via `azure/login@v2` with a federated credential on the service principal.

**Rationale**: OIDC exchanges a short-lived GitHub-issued JWT for an Azure access token at runtime. No secret material is stored in GitHub — `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` are non-sensitive identifiers, not credentials. This satisfies the spec requirement of "not client secret" while being strictly more secure than certificate (no private key to store or rotate).

**Alternatives considered**:
- **Certificate**: Valid, supported by `azure/login@v2` but stores a long-lived private key (PFX) as a GitHub Secret — higher blast radius than OIDC, adds rotation burden. Rejected for Azure CLI operations.
- **Client secret**: Plaintext, up to 2-year validity, highest blast radius. Rejected per spec.

**OIDC configuration**: One federated credential on the service principal with subject `repo:camiloborges/TheDarkFactory365:ref:refs/heads/main` covers both `push` to main and `workflow_dispatch` from main.

**Workflow requirement**: The deploy workflow must declare `permissions: id-token: write` for OIDC token exchange to work.

---

## D-002: SharePoint / PnP.PowerShell Authentication Method

**Decision**: Certificate-based auth via `Connect-PnPOnline -CertificateBase64Encoded`.

**Rationale**: PnP.PowerShell v2 supports OIDC via a community action (`anoopt/action-pnp-powershell-with-oidc`) but certificate auth is simpler, production-proven, and avoids a third-party action dependency. The base64-encoded PFX is stored as a single GitHub Secret (`SP_CERT_BASE64`). The same Entra app registration is used for both Azure CLI (OIDC) and PnP.PowerShell (certificate) — one registration, two auth surfaces.

**Invocation**:
```powershell
Connect-PnPOnline `
  -Url $env:SHAREPOINT_SITE_URL `
  -ClientId $env:AZURE_CLIENT_ID `
  -CertificateBase64Encoded $env:SP_CERT_BASE64 `
  -Tenant $env:AZURE_TENANT_ID
```

**Certificate generation**: A self-signed certificate is generated once during setup (`New-PnPAzureCertificate` or `openssl req -x509`). The public key (`.cer`) is uploaded to the Entra app registration. The private key (`.pfx`, base64-encoded) is stored as `SP_CERT_BASE64` in GitHub Secrets.

---

## D-003: SPFx App Catalog Deployment Tool

**Decision**: PnP.PowerShell `Add-PnPApp` + `Publish-PnPApp`.

**Rationale**: The service principal is already configured for PnP.PowerShell certificate auth. Staying in PowerShell avoids installing and authenticating a second tool (CLI for M365 requires Node.js and its own `m365 login` flow). `Add-PnPApp -Scope Tenant -Overwrite` handles both first-time upload and updates. `Publish-PnPApp -Scope Tenant` enables tenant-wide availability with `skipFeatureDeployment`.

**Alternatives considered**:
- **CLI for M365 (`m365 spo app add/deploy`)**: Requires Node.js install + separate auth configuration. Rejected — adds toolchain complexity with no benefit over PnP.PowerShell.
- **SharePoint REST API directly**: Low-level, no retry handling. Rejected.

---

## D-004: Single Service Principal for Azure and SharePoint

**Decision**: One Entra app registration serves both Azure RBAC (az CLI) and SharePoint app-only (PnP.PowerShell).

**Rationale**: An Entra app registration is simultaneously an Azure service principal (for RBAC-gated operations) and a SharePoint app-only principal (for SharePoint API operations). One registration, one certificate, two auth surfaces. Standard pattern — no separate registrations needed.

**Azure RBAC permission**: Contributor role scoped to the `rg-darkfactory` resource group (minimum required for deploying and updating Logic App Consumption workflows).

**SharePoint API permission**: `SharePoint > Application > Sites.Selected` (least-privilege over `Sites.FullControl.All`). After granting admin consent, the specific sites (App Catalog + DarkFactory) are individually authorised via `Grant-PnPAzureADAppSitePermission`. Admin consent is a one-time manual step.

---

## D-005: Workflow File Structure

**Decision**: Two workflow files — `ci-spfx.yml` (PR validation) and `deploy.yml` (deployment).

**Rationale**: Separating CI from deployment keeps responsibilities clear and avoids running deployment logic on every PR. `ci-spfx.yml` runs only when `dark-factory-weather/**` files change on a PR — it builds, tests, and uploads the `.sppkg` artefact. `deploy.yml` runs on push to `main` or `workflow_dispatch` and performs all three deployments.

**Path-conditional jobs in `deploy.yml`**: `dorny/paths-filter@v3` is used to detect which directories changed. Each deployment job uses an `if:` condition to skip itself when its files didn't change — except when triggered by `workflow_dispatch`, which runs all jobs unconditionally.

**Artefact strategy**: The `deploy.yml` includes its own `build-spfx` job that rebuilds the package fresh (not reusing the artefact from the CI run, which lives in a different workflow run). The CI run validates PRs; the deploy run builds a fresh release artefact. The `.sppkg` artefact is passed from `build-spfx` to `deploy-spfx` within the same `deploy.yml` run via `actions/upload-artifact` + `actions/download-artifact`.

**Alternatives considered**:
- **Single combined workflow**: All triggers in one file. Rejected — harder to read; deploy jobs complicate PR feedback.
- **One workflow per deployment target**: Three deploy files. Rejected — duplicates the `detect-changes` step and scatters the deployment picture.

---

## D-006: GitHub Actions Path Filtering

**Decision**: `dorny/paths-filter@v3` for job-level conditional execution within `deploy.yml`.

**Rationale**: Native GitHub Actions `paths:` filtering works at the workflow trigger level (determines whether the workflow runs at all) but not at the job level. `dorny/paths-filter@v3` outputs boolean values that `if:` conditions on jobs can consume. This enables the `workflow_dispatch` trigger to bypass path filters and run all jobs unconditionally, while `push to main` only runs jobs for changed paths.

---

## D-007: GitHub Secrets vs Variables

**Decision**: Secrets for credentials, Variables for non-sensitive configuration.

| Name | Type | Value |
|---|---|---|
| `AZURE_CLIENT_ID` | Secret | Service principal client ID |
| `AZURE_TENANT_ID` | Secret | Entra tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Secret | Azure subscription ID |
| `SP_CERT_BASE64` | Secret | Base64-encoded PFX private key |
| `SP_CERT_PASSWORD` | Secret | PFX password (empty string if none) |
| `SHAREPOINT_SITE_URL` | Variable | `https://aiwhisperer.sharepoint.com/sites/DarkFactory` |
| `AZURE_RESOURCE_GROUP` | Variable | `rg-darkfactory` |
| `LOGIC_APP_NAME` | Variable | `la-darkfactory-rain-alert` |

`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` are technically non-sensitive identifiers (they can be derived from public Azure resources), but storing them as secrets ensures they are masked in workflow logs.

---

## D-008: PnP.PowerShell Version Pinning

**Decision**: Pin `PnP.PowerShell` to a specific version in the workflow (`Install-Module PnP.PowerShell -RequiredVersion 2.x.x -Force`).

**Rationale**: PnP.PowerShell releases frequently and breaking changes between minor versions have occurred historically. Pinning prevents unexpected failures when a new version is published. Version to use: the latest stable 2.x release at the time of workflow authoring. The version is documented in the workflow and updated deliberately.

---

## D-009: Logic App Connection Parameters

**Decision**: The `connection-parameters.json.template` is populated at deploy time using `az rest` to query the `connectionRuntimeUrl` from the deployed connection resources, then passed to `az logic workflow update`.

**Rationale**: The `connectionRuntimeUrl` is only known after the connection ARM resources are deployed. The deploy workflow queries it from Azure at runtime rather than hardcoding it. This makes the workflow self-contained and correct after a re-deploy.

**Alternative**: Hardcode the runtime URL from a known prior deployment. Rejected — fragile; breaks on connection re-creation.
