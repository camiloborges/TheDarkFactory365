# Feature Specification: TheDarkFactory365 Tenant Infrastructure

**Feature Branch**: `003-tenant-infra`
**Created**: 2026-05-10
**Status**: Draft
**Scope Note**: This spec covers the one-time provisioning of all tenant and workload resources that every other TheDarkFactory365 spec depends on. It is the foundational infrastructure layer — run it once on a fresh tenant and it is ready for all downstream solutions.

## Clarifications

### Session 2026-05-10

- Q: Must the provisioning operation run cross-platform (Windows and macOS), or is Windows only required? → A: Windows only.
- Q: Should the provisioning operation accept home location as run-time parameters, or seed Auckland placeholder defaults for manual update? → A: Accept home location as run-time parameters — Auckland is never written; actual coordinates are seeded directly.
- Q: Will family member accounts be internal licensed accounts or external guest accounts? → A: Guest accounts — family members use personal Microsoft accounts invited as B2B guests; external sharing must be configured.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Provision Workload Resources (Priority: P1)

As the family administrator, I want to run a single provisioning operation that creates the DarkFactory SharePoint site, the central configuration store, the DarkFactory Teams team, and all family member access grants, so that every TheDarkFactory365 solution has the infrastructure it needs to run without any manual portal steps.

**Why this priority**: This is the most immediate need — without the SharePoint site, config list, and Teams team, Spec 001 (Weather Display) cannot be deployed. It is the highest-value deliverable and can be validated independently.

**Independent Test**: Can be fully tested against a fresh tenant by running the provisioning operation and then verifying: the DarkFactory SharePoint site loads, the `DarkFactory-Settings` list exists with the correct columns and seed data, the DarkFactory Teams team appears with a General channel, and a family member account can read the config list.

**Acceptance Scenarios**:

1. **Given** a fresh tenant with no DarkFactory resources, **When** the administrator runs the provisioning operation, **Then** the DarkFactory SharePoint site is created and accessible.
2. **Given** the provisioning operation completes, **When** the administrator opens the SharePoint site, **Then** the `DarkFactory-Settings` list exists with the Title, Value, Description, and Category columns, and all Spec 001 seed keys are present.
3. **Given** the provisioning operation completes, **When** a family member logs in, **Then** they can read entries in the `DarkFactory-Settings` list but cannot edit them.
4. **Given** the provisioning operation completes, **When** the administrator opens Microsoft Teams, **Then** the `DarkFactory` team exists with a `General` channel.
5. **Given** the provisioning operation has already run successfully, **When** the administrator runs it again, **Then** it completes without errors and does not create duplicate resources or overwrite existing configuration values.

---

### User Story 2 — Apply Tenant-Level Configuration (Priority: P2)

As the family administrator, I want the tenant-level settings required for SPFx deployment and external API access (App Catalog, Content Security Policy, Power Platform environment) to be declared and applied in code, so that these settings are reproducible and I never need to configure them manually in admin portals.

**Why this priority**: Required for Spec 001 deployment (App Catalog + CSP) and future specs (Power Platform environment), but depends on workload resources being provisioned first. Independently testable once tenant admin access is confirmed.

**Independent Test**: Can be tested by verifying the App Catalog site is accessible, `api.open-meteo.com` appears in the tenant CSP allowlist, and a Power Platform environment exists — all without opening any admin portal manually.

**Acceptance Scenarios**:

1. **Given** the tenant-level configuration has been applied, **When** the administrator checks the tenant, **Then** a tenant App Catalog site exists and is accessible to deploy SPFx solutions.
2. **Given** the tenant-level configuration has been applied, **When** a browser makes a client-side request to `api.open-meteo.com` from a SharePoint page, **Then** the request is not blocked by the browser's Content Security Policy.
3. **Given** the tenant-level configuration has been applied, **When** the administrator opens the Power Platform admin centre, **Then** a dedicated Power Platform environment for TheDarkFactory365 exists.
4. **Given** all tenant-level configuration is already in place, **When** the configuration is re-applied, **Then** it completes without errors and makes no changes to already-correct settings.

---

### User Story 3 — Provisioning Transparency and Recovery (Priority: P3)

As the family administrator, I want the provisioning operation to tell me exactly what it did — what was created, what already existed and was skipped, and what failed — so that I can run it safely at any time and know the exact state of the environment.

**Why this priority**: Critical for safe re-runs and partial-failure recovery, but does not block the initial setup. Builds confidence that running the solution is always safe.

**Independent Test**: Can be tested by running the provisioning operation twice — the second run should produce a report showing all items as "already exists / skipped" with zero changes made.

**Acceptance Scenarios**:

1. **Given** the provisioning operation runs successfully, **When** it completes, **Then** it produces a summary listing each resource with its outcome: created, already existed (skipped), or failed.
2. **Given** the provisioning operation fails on one resource (e.g., a family member account does not exist), **When** it completes, **Then** it reports that specific failure with a clear message and continues provisioning the remaining resources rather than stopping entirely.
3. **Given** the `DarkFactory-Settings` list already contains some seed keys but not all, **When** the provisioning operation runs, **Then** it adds only the missing keys and leaves existing keys and their values untouched.
4. **Given** the administrator has updated a seed value (e.g., changed the home latitude), **When** the provisioning operation re-runs, **Then** it does not overwrite the updated value.

---

### Edge Cases

- What if the App Catalog already exists at a different URL than expected? The operation must detect the existing catalog URL and use it rather than attempting to create a second one.
- What if a family member account does not exist in the tenant at run time? The operation skips that grant with a warning rather than failing the entire run.
- What if `api.open-meteo.com` is already in the CSP allowlist? The operation uses an exact match on both directive (`connect-src`) and source (`api.open-meteo.com`) to detect the existing entry and skips without error.
- What if CSP enforcement is not enabled on the tenant? The operation reports this as a required manual step in the completion report rather than silently succeeding with a no-op add.
- What if the `DarkFactory-Settings` list already exists but is missing some columns? The operation adds the missing columns without recreating the list or losing existing data.
- What if the Teams team already exists but its General channel was manually deleted? The operation detects the missing channel and recreates it.
- What if the operation fails partway through (e.g., network interruption)? The administrator can re-run safely — successfully provisioned resources are detected and skipped; only incomplete items are retried.
- What if a guest account has been invited but has not yet accepted the invitation? The operation grants access to the pending guest account (SharePoint access can be granted before invitation is accepted) and notes the pending state in the completion report.
- What if external sharing is disabled at the tenant level? The operation must enable it (set to "ExistingExternalUserSharingOnly" or equivalent) before granting guest access, and must report this change explicitly in the completion report so the administrator is aware.
- What if the tenant does not yet have a Power Platform licence included? The operation reports the environment creation as skipped with an explanation rather than failing the entire run.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The provisioning operation MUST create the DarkFactory SharePoint team site if it does not already exist at the expected URL.
- **FR-002**: The provisioning operation MUST create the `DarkFactory-Settings` SharePoint list on the DarkFactory team site with the following columns if the list does not already exist: `Title` (single line, required, unique key), `Value` (single line, required), `Description` (multi-line, optional), `Category` (choice: Weather / Alerts / General, optional).
- **FR-003**: The provisioning operation MUST accept the home location as run-time input parameters: latitude, longitude, timezone (IANA), location display name, and city. It MUST seed the `DarkFactory-Settings` list with all Spec 001 required configuration keys (`Weather.Latitude`, `Weather.Longitude`, `Weather.Timezone`, `Weather.LocationName`, `Weather.City`, `Weather.ApiBaseUrl`, `Weather.TemperatureUnit`, `Weather.RefreshIntervalMinutes`) using the provided values. No placeholder defaults are written — the administrator must supply real values when running the operation. Keys that already exist in the list MUST NOT be overwritten.
- **FR-004**: The `DarkFactory-Settings` list MUST have broken permission inheritance from the parent site: Owners group → Full Control; Members and Visitors groups → Read only.
- **FR-005**: The provisioning operation MUST create the `DarkFactory` Microsoft Teams team if it does not already exist, and ensure a `General` channel exists within it.
- **FR-006**: Family members use personal Microsoft accounts invited as B2B guest accounts in the tenant. The provisioning operation MUST: (1) verify that external sharing is enabled at the tenant level and set it to allow guest access if not already configured; (2) verify that external sharing is enabled on the DarkFactory SharePoint site specifically; (3) grant each configured guest account at minimum Visitor (Read) access to the DarkFactory site. Guest accounts not yet accepted their invitation or not found in the tenant MUST be reported as warnings, not failures, so the remaining provisioning continues.
- **FR-007**: The provisioning operation MUST verify that a tenant App Catalog site exists. If it does not exist, it MUST create one.
- **FR-008**: The provisioning operation MUST first verify that SharePoint tenant Content Security Policy enforcement is enabled. If it is not enabled, it MUST report this as a required manual step. If enforcement is active, the operation MUST add `api.open-meteo.com` to the CSP allowlist (directive: `connect-src`) if it is not already present, using an exact directive-and-source match to detect duplicates. If already present, it MUST skip without error.
- **FR-009**: Microsoft 365 Business Basic does not permit creation of additional Power Platform environments — only the default environment (provisioned automatically by Microsoft) is available. The provisioning operation MUST retrieve and record the default Power Platform environment URL in the completion report for use by downstream specs. It MUST NOT attempt to create a new environment. If a dedicated environment is required in future, a Power Apps Premium licence is a prerequisite and must be documented as a gate at that time.
- **FR-010**: Every provisioning step MUST be idempotent — re-running the operation against a fully provisioned tenant MUST produce no changes and no errors.
- **FR-011**: The provisioning operation MUST produce a structured completion report that lists each resource with its outcome: `created`, `already-exists` (skipped), `skipped-with-warning`, or `failed`. The report MUST be readable without specialist knowledge.
- **FR-012**: The provisioning operation MUST NOT require the administrator to perform any manual steps in the Microsoft 365 admin portals — all configuration must be applied programmatically.

### Key Entities

- **TenantConfiguration**: The declared desired state of tenant-level settings — includes App Catalog URL, CSP entries, and Power Platform environment details.
- **WorkloadResources**: The set of workload-level resources to be provisioned — includes SharePoint site URL, list definitions, Teams team/channel names, and family member access grants.
- **ConfigSeedEntry**: A single key/value pair to be seeded into `DarkFactory-Settings` — includes key name, value (supplied by the administrator at run time for location keys; fixed for non-location keys such as `Weather.ApiBaseUrl`), category, and description.
- **ProvisioningReport**: The outcome of one provisioning run — includes per-resource status (created / already-exists / skipped-with-warning / failed) and a summary of changes made.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A fresh `aiwhisperer.onmicrosoft.com` tenant reaches provisioning-complete status (all workload resources created, App Catalog created) within 30 minutes of the administrator starting the provisioning operation. Deployment-ready status (App Catalog accessible for SPFx package upload) may require an additional 30 minutes on first-time App Catalog creation due to Microsoft's platform propagation delay. If the App Catalog already exists, deployment-ready status is reached within the same 30-minute window.
- **SC-002**: Re-running the provisioning operation against a fully provisioned tenant completes in under 5 minutes, makes zero changes, and produces zero errors.
- **SC-003**: All provisioned resources match the declared configuration — no manual portal steps are required after the operation completes.
- **SC-004**: A non-developer administrator can run the provisioning operation end-to-end by following the setup guide, without requiring assistance.
- **SC-005**: The completion report allows the administrator to identify exactly what was created vs skipped vs failed without reading technical logs.
- **SC-006**: A partial failure (one resource fails) does not prevent the remaining resources from being provisioned — the operation continues and the report identifies what needs to be retried.

---

## Assumptions

- The administrator holds Global Administrator or equivalent role (SharePoint Administrator + Teams Administrator) in the `aiwhisperer.onmicrosoft.com` tenant.
- The tenant is Microsoft 365 Business Basic — the minimum subscription confirmed for this project.
- Family members access TheDarkFactory365 solutions using their personal Microsoft accounts, invited as B2B guest accounts in the `aiwhisperer.onmicrosoft.com` tenant. The provisioning operation configures guest access but does not send invitations — inviting guest accounts is a manual step performed by the administrator before or after provisioning.
- The provisioning operation requires the administrator to supply the home location at run time (latitude, longitude, IANA timezone, display name, city). No placeholder coordinates are used — real values are seeded directly into `DarkFactory-Settings`.
- The provisioning operation is run from the administrator's local **Windows** machine, not from a CI/CD pipeline. macOS is not a supported platform. Unattended/scheduled execution is out of scope for v1.
- User licensing is out of scope — accounts must already hold appropriate Microsoft 365 licences before access grants are applied.
- The Power Platform environment provisioned is a new, dedicated environment named for TheDarkFactory365. If environment creation is not supported by the subscription, this step is documented as manually completable via the Power Platform admin centre.
- The DarkFactory SharePoint site is a modern team site (not a communication site), provisioned with a Microsoft 365 group backing it — this is required for the Microsoft Teams team association.
- Existing data in any already-provisioned resource is never destroyed or overwritten by re-running the operation.
