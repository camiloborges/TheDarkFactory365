# Feature Specification: GitHub Actions Deployment Automation

**Feature Branch**: `004-gha-deploy-automation`
**Created**: 2026-05-11
**Status**: Draft
**Scope Note**: Automates the deployment pipeline for TheDarkFactory365 specs 001, 002, 003, and 005 (Activity Advisor) using GitHub Actions. Three manual gates intentionally remain: Logic App OAuth connection authorisation (×2 — rain-alert and activity-advisor) and the initial Logic App enable — these require a human to sign in once and cannot be scripted with user-delegated auth.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Automated SPFx Build and Package Verification (Priority: P1)

As the administrator, I want every pull request to automatically build and validate the SPFx web part, so that broken packages are caught before they reach the main branch and I never accidentally deploy a web part that doesn't compile.

**Why this priority**: The SPFx package (Spec 001) is the user-facing artefact with the most moving parts — TypeScript compilation, Jest tests, and Webpack bundling. This is the highest-value CI check because it runs on every PR and catches regressions instantly. It delivers value even if no deployment automation exists.

**Independent Test**: Open a PR that breaks a TypeScript type. The GHA workflow should fail on the build step and report the error. A passing PR should show a green check with test results.

**Acceptance Scenarios**:

1. **Given** a pull request is opened or updated, **When** files under `src/dark-factory-weather/` are changed, **Then** the workflow runs `npm install`, executes all unit tests, and bundles the production package — reporting pass or fail on the PR.
2. **Given** a pull request has a TypeScript compilation error, **When** the build workflow runs, **Then** the workflow fails with an error message identifying the failing file, blocking merge.
3. **Given** all unit tests pass and the package builds successfully, **When** the build workflow completes, **Then** the compiled `.sppkg` artefact is uploaded and available for the deployment job to use — no re-build required.
4. **Given** no files under `src/dark-factory-weather/` are changed in a PR, **When** the workflow evaluates its trigger, **Then** the SPFx build job is skipped to avoid wasting CI minutes.

---

### User Story 2 — One-Command Deployment to SharePoint and Azure (Priority: P2)

As the administrator, I want to deploy all three specs to my tenant by merging to main or running a manual trigger, so that deploying a change doesn't require me to manually run scripts, open portals, or remember the right parameters.

**Why this priority**: The whole point of the automation spec is to remove the manual deployment burden. After initial infrastructure setup (which remains manual), any subsequent change — a web part update, a new config key, a Logic App workflow change — should deploy itself.

**Independent Test**: Merge a change to `src/dark-factory-weather/` into main. The deployment workflow should upload the new `.sppkg` to the SharePoint App Catalog and update the app without any manual steps.

**Acceptance Scenarios**:

1. **Given** a merge to main includes changes to `src/dark-factory-weather/`, **When** the deployment workflow runs, **Then** the updated `.sppkg` is uploaded to the SharePoint tenant App Catalog and the app version is updated — without the administrator opening a browser.
2. **Given** a merge to main includes changes to `src/rain-alert/logic-app-definition.json`, **When** the deployment workflow runs, **Then** the updated Logic App workflow definition is deployed to `la-darkfactory-rain-alert` in `rg-darkfactory` — without the administrator running any CLI command.
3. **Given** a merge to main includes changes to the tenant provisioning scripts under `specs/003-tenant-infra/`, **When** the deployment workflow runs, **Then** the SharePoint seed script runs idempotently against the DarkFactory site — adding missing config rows, skipping existing ones.
4. **Given** the deployment workflow is triggered manually via the GitHub Actions UI, **When** the administrator selects a target environment and confirms, **Then** all deployment jobs (all specs) run in the correct dependency order regardless of which files changed.
5. **Given** a deployment job fails mid-run (e.g., Azure authentication error), **When** the workflow terminates, **Then** completed steps are not re-run on the next trigger, and the specific failing step is clearly reported in the workflow summary.
6. **Given** a merge to main includes changes to `src/sk-weather-agent/`, **When** the deployment workflow runs, **Then** the SK agent Docker image is built, pushed to the Azure Container Registry, and the Container App is updated with the new image tag — without the administrator opening a browser.
7. **Given** a merge to main includes changes to Activity Advisor provisioning files (`src/activity-advisor/` or `src/tenant-infra/modules/DarkFactory.ActivityAdvisor.psm1`), **When** the deployment workflow runs, **Then** the SharePoint `DarkFactory-ActivityRequests` list is provisioned idempotently against the DarkFactory site.
8. **Given** a merge to main includes changes to `src/activity-advisor/logic-app-definition.json`, **When** the deployment workflow runs, **Then** the updated Logic App workflow definition is deployed to `la-darkfactory-activity-advisor` in `rg-darkfactory`.

---

### User Story 4 — Automated SK Agent Build Gate (Priority: P2)

As the administrator, I want every pull request that changes the SK Weather Agent to be automatically built, so that .NET compilation errors are caught before main and a broken Docker image is never deployed to Azure Container Apps.

**Why this priority**: The SK Agent (.NET 8 web app) is the AI core of Spec 005. A compilation failure here produces a broken Docker image. The CI gate prevents that at zero marginal cost once the pipeline exists. Priority P2 (not P1) because it gates the deploy workflow, which is also P2.

**Independent Test**: Open a PR with a .NET compilation error in `src/sk-weather-agent/`. The `ci-sk-agent` workflow should fail and block the PR from merging.

**Acceptance Scenarios**:

1. **Given** a pull request is opened or updated, **When** files under `src/sk-weather-agent/` are changed, **Then** the workflow runs `dotnet restore` and `dotnet build` — reporting pass or fail on the PR.
2. **Given** a pull request introduces a .NET compilation error, **When** the build workflow runs, **Then** the workflow fails with the compiler error message identifying the failing file and line, blocking merge.
3. **Given** no files under `src/sk-weather-agent/` are changed, **When** the workflow evaluates its trigger, **Then** the SK agent build job is skipped entirely.

---

### User Story 5 — Canvas App Artifact Build (Priority: P3)

As the administrator, I want every pull request that changes the canvas app source to produce a verified `.msapp` artifact, so that the community can download a tested importable package directly from the GitHub Actions run summary without needing the `pac` CLI installed locally.

**Why this priority**: Closes the reproducibility gap for the canvas app (identified in the Spec 005 MVP community assessment). Low effort given the `build.ps1` already exists; highest community-facing value of the P3 items.

**Independent Test**: Open a PR touching `src/activity-advisor/canvas-app/src/`. The `ci-canvas-pack` workflow should produce a `canvas-app-package` artifact visible in the Actions run summary.

**Acceptance Scenarios**:

1. **Given** a pull request touches `src/activity-advisor/canvas-app/**`, **When** the CI workflow runs, **Then** `pac canvas pack` executes successfully and uploads `DarkFactoryActivityAdvisor.msapp` as a workflow artifact named `canvas-app-package`.
2. **Given** the pack step fails (malformed YAML), **When** the workflow runs, **Then** the job fails with the pac error output visible in the run log.
3. **Given** no files under `src/activity-advisor/canvas-app/` are changed, **When** the workflow evaluates its trigger, **Then** the canvas pack job is skipped.

---

### User Story 3 — Secure Credential Management (Priority: P3)

As the administrator, I want all deployment credentials stored as GitHub repository secrets and never present in committed files, so that my Azure service principal, SharePoint credentials, and certificate are not exposed in the repository history or workflow logs.

**Why this priority**: Necessary for the pipeline to be safe to operate, but does not deliver standalone user value — it is a constraint on how US1 and US2 are implemented. Covered here as an explicit user story because credential hygiene is a first-class requirement, not an afterthought.

**Independent Test**: Review the repository — no secrets, certificates, or plaintext passwords appear in any committed file or workflow log output. The deployment runs solely from values defined in GitHub Secrets.

**Acceptance Scenarios**:

1. **Given** the deployment workflow is configured, **When** a security scan runs on the repository, **Then** no credentials, certificates, subscription IDs, or tenant IDs are present in any committed file.
2. **Given** a deployment workflow run completes (pass or fail), **When** the workflow log is viewed, **Then** all sensitive values (service principal client ID, certificate thumbprint, tenant ID, subscription ID) are masked and never appear in plain text.
3. **Given** a contributor forks the repository, **When** they run the workflow from their fork, **Then** the workflow fails gracefully at the authentication step with a clear message — it does not silently deploy to the real tenant or expose credentials.

---

### Edge Cases

- What happens when the SharePoint App Catalog does not yet exist (Spec 003 not yet run)? The workflow should fail the deployment step with a clear error message pointing to the quickstart guide, not with an obscure API error.
- What happens when the Azure resource group `rg-darkfactory` does not exist? The Logic App deployment step should fail with a human-readable error, not silently succeed with a wrong deployment.
- What happens when the Logic App OAuth connections are not yet authorised? The workflow should deploy the definition successfully and print a clear reminder that the two manual steps (authorise connections, enable Logic App) must be completed before alerts will fire.
- What happens when a GitHub Actions runner cannot reach `management.azure.com` or SharePoint? The step should fail with a timeout error and the retry-able nature of the job should be noted in the workflow summary.
- What happens when the `.sppkg` artefact from the build job is not available for the deploy job? The deploy job should fail immediately with a clear message that the build job must run first.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST run an automated build and test job for the SPFx web part on every pull request that touches `src/dark-factory-weather/`.
- **FR-002**: The build job MUST execute all unit tests and fail the workflow if any test fails.
- **FR-003**: The build job MUST produce a deployable `.sppkg` artefact and upload it for use by the deployment job without rebuilding.
- **FR-004**: The system MUST deploy the SPFx package to the SharePoint tenant App Catalog when a change to `src/dark-factory-weather/` is merged to main.
- **FR-005**: The system MUST deploy the Logic App workflow definition to Azure when a change to `src/rain-alert/logic-app-definition.json` is merged to main.
- **FR-006**: The system MUST run the SharePoint seed script idempotently when provisioning-related files change on main.
- **FR-007**: The system MUST support a manual trigger that runs all deployment jobs regardless of which files changed, for use during initial setup and ad-hoc re-deployments.
- **FR-008**: The system MUST authenticate to Azure using a service principal with certificate-based auth (not client secret) so that credentials can be rotated without changing workflow files.
- **FR-009**: The system MUST authenticate to SharePoint using app-only permissions granted to the same service principal, avoiding interactive OAuth for automated runs.
- **FR-010**: All credentials (tenant ID, subscription ID, client ID, certificate) MUST be stored exclusively in GitHub repository secrets — never in workflow YAML files or committed scripts.
- **FR-011**: Workflow logs MUST mask all secret values so they never appear in plain text in any log output.
- **FR-012**: The Logic App deployment job MUST print a post-deployment reminder listing the two manual steps (authorise connections, enable Logic App) when those steps have not yet been completed.
- **FR-013**: Each deployment job MUST be independently skippable — if only the Logic App definition changed, the SPFx deployment job should be skipped.
- **FR-014**: The system MUST report deployment success or failure per-job in the GitHub Actions workflow summary, with enough context to diagnose failures without reading raw logs.

#### Spec 005 — Activity Advisor

- **FR-015**: The system MUST run an automated .NET build job for the SK Weather Agent on every pull request that touches `src/sk-weather-agent/`.
- **FR-016**: The SK agent build job MUST run `dotnet restore` and `dotnet build --configuration Release` and fail the workflow if the build fails.
- **FR-017**: The system MUST run `pac canvas pack` on every pull request that touches `src/activity-advisor/canvas-app/**` and upload the resulting `.msapp` as a workflow artifact named `canvas-app-package`.
- **FR-018**: The system MUST build the SK agent Docker image and deploy it to Azure Container Apps when a change to `src/sk-weather-agent/` is merged to main — using the commit SHA as the image tag.
- **FR-019**: The system MUST run the `Invoke-ActivityAdvisorProvisioning` function idempotently when provisioning-related files for Spec 005 change on main.
- **FR-020**: The system MUST deploy the Activity Advisor Logic App ARM template when `src/activity-advisor/logic-app-definition.json` or its deploy template changes on main.

### Key Entities

- **CI Workflow**: The GitHub Actions workflow that runs on pull requests — builds the SPFx package, runs tests, uploads artefacts. Does not deploy.
- **Deploy Workflow**: The GitHub Actions workflow that runs on merge to main or manual trigger — deploys SPFx, Logic App, and SharePoint seed data. Depends on CI artefacts.
- **Service Principal**: An Entra ID (Azure AD) app registration with a self-signed certificate, granted the minimum permissions required: SharePoint App Catalog write, Azure resource group contributor, SharePoint site member (for seed script).
- **GitHub Secrets**: Repository-level secrets storing the tenant ID, subscription ID, service principal client ID, and base64-encoded certificate (both public and private parts for PnP PowerShell).
- **Artefact**: The compiled `.sppkg` file produced by the CI job and consumed by the deploy job. Retained for 7 days.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A pull request with a broken TypeScript type or failing unit test is blocked from merging within 5 minutes of being pushed — no manual review required to catch the error.
- **SC-002**: A change merged to main is live in the SharePoint App Catalog and/or Azure Logic App within 10 minutes of the merge — no manual commands needed.
- **SC-003**: The full deployment pipeline (all three specs) completes in under 15 minutes when triggered manually.
- **SC-004**: Zero plaintext secrets appear in any workflow run log, repository file, or PR diff — verified by automated secret scanning.
- **SC-005**: The pipeline self-recovers from a transient failure (network timeout, API throttle) by retrying the failed step without manual intervention, within the same run.
- **SC-006**: A contributor with no Azure access cannot accidentally deploy to the production tenant — the workflow fails at authentication with a clear message.
- **SC-007**: A PR with a .NET compilation error in `src/sk-weather-agent/` is blocked from merging within 5 minutes of being pushed — no manual review needed to catch the error.
- **SC-008**: A change merged to main that updates the SK agent is live in Azure Container Apps within 15 minutes — Docker build, ACR push, and `az containerapp update` complete without manual commands.

---

## Assumptions

- The GitHub repository is `camiloborges/TheDarkFactory365` — the workflow files will live under `.github/workflows/`.
- Spec 003 (Tenant Infrastructure) has been run at least once before the deployment pipeline is set up — the SharePoint site, App Catalog, and Azure resource group must already exist for deployments to succeed.
- The Logic App OAuth connections (SharePoint and Teams) still require one-time manual authorisation in the Azure portal — this remains a manual gate and the automation pipeline will not attempt to bypass it.
- The initial Logic App enable (after connections are authorised) is also a manual step. The pipeline deploys the definition but leaves the Logic App disabled.
- GitHub Actions standard runners (ubuntu-latest) are used. No self-hosted runners are required.
- The service principal is created once by the administrator as a one-time setup step outside the pipeline — the pipeline consumes its credentials but does not create or rotate them.
- PnP PowerShell (PnP.PowerShell module) is used for SharePoint operations in the pipeline, running on the ubuntu-latest runner via PowerShell Core.
- The `az` CLI (Azure CLI) is used for Logic App and Azure resource operations.
- M365 CLI or PnP CLI is used for SPFx App Catalog deployment.
- Certificate-based auth is preferred over client secrets for the service principal because certificates do not appear in audit logs as leaked credentials and have a clear rotation path.
- The pipeline only deploys from the `main` branch — feature branches never trigger deployments to the live tenant.

#### Spec 005 — Activity Advisor

- An Azure Container Registry (ACR) exists in `rg-darkfactory` — this is a one-time manual creation step outside the pipeline.
- A Container Apps environment and the Container App `ca-darkfactory-sk-weather-agent` are provisioned in `rg-darkfactory` before the first deploy — initial container app creation is a one-time manual step; subsequent deployments use `az containerapp update`.
- The SK agent container listens on port 3978 (default M365 Agents SDK / Bot Framework port).
- `ACTIVITY_ADVISOR_API_KEY` is a pre-generated strong random string stored in GitHub Secrets; the same value is configured in the Container App environment variables and in the Logic App deployment parameters.
- The Activity Advisor Logic App OAuth connection (SharePoint) requires one-time manual authorisation in the Azure portal after first deploy — same pattern as the rain-alert Logic App.
- The `pac` CLI is installed on the GHA runner via the `microsoft/powerplatform-actions/actions-install` official action.
- The SK agent project (`src/sk-weather-agent/`) has no dedicated test project — the CI job validates compilation only; test coverage is tracked as a future improvement.
