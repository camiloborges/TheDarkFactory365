# Tasks: GitHub Actions Deployment Automation

**Input**: Design documents from `specs/004-gha-deploy-automation/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, quickstart.md ✅

**Scope**: Two new files only — `.github/workflows/ci-spfx.yml` and `.github/workflows/deploy.yml`. No existing source files are modified.

**Tests**: No separate test files — GitHub Actions workflow YAML does not have a unit test suite. Correctness is verified by running the workflows as described in the Independent Test criteria and quickstart.md.

---

## Phase 1: Setup

**Purpose**: Create the workflow directory so both CI and deploy workflow files have a home.

- [ ] T001 Create `.github/workflows/` directory in the repository root (if it does not already exist)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Identify the Node.js version used by the SPFx project — this value is needed by both `ci-spfx.yml` and `deploy.yml` and must be established before writing either workflow file.

- [ ] T002 Read `src/dark-factory-weather/package.json` (field `engines.node`) or `src/dark-factory-weather/.nvmrc` to confirm the Node.js version to pin in `actions/setup-node@v4`; record the version as a comment at the top of each workflow file

**Checkpoint**: Node.js version confirmed — workflow file authoring can begin

---

## Phase 3: User Story 1 — Automated SPFx CI (Priority: P1) 🎯 MVP

**Goal**: Every pull request that touches `src/dark-factory-weather/` gets an automatic build gate — TypeScript compilation, Jest tests, and `.sppkg` artefact production — reported as a required status check on the PR.

**Independent Test**: Open a PR with a TypeScript compile error in `src/dark-factory-weather/` and verify the workflow fails with the error clearly identified. Open a PR with a green build and verify the `.sppkg` artefact is uploaded as `spfx-package` in the Actions run summary.

### Implementation for User Story 1

- [ ] T003 [US1] Create `.github/workflows/ci-spfx.yml` with the following `on:` trigger block:
  ```yaml
  on:
    pull_request:
      paths:
        - 'src/dark-factory-weather/**'
  ```
  Add top-level `name: CI` and a single job `build-and-test` running on `ubuntu-latest`.

- [ ] T004 [US1] Add the install and test steps to `build-and-test` in `.github/workflows/ci-spfx.yml`:
  1. `actions/checkout@v4`
  2. `actions/setup-node@v4` with `node-version` set to the version from T002 and `cache: 'npm'` with `cache-dependency-path: src/dark-factory-weather/package-lock.json`
  3. `run: npm ci` with `working-directory: src/dark-factory-weather`
  4. `run: npm test` with `working-directory: src/dark-factory-weather` — this step MUST fail the job if any Jest test fails

- [ ] T005 [US1] Add the build and upload steps to `build-and-test` in `.github/workflows/ci-spfx.yml`:
  1. `run: npm run build` with `working-directory: src/dark-factory-weather` (executes `gulp bundle --ship && gulp package-solution --ship` via the npm script defined in package.json)
  2. `actions/upload-artifact@v4` uploading `src/dark-factory-weather/sharepoint/solution/*.sppkg` as artifact name `spfx-package` with `retention-days: 7`

**Checkpoint**: `ci-spfx.yml` is complete and independently testable — open a test PR against `src/dark-factory-weather/` to verify

---

## Phase 4: User Story 2 — One-Command Deployment (Priority: P2)

**Goal**: A merge to `main` (or a manual `workflow_dispatch`) deploys whichever of the three specs changed — SPFx to the App Catalog, Logic App definition to Azure, SharePoint seed data to DarkFactory — with no manual CLI commands.

**Independent Test**: Merge a change to `src/dark-factory-weather/` into `main`. Verify the `deploy-spfx` job runs and the App Catalog shows the updated app version. Then trigger `workflow_dispatch` manually and verify all three deploy jobs run.

### Implementation for User Story 2 — Workflow Shell and Permissions

- [ ] T006 [US2] Create `.github/workflows/deploy.yml` with:
  - `name: Deploy`
  - `on:` block with `push` to `main` with paths filter covering `src/dark-factory-weather/**`, `src/rain-alert/logic-app-definition.json`, `src/rain-alert/deploy/**`, `specs/003-tenant-infra/**`; plus `workflow_dispatch:` (no paths — runs all jobs)
  - Top-level `permissions: { id-token: write, contents: read }` (required for OIDC token exchange in `azure/login@v2`)

### Implementation for User Story 2 — detect-changes Job

- [ ] T007 [US2] Add the `detect-changes` job to `.github/workflows/deploy.yml`:
  - Runs on `ubuntu-latest`, always runs
  - Uses `dorny/paths-filter@v3` with filters:
    - `spfx: ['src/dark-factory-weather/**']`
    - `logic-app: ['src/rain-alert/logic-app-definition.json', 'src/rain-alert/deploy/**']`
    - `sharepoint-seed: ['src/rain-alert/deploy/Invoke-AlertSeedData.ps1', 'specs/003-tenant-infra/**']`
  - Exposes job outputs: `spfx`, `logic-app`, `sharepoint-seed` from the filter step outputs

### Implementation for User Story 2 — build-spfx Job

- [ ] T008 [US2] Add the `build-spfx` job to `.github/workflows/deploy.yml`:
  - `needs: detect-changes`
  - `if: needs.detect-changes.outputs.spfx == 'true' || github.event_name == 'workflow_dispatch'`
  - Steps mirror `ci-spfx.yml` (T004 + T005): checkout, setup-node (same version), `npm ci`, `npm test`, `npm run build`, upload-artifact `spfx-package`

### Implementation for User Story 2 — deploy-spfx Job

- [ ] T009 [US2] Add the `deploy-spfx` job to `.github/workflows/deploy.yml`:
  - `needs: build-spfx`
  - `if: needs.detect-changes.outputs.spfx == 'true' || github.event_name == 'workflow_dispatch'`
  - Steps:
    1. `actions/checkout@v4`
    2. `actions/download-artifact@v4` for `spfx-package` into `./spfx-drop`
    3. Install PnP.PowerShell via `pwsh -command "Install-Module PnP.PowerShell -RequiredVersion 2.12.0 -Force -Scope CurrentUser"` (pin to latest stable 2.x at time of authoring; update version comment in file header)
    4. Connect and deploy via `pwsh` inline script:
       ```powershell
       Connect-PnPOnline -Url $env:SHAREPOINT_SITE_URL `
         -ClientId $env:AZURE_CLIENT_ID `
         -CertificateBase64Encoded $env:SP_CERT_BASE64 `
         -Tenant $env:AZURE_TENANT_ID
       $pkg = Get-ChildItem -Path ./spfx-drop -Filter *.sppkg | Select-Object -First 1
       $app = Add-PnPApp -Path $pkg.FullName -Scope Tenant -Overwrite
       Publish-PnPApp -Identity $app.Id -Scope Tenant
       Write-Host "Deployed: $($app.Title) v$($app.AppVersion)"
       ```
    5. Set env vars for the step: `SHAREPOINT_SITE_URL: ${{ vars.SHAREPOINT_SITE_URL }}`, `AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}`, `SP_CERT_BASE64: ${{ secrets.SP_CERT_BASE64 }}`, `AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}`

### Implementation for User Story 2 — deploy-logic-app Job

- [ ] T010 [US2] Add the `deploy-logic-app` job to `.github/workflows/deploy.yml`:
  - `needs: detect-changes`
  - `if: needs.detect-changes.outputs.logic-app == 'true' || github.event_name == 'workflow_dispatch'`
  - Steps:
    1. `actions/checkout@v4`
    2. `azure/login@v2` with `client-id: ${{ secrets.AZURE_CLIENT_ID }}`, `tenant-id: ${{ secrets.AZURE_TENANT_ID }}`, `subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}`
    3. Bash step to query connectionRuntimeUrl for SharePoint and Teams connections using `az rest`:
       ```bash
       SP_RUNTIME_URL=$(az rest --method get \
         --url "https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP/providers/Microsoft.Web/connections/$SHAREPOINT_CONNECTION_NAME?api-version=2016-06-01" \
         --query "properties.connectionRuntimeUrl" -o tsv)
       TEAMS_RUNTIME_URL=$(az rest --method get \
         --url "https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP/providers/Microsoft.Web/connections/$TEAMS_CONNECTION_NAME?api-version=2016-06-01" \
         --query "properties.connectionRuntimeUrl" -o tsv)
       ```
       Then substitute placeholders in `src/rain-alert/deploy/connection-parameters.json.template` using `sed` (replacing `{SUBSCRIPTION_ID}`, `{RESOURCE_GROUP}`, `{SHAREPOINT_RUNTIME_URL}`, `{TEAMS_RUNTIME_URL}`) and write output to `/tmp/connection-parameters.json`
    4. `az logic workflow update --resource-group $AZURE_RESOURCE_GROUP --name $LOGIC_APP_NAME --definition @src/rain-alert/logic-app-definition.json --parameters @/tmp/connection-parameters.json`
    5. Print the post-deploy reminder to `$GITHUB_STEP_SUMMARY`:
       ```
       Logic App workflow definition deployed successfully.

       MANUAL STEPS REQUIRED (one-time setup only):
         1. Azure portal → la-darkfactory-rain-alert → API connections
            → Authorise 'connection-sharepoint-darkfactory' (sign in as admin)
            → Authorise 'connection-teams-darkfactory' (sign in as admin)
         2. Azure portal → la-darkfactory-rain-alert → Enable
       ```
    6. Set env vars: `AZURE_RESOURCE_GROUP: ${{ vars.AZURE_RESOURCE_GROUP }}`, `LOGIC_APP_NAME: ${{ vars.LOGIC_APP_NAME }}`, `AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}`, `SHAREPOINT_CONNECTION_NAME: ${{ vars.SHAREPOINT_CONNECTION_NAME }}`, `TEAMS_CONNECTION_NAME: ${{ vars.TEAMS_CONNECTION_NAME }}`

### Implementation for User Story 2 — deploy-sharepoint-seed Job

- [ ] T011 [US2] Add the `deploy-sharepoint-seed` job to `.github/workflows/deploy.yml`:
  - `needs: detect-changes`
  - `if: needs.detect-changes.outputs.sharepoint-seed == 'true' || github.event_name == 'workflow_dispatch'`
  - Steps:
    1. `actions/checkout@v4`
    2. Install PnP.PowerShell (same pinned version as T009)
    3. Run `pwsh` inline script:
       ```powershell
       Connect-PnPOnline -Url $env:SHAREPOINT_SITE_URL `
         -ClientId $env:AZURE_CLIENT_ID `
         -CertificateBase64Encoded $env:SP_CERT_BASE64 `
         -Tenant $env:AZURE_TENANT_ID
       & src/rain-alert/deploy/Invoke-AlertSeedData.ps1 -SiteUrl $env:SHAREPOINT_SITE_URL
       ```
    4. Set env vars: `SHAREPOINT_SITE_URL: ${{ vars.SHAREPOINT_SITE_URL }}`, `AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}`, `SP_CERT_BASE64: ${{ secrets.SP_CERT_BASE64 }}`, `AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}`

**Checkpoint**: `deploy.yml` is complete — trigger a `workflow_dispatch` from the Actions UI to verify all three deploy jobs run. Verify `deploy-spfx` skips when only Logic App files changed.

---

## Phase 5: User Story 3 — Secure Credential Management (Priority: P3)

**Goal**: Audit both workflow files to confirm that no secret material appears in any committed YAML, all sensitive values are sourced exclusively from `${{ secrets.X }}` or `${{ vars.X }}`, and the OIDC permissions block is correctly scoped.

**Independent Test**: Run a grep across `.github/workflows/` for any GUIDs, base64 blobs, passwords, or subscription IDs. None should appear. Confirm `id-token: write` is set only on `deploy.yml`, not `ci-spfx.yml`.

### Implementation for User Story 3

- [ ] T012 [P] [US3] Audit `.github/workflows/ci-spfx.yml`: verify no `secrets.` references exist (CI does not need credentials), no hardcoded URLs, node version uses a variable or literal version string (not a secret), and `permissions:` block is absent (uses repository defaults — read-only for content).

- [ ] T013 [P] [US3] Audit `.github/workflows/deploy.yml`: verify all occurrences of `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `SP_CERT_BASE64`, `SP_CERT_PASSWORD` reference `${{ secrets.X }}`; `SHAREPOINT_SITE_URL`, `AZURE_RESOURCE_GROUP`, `LOGIC_APP_NAME`, `SHAREPOINT_CONNECTION_NAME`, `TEAMS_CONNECTION_NAME` reference `${{ vars.X }}`; no GUIDs, URLs, base64 strings, or passwords appear as literal values anywhere in the file.

- [ ] T014 [US3] Verify the `permissions:` block in `deploy.yml` is at the workflow top level (not per-job) and contains exactly `id-token: write` and `contents: read` — no additional permissions granted. Confirm `ci-spfx.yml` does NOT have `id-token: write` (it never needs OIDC).

**Checkpoint**: Security audit complete — no secrets in committed files, all credential references masked

---

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T015 [P] Add a `name:` to every job in both workflow files (e.g., `name: "Build and Test SPFx"`, `name: "Detect changed paths"`, `name: "Build SPFx package"`, `name: "Deploy to App Catalog"`, `name: "Deploy Logic App"`, `name: "Run SharePoint seed"`) — these names appear in the PR status check list and workflow summary.

- [ ] T016 [P] Add the PnP.PowerShell pinned version as a workflow-level env var at the top of `deploy.yml` (e.g., `env: PNP_VERSION: '2.12.0'`) and reference it in both `deploy-spfx` and `deploy-sharepoint-seed` install steps — satisfies the DRY principle from the constitution check.

- [ ] T017 Run YAML syntax validation on both workflow files: `npx js-yaml .github/workflows/ci-spfx.yml` and `npx js-yaml .github/workflows/deploy.yml` — fix any indentation or quoting errors reported.

- [ ] T018 Follow the quickstart.md verification steps to confirm the end-to-end pipeline is ready for the one-time service principal setup: review that all secret and variable names used in the workflow files exactly match the names listed in `specs/004-gha-deploy-automation/quickstart.md` Step 7 table — correct any mismatches.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — needed by both US1 and US2
- **US1 / Phase 3**: Depends on Phase 2 — `ci-spfx.yml` is fully independent
- **US2 / Phase 4**: Depends on Phase 2 — `deploy.yml` is independent of `ci-spfx.yml`
- **US3 / Phase 5**: Depends on Phase 3 and Phase 4 both being complete
- **Polish / Phase 6**: Depends on Phase 5 completion

### User Story Dependencies

- **US1 (P1)**: Can proceed immediately after Phase 2 — no dependency on US2 or US3
- **US2 (P2)**: Can proceed in parallel with US1 after Phase 2 — `deploy.yml` and `ci-spfx.yml` are separate files
- **US3 (P3)**: Audit tasks; must follow US1 and US2

### Within Phase 4 (US2)

T006 (workflow shell) → T007 (detect-changes job) → T008 (build-spfx), T009 (deploy-spfx), T010 (deploy-logic-app), T011 (deploy-sharepoint-seed) in that order — each job builds on the YAML written by the previous task.

### Parallel Opportunities

- T003–T005 (US1) can run in parallel with T006–T011 (US2) — different files
- T012, T013 (US3 audit) can run in parallel with each other — different files
- T019–T022 (Phase 7) depend on `deploy.yml` and `detect-changes` existing (Phase 4 complete)
- T023, T024 (canvas pack CI) is independent — new file, no dependency on deploy.yml

---

## Phase 7: Spec 005 — Activity Advisor GHA Integration (Priority: P2/P3)

**Purpose**: Extend the pipeline to cover the three GHA-deployable components of Spec 005: the SK Weather Agent (CI build gate + ACA deploy), the Activity Advisor SharePoint list provisioning, and the Activity Advisor Logic App ARM deployment. Adds two new CI workflow files and three new jobs to `deploy.yml`.

**Prerequisite**: Phase 4 complete (`deploy.yml` with detect-changes, build-spfx, deploy-spfx, deploy-logic-app, deploy-sharepoint-seed all in place).

---

### T019 [US4] Create `.github/workflows/ci-sk-agent.yml`

Create a new CI workflow that builds the SK Weather Agent on every pull request touching `src/sk-weather-agent/`:

```yaml
name: CI — SK Weather Agent
on:
  pull_request:
    paths:
      - 'src/sk-weather-agent/**'
jobs:
  build:
    name: Build SK Agent (.NET 8)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'
      - name: Restore
        run: dotnet restore
        working-directory: src/sk-weather-agent
      - name: Build
        run: dotnet build --no-restore --configuration Release
        working-directory: src/sk-weather-agent
```

Note: no `dotnet test` step — the SK agent project has no test project at this time. Add the test step when a test project is introduced.

---

### T020 [US5] Create `.github/workflows/ci-canvas-pack.yml`

Create a new CI workflow that runs `pac canvas pack` on every PR touching the canvas app source and uploads the `.msapp` as a workflow artifact:

```yaml
name: CI — Canvas App Pack
on:
  pull_request:
    paths:
      - 'src/activity-advisor/canvas-app/**'
jobs:
  build-canvas-app:
    name: Build Canvas App (.msapp)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install pac CLI
        uses: microsoft/powerplatform-actions/actions-install@latest
      - name: pac canvas pack
        run: pac canvas pack --sources src/activity-advisor/canvas-app --msapp /tmp/DarkFactoryActivityAdvisor.msapp
      - name: Upload canvas app artifact
        uses: actions/upload-artifact@v4
        with:
          name: canvas-app-package
          path: /tmp/DarkFactoryActivityAdvisor.msapp
          retention-days: 7
```

---

### T021 [US2] Extend `deploy.yml` — add Spec 005 paths and detect-changes filters

Two edits to `deploy.yml`:

**1. Extend `on.push.paths`** to include:
```yaml
- 'src/sk-weather-agent/**'
- 'src/activity-advisor/**'
- 'src/tenant-infra/modules/DarkFactory.ActivityAdvisor.psm1'
```

**2. Extend `detect-changes` job** — add two new filter entries and two new outputs:
```yaml
# In dorny/paths-filter@v3 with: filters:
sk-agent: ['src/sk-weather-agent/**']
activity-advisor:
  - 'src/activity-advisor/logic-app-definition.json'
  - 'src/activity-advisor/deploy/**'
  - 'src/tenant-infra/modules/DarkFactory.ActivityAdvisor.psm1'
  - 'src/tenant-infra/Invoke-DarkFactoryProvisioning.ps1'
```
```yaml
# In detect-changes job outputs:
sk-agent: ${{ steps.filter.outputs.sk-agent }}
activity-advisor: ${{ steps.filter.outputs.activity-advisor }}
```

---

### T022 [US2, US4] Add `deploy-sk-agent` job to `deploy.yml`

```yaml
deploy-sk-agent:
  name: Deploy SK Agent → ACA
  needs: detect-changes
  if: needs.detect-changes.outputs.sk-agent == 'true' || github.event_name == 'workflow_dispatch'
  runs-on: ubuntu-latest
  env:
    ACR_NAME: ${{ vars.ACR_NAME }}
    ACA_NAME: ${{ vars.ACA_NAME }}
    ACA_RESOURCE_GROUP: ${{ vars.AZURE_RESOURCE_GROUP }}
  steps:
    - uses: actions/checkout@v4
    - uses: azure/login@v2
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    - name: Login to ACR
      run: az acr login --name $ACR_NAME
    - name: Build and push Docker image
      run: |
        IMAGE=$ACR_NAME.azurecr.io/sk-weather-agent:$GITHUB_SHA
        docker build -t $IMAGE src/sk-weather-agent
        docker push $IMAGE
        echo "IMAGE=$IMAGE" >> $GITHUB_ENV
    - name: Deploy to Container Apps
      run: |
        az containerapp update \
          --name $ACA_NAME \
          --resource-group $ACA_RESOURCE_GROUP \
          --image $IMAGE
    - name: Print deployment summary
      run: |
        echo "### SK Agent Deployed ✅" >> $GITHUB_STEP_SUMMARY
        echo "Image: \`$IMAGE\`" >> $GITHUB_STEP_SUMMARY
        echo "Container App: \`$ACA_NAME\`" >> $GITHUB_STEP_SUMMARY
```

New GitHub Variables required: `ACR_NAME`, `ACA_NAME` (if `ACA_RESOURCE_GROUP` differs from `AZURE_RESOURCE_GROUP`, add it separately).

---

### T023 [US2] Add `deploy-activity-sp-list` job to `deploy.yml`

```yaml
deploy-activity-sp-list:
  name: Deploy Activity Advisor SP List
  needs: detect-changes
  if: needs.detect-changes.outputs.activity-advisor == 'true' || github.event_name == 'workflow_dispatch'
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - name: Install PnP.PowerShell
      run: Install-Module PnP.PowerShell -RequiredVersion $env:PNP_VERSION -Force -Scope CurrentUser
      shell: pwsh
    - name: Provision Activity Advisor SP list
      shell: pwsh
      env:
        SHAREPOINT_SITE_URL: ${{ vars.SHAREPOINT_SITE_URL }}
        AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
        SP_CERT_BASE64: ${{ secrets.SP_CERT_BASE64 }}
        AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
        ACA_ENDPOINT_URL: ${{ vars.ACA_ENDPOINT_URL }}
        NOTIFICATION_RECIPIENT: ${{ vars.ACTIVITY_ADVISOR_NOTIFICATION_RECIPIENT }}
      run: |
        Connect-PnPOnline -Url $env:SHAREPOINT_SITE_URL `
          -ClientId $env:AZURE_CLIENT_ID `
          -CertificateBase64Encoded $env:SP_CERT_BASE64 `
          -Tenant $env:AZURE_TENANT_ID
        Import-Module ./src/tenant-infra/modules/DarkFactory.ActivityAdvisor.psm1
        Invoke-ActivityAdvisorProvisioning `
          -AgentEndpoint $env:ACA_ENDPOINT_URL `
          -NotificationRecipient $env:NOTIFICATION_RECIPIENT
```

New GitHub Variables required: `ACA_ENDPOINT_URL`, `ACTIVITY_ADVISOR_NOTIFICATION_RECIPIENT`.

---

### T024 [US2] Add `deploy-activity-logic-app` job to `deploy.yml`

```yaml
deploy-activity-logic-app:
  name: Deploy Activity Advisor Logic App
  needs: detect-changes
  if: needs.detect-changes.outputs.activity-advisor == 'true' || github.event_name == 'workflow_dispatch'
  runs-on: ubuntu-latest
  env:
    AZURE_RESOURCE_GROUP: ${{ vars.AZURE_RESOURCE_GROUP }}
    ACTIVITY_LA_NAME: ${{ vars.ACTIVITY_ADVISOR_LOGIC_APP_NAME }}
    SP_CONN_NAME: ${{ vars.ACTIVITY_ADVISOR_SP_CONNECTION_NAME }}
    ACA_ENDPOINT_URL: ${{ vars.ACA_ENDPOINT_URL }}
  steps:
    - uses: actions/checkout@v4
    - uses: azure/login@v2
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    - name: Get SharePoint connection runtime URL
      run: |
        SP_RUNTIME_URL=$(az rest --method get \
          --url "https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP/providers/Microsoft.Web/connections/$SP_CONN_NAME?api-version=2016-06-01" \
          --query "properties.connectionRuntimeUrl" -o tsv)
        echo "SP_RUNTIME_URL=$SP_RUNTIME_URL" >> $GITHUB_ENV
      env:
        AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    - name: Deploy ARM template
      run: |
        az deployment group create \
          --resource-group $AZURE_RESOURCE_GROUP \
          --template-file src/activity-advisor/deploy/activity-advisor-logic-app.json \
          --parameters \
            workflowDefinition=@src/activity-advisor/logic-app-definition.json \
            sharePointConnectionRuntimeUrl="$SP_RUNTIME_URL" \
            agentEndpointUrl="$ACA_ENDPOINT_URL" \
            activityAdvisorApiKey="${{ secrets.ACTIVITY_ADVISOR_API_KEY }}"
    - name: Print post-deploy reminder
      run: |
        echo "### Activity Advisor Logic App Deployed ✅" >> $GITHUB_STEP_SUMMARY
        echo "" >> $GITHUB_STEP_SUMMARY
        echo "**MANUAL STEPS REQUIRED (one-time):**" >> $GITHUB_STEP_SUMMARY
        echo "1. Azure portal → \`$ACTIVITY_LA_NAME\` → API connections → Authorise \`$SP_CONN_NAME\`" >> $GITHUB_STEP_SUMMARY
        echo "2. Azure portal → \`$ACTIVITY_LA_NAME\` → Enable" >> $GITHUB_STEP_SUMMARY
```

New GitHub Secrets required: `ACTIVITY_ADVISOR_API_KEY`.
New GitHub Variables required: `ACTIVITY_ADVISOR_LOGIC_APP_NAME`, `ACTIVITY_ADVISOR_SP_CONNECTION_NAME`.

---

### T025 [US3, P] Document and audit Spec 005 GitHub Secrets and Variables

Verify every name used in T022–T024 appears in the quickstart.md Step 7 secrets/variables table. Add the following entries if missing:

| Name | Type | Description |
|---|---|---|
| `ACTIVITY_ADVISOR_API_KEY` | Secret | X-Api-Key for the SK agent `POST /api/assess-activity` endpoint |
| `ACR_NAME` | Variable | Azure Container Registry name (e.g. `acrdarkfactory`) |
| `ACA_NAME` | Variable | Container App name (e.g. `ca-darkfactory-sk-weather-agent`) |
| `ACA_ENDPOINT_URL` | Variable | Public HTTPS URL of the Container App (e.g. `https://ca-darkfactory-sk-weather-agent.azurecontainerapps.io`) |
| `ACTIVITY_ADVISOR_LOGIC_APP_NAME` | Variable | e.g. `la-darkfactory-activity-advisor` |
| `ACTIVITY_ADVISOR_SP_CONNECTION_NAME` | Variable | SharePoint API connection name in `rg-darkfactory` |
| `ACTIVITY_ADVISOR_NOTIFICATION_RECIPIENT` | Variable | Teams user UPN or email for assessment notifications |

Also re-run the credential audit from T013 and T014 across the three new workflow sections to verify no hardcoded values appear.

**Checkpoint**: All three new `deploy.yml` jobs verified with `workflow_dispatch`. `ci-sk-agent.yml` verified by opening a test PR with a .NET compile error. `ci-canvas-pack.yml` verified by opening a PR touching the canvas app source.
- T015, T016, T017, T018 (polish) can run in parallel

---

## Parallel Example: US1 and US2 Together

```
# Start both user stories after Phase 2 completes:
Agent A: T003 → T004 → T005  (ci-spfx.yml complete)
Agent B: T006 → T007 → T008 → T009 → T010 → T011  (deploy.yml complete)

# Once both complete, run US3 audit in parallel:
Agent A: T012  (audit ci-spfx.yml)
Agent B: T013  (audit deploy.yml)
Then: T014  (verify permissions blocks)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Create `.github/workflows/`
2. Complete Phase 2: Confirm Node.js version
3. Complete Phase 3 (T003–T005): Write `ci-spfx.yml`
4. **STOP and VALIDATE**: Open a test PR that breaks a TypeScript type — verify the check fails
5. Proceed to US2 once PR checks are confirmed working

### Incremental Delivery

1. Setup + Foundational (T001–T002): Directory and Node version confirmed
2. US1 (T003–T005): `ci-spfx.yml` — PR gates on SPFx changes ✅
3. US2 (T006–T011): `deploy.yml` — merge-triggered and manual deployments ✅
4. US3 (T012–T014): Credential audit — confirmed no secrets in committed files ✅
5. Polish (T015–T018): Names, DRY env var, YAML lint, secret name alignment ✅

---

## Notes

- No source files in `src/dark-factory-weather/`, `src/rain-alert/`, or `specs/` are modified by this feature
- Existing scripts (`Deploy-AlertInfrastructure.ps1`, `Invoke-AlertSeedData.ps1`) are called as-is
- The one-time service principal setup in `quickstart.md` is NOT a task here — it is administrator pre-work done outside the pipeline
- PnP.PowerShell version `2.12.0` is a placeholder — use the latest stable 2.x release at time of implementation and update both the workflow file and this tasks.md
- The `connection-parameters.json.template` file lives at `src/rain-alert/deploy/connection-parameters.json.template` and is already committed — T010 only reads and substitutes it at runtime, never commits the populated version
