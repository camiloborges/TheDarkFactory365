# Tasks: TheDarkFactory365 Tenant Infrastructure

**Branch**: `003-tenant-infra` | **Date**: 2026-05-10 | **Plan**: [plan.md](plan.md) | **Spec**: [spec.md](spec.md)
**Script root**: `tenant-infra/` (separate directory, created in Phase 1)

**Tests**: Included — plan.md explicitly specifies Pester tests for all modules and idempotency verification.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no shared state dependencies)
- **[Story]**: Which user story this task belongs to ([US1], [US2], [US3])
- All paths are relative to `tenant-infra/` unless noted

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project scaffold and entry point parameter block. No live tenant operations.

- [X] T001 Create `tenant-infra/` directory with subdirectories `modules/` and `tests/modules/` — this is the separate PowerShell project root distinct from the spec repo
- [X] T002 [P] Install Pester 5+ on the development machine: `Install-Module Pester -Force -SkipPublisherCheck -Scope CurrentUser` — required for all test authoring in subsequent phases
- [X] T003 [P] Create `tenant-infra/Invoke-DarkFactoryProvisioning.ps1` parameter block — `[CmdletBinding(SupportsShouldProcess)]`, all 7 parameters per `contracts/script-interface.md` (`Latitude` with `[ValidateRange(-90,90)]`, `Longitude` with `[ValidateRange(-180,180)]`, `Timezone`, `LocationName`, `City`, `GuestEmails` with email format validation, `WhatIf` switch); parameter validation fires before any connections open

**Checkpoint**: Script file exists and parameter validation works (`-Latitude 200` → error; `-WhatIf` accepted)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Report module and connection orchestration. All user story modules return `ProvisioningResult` — this type and the report writer must exist before any module can be implemented or tested.

**⚠️ CRITICAL**: No user story module work can begin until this phase is complete

- [X] T004 Implement `tenant-infra/modules/DarkFactory.Report.psm1` — export two functions: `New-ProvisioningResult -Resource [string] -Status [string] -Detail [string]` returns a `[PSCustomObject]` with those three properties; `Write-ProvisioningReport -Results -TenantDomain -AppCatalogUrl -PowerPlatformUrl` outputs color-coded console table (green=Created, grey=AlreadyExists/AlreadyCorrect, yellow=SkippedWithWarning, red=Failed), writes `darkfactory-provisioning-report.txt` to current directory with same content plus AppCatalogUrl and PowerPlatformUrl, returns exit code: 0=all pass, 1=has warnings, 2=has failures
- [X] T005 Write Pester tests for `DarkFactory.Report.psm1` in `tenant-infra/tests/modules/DarkFactory.Report.Tests.ps1` — fixture Results array with one of each status; assert `Write-ProvisioningReport` creates the file; assert file contains each Resource name; assert exit code 0 when all AlreadyExists, 1 when any SkippedWithWarning and no Failed, 2 when any Failed
- [X] T006 Add module imports and connection orchestration to `tenant-infra/Invoke-DarkFactoryProvisioning.ps1` — `Import-Module` for all 8 modules from `modules/` directory; `Connect-SPOService -Url "https://aiwhisperer-admin.sharepoint.com"` (SPO Management Shell); `Connect-PnPOnline -Url "https://aiwhisperer-admin.sharepoint.com" -Interactive` (PnP); `Add-PowerAppsAccount` (Power Apps module); any connection failure → `Write-Error` and `exit 2` before provisioning begins; orchestrator collects all module results into `$results` array and passes to `Write-ProvisioningReport`

**Checkpoint**: Script runs, prompts for 3 browser logins, exits with empty but valid report

---

## Phase 3: User Story 1 — Provision Workload Resources (Priority: P1) 🎯 MVP

**Goal**: DarkFactory SharePoint site, `DarkFactory-Settings` config list with correct schema and seed data, list permissions, Teams team, General channel, and guest Visitor access — all provisioned idempotently from a single script run.

**Independent Test**: Run script with real home location params against a fresh tenant → verify DarkFactory site loads, config list has 8 keys with correct values, Teams team appears in client, guest accounts can open the site in a private browser. Re-run → all results are `AlreadyExists`/`AlreadyCorrect`.

### Tests for User Story 1

> **Write tests FIRST — verify they FAIL before implementing the corresponding module**

- [X] T007 Write Pester tests for `DarkFactory.List.psm1` in `tenant-infra/tests/modules/DarkFactory.List.Tests.ps1` — mock `Get-PnPList` returning `$null` → assert `New-PnPList` called with Title "DarkFactory-Settings"; mock returning list → assert `New-PnPList` not called; mock `HasUniqueRoleAssignments = $false` → assert `Set-PnPList -BreakRoleInheritance` called; mock `= $true` → assert NOT called (critical idempotency guard); mock CAML query finding existing key → assert `Add-PnPListItem` NOT called; mock returning no items → assert called; assert one result per seed key

### Implementation for User Story 1

- [X] T008 [P] [US1] Implement `Invoke-SiteProvisioning` in `tenant-infra/modules/DarkFactory.Site.psm1` — `Get-PnPSite -Url $siteUrl -ErrorAction SilentlyContinue` existence check; if absent: `New-PnPSite -Type TeamSite -Title "DarkFactory" -Alias "DarkFactory"`; wait loop (10 attempts × 15 seconds polling `Get-PnPSite`); return `ProvisioningResult` Created or AlreadyExists
- [X] T009 [P] [US1] Implement `Invoke-ExternalSharingProvisioning` in `tenant-infra/modules/DarkFactory.Site.psm1` — check `(Get-PnPTenant).SharingCapability`; `Set-PnPTenant -SharingCapability "ExternalUserAndGuestSharing" -EnableAzureADB2BIntegration $true` if not already ExternalUserAndGuestSharing; check `(Get-PnPTenantSite -Url $siteUrl).SharingCapability`; `Set-PnPTenantSite -Url $siteUrl -Sharing "ExternalUserAndGuestSharing"` if needed; return AlreadyCorrect if both already set; return Created if any change made
- [X] T010 [US1] Implement `DarkFactory.List.psm1` in `tenant-infra/modules/DarkFactory.List.psm1` with three exported functions: (1) `Invoke-ListProvisioning`: `Get-PnPList` check; `New-PnPList -Title "DarkFactory-Settings" -Template GenericList`; `Add-PnPField` for DFValue (Text, Required), DFDescription (Note), DFCategory (Choice: Weather/Alerts/General); (2) `Invoke-ListPermissionsProvisioning`: `HasUniqueRoleAssignments` guard → `Set-PnPList -BreakRoleInheritance -CopyRoleAssignments $false` → `Set-PnPListPermission` for Owners (Full Control), Members (Read), Visitors (Read); (3) `Invoke-ConfigSeedProvisioning -SeedEntries`: for each entry, CAML query for existing item by Title → `Add-PnPListItem` only if not found; one `ProvisioningResult` per seed key
- [X] T011 [P] [US1] Implement `DarkFactory.Teams.psm1` in `tenant-infra/modules/DarkFactory.Teams.psm1` — `Invoke-TeamsProvisioning`: `Get-PnPTeamsTeam | Where-Object { $_.DisplayName -eq "DarkFactory" }`; if absent: `New-PnPTeamsTeam -DisplayName "DarkFactory" -Visibility Private` (no `-Members` or `-Owners` — reduces provisioning lag); `Start-Sleep -Seconds 60`; `Get-PnPTeamsChannel -Team $team.Id | Where-Object { $_.DisplayName -eq "General" }`; `New-PnPTeamsChannel -Team $team.Id -DisplayName "General"` only if absent; separate `ProvisioningResult` for team and for channel
- [X] T012 [P] [US1] Implement `DarkFactory.Access.psm1` in `tenant-infra/modules/DarkFactory.Access.psm1` — `Invoke-GuestAccessProvisioning -SiteUrl -GuestEmails`: for each email: `Get-PnPUser -Identity $email -ErrorAction SilentlyContinue`; if found: `Add-PnPUser -LoginName $email -Group "DarkFactory Visitors"`; if not found: return `SkippedWithWarning` with Detail "Account not found in tenant — send B2B invitation first"; one `ProvisioningResult` per email
- [X] T013 [US1] Wire US1 modules into `tenant-infra/Invoke-DarkFactoryProvisioning.ps1` orchestrator — build `$seedEntries` array from parameters (5 location keys from params + 3 fixed: ApiBaseUrl/TemperatureUnit/RefreshIntervalMinutes); call `Invoke-SiteProvisioning`, `Invoke-ExternalSharingProvisioning`, `Invoke-ListProvisioning`, `Invoke-ListPermissionsProvisioning`, `Invoke-ConfigSeedProvisioning -SeedEntries $seedEntries`, `Invoke-TeamsProvisioning`, `Invoke-GuestAccessProvisioning -GuestEmails $GuestEmails`; each call wrapped in try/catch (failure → `Failed` result, continue to next); accumulate all results

**Checkpoint**: Run script with real params → DarkFactory site live, config list has 8 seeded keys with provided location values, Teams team visible in Teams client, guest accounts can read the site. Re-run → all AlreadyExists/Correct, no changes made.

---

## Phase 4: User Story 2 — Apply Tenant-Level Configuration (Priority: P2)

**Goal**: Tenant App Catalog created or confirmed, `api.open-meteo.com` added to CSP trusted sources, default Power Platform environment URL recorded in completion report — all idempotent.

**Independent Test**: Run script → verify `Get-PnPTenantAppCatalogUrl` returns a URL, `Get-SPOContentSecurityPolicy` includes `api.open-meteo.com`, completion report includes Power Platform default environment URL. Re-run → all AlreadyExists, no changes.

### Tests for User Story 2

- [X] T017 [P] [US2] Write Pester tests for `DarkFactory.AppCatalog.psm1` and `DarkFactory.CSP.psm1` in `tenant-infra/tests/modules/DarkFactory.TenantConfig.Tests.ps1` — mock `Get-PnPTenantAppCatalogUrl` returning `$null` → assert `Register-PnPAppCatalogSite` called with URL `https://aiwhisperer.sharepoint.com/sites/appcatalog`; mock returning URL → assert NOT called; mock `Get-SPOContentSecurityPolicy` returning list without `api.open-meteo.com` → assert `Add-SPOContentSecurityPolicy` called with exact source; mock list containing `not-api.open-meteo.com` (partial match) → assert `Add-SPOContentSecurityPolicy` STILL called (exact match, not substring); mock list containing exact `api.open-meteo.com` → assert NOT called

### Implementation for User Story 2

- [X] T014 [P] [US2] Implement `DarkFactory.AppCatalog.psm1` in `tenant-infra/modules/DarkFactory.AppCatalog.psm1` — `Invoke-AppCatalogProvisioning`: `Get-PnPTenantAppCatalogUrl`; if absent: `Register-PnPAppCatalogSite -Url "https://aiwhisperer.sharepoint.com/sites/appcatalog" -Owner "camilo.borges@aiwhisperer.onmicrosoft.com" -TimeZoneId 17`; when newly created, Detail includes "⚠ App Catalog created — wait 30 minutes before Spec 001 SPFx deployment"; return `ProvisioningResult` with resolved catalog URL in Detail
- [X] T015 [P] [US2] Implement `DarkFactory.CSP.psm1` in `tenant-infra/modules/DarkFactory.CSP.psm1` — `Invoke-CSPProvisioning -Source`: `Get-SPOContentSecurityPolicy`; exact string match (not `-like` or `-contains` substring): `$existing = $policies | Where-Object { $_ -eq $Source }`; `Add-SPOContentSecurityPolicy -Source $Source` if `$null -eq $existing`; separately check `(Get-PnPTenant).DelayContentSecurityPolicyEnforcement`; if `$true`: add additional `SkippedWithWarning` result "CSP enforcement is delayed — allowlist entry added but may have no effect until enforcement is enabled"
- [X] T016 [P] [US2] Implement `DarkFactory.PowerPlatform.psm1` in `tenant-infra/modules/DarkFactory.PowerPlatform.psm1` — `Get-PowerPlatformEnvironmentUrl`: `Get-AdminPowerAppEnvironment -Default`; extract `$env.Properties.LinkedEnvironmentMetadata.InstanceUrl`; return `ProvisioningResult` with Status=AlreadyExists, Detail="Default environment: $envUrl" (Business Basic cannot create additional environments — this step is read-only by design)
- [X] T018 [US2] Wire US2 modules into `tenant-infra/Invoke-DarkFactoryProvisioning.ps1` orchestrator — call `Invoke-AppCatalogProvisioning` (capture returned URL for report), `Invoke-CSPProvisioning -Source "https://api.open-meteo.com"`, `Get-PowerPlatformEnvironmentUrl` (capture URL for report); pass `$appCatalogUrl` and `$powerPlatformUrl` to `Write-ProvisioningReport`

**Checkpoint**: Script run → App Catalog confirmed, CSP entry present, Power Platform URL in report. Re-run → all AlreadyExists.

---

## Phase 5: User Story 3 — Provisioning Transparency and Recovery (Priority: P3)

**Goal**: Administrator can re-run the script safely at any time; completion report clearly identifies what happened; partial failures do not block remaining resources; idempotency is guaranteed across all modules.

**Independent Test**: (1) Run script twice — second run produces zero changes and exit code 0. (2) Simulate one module failing — script continues and reports the failure without stopping. (3) Run with `-WhatIf` — no changes made, output shows what would happen.

### Tests for User Story 3

- [X] T019 [US3] Write idempotency integration test in `tenant-infra/tests/Invoke-DarkFactoryProvisioning.Tests.ps1` — mock ALL `Get-*` cmdlets to return fully-provisioned state; invoke full script; assert: every result has Status `AlreadyExists` or `AlreadyCorrect`; exit code equals 0; assert `New-PnPSite`, `New-PnPList`, `New-PnPTeamsTeam`, `Add-PnPListItem`, `Register-PnPAppCatalogSite`, `Add-SPOContentSecurityPolicy`, `Add-PnPUser` are NOT called
- [X] T020 [P] [US3] Write parameter validation tests in `tenant-infra/tests/Invoke-DarkFactoryProvisioning.Tests.ps1` — assert `-Latitude 91` raises `ParameterArgumentValidationError`; `-Longitude -181` raises error; invalid email in `-GuestEmails` raises error; all errors raised BEFORE `Connect-SPOService` is called (connections never attempted on bad params)
- [X] T021 [P] [US3] Write `-WhatIf` test in `tenant-infra/tests/Invoke-DarkFactoryProvisioning.Tests.ps1` — invoke script with `-WhatIf`; assert `ShouldProcess` returns `$false` for all provisioning calls; assert no write cmdlets executed (`New-*`, `Add-*`, `Set-*`, `Register-*`); assert console output contains `[WhatIf]` prefix markers
- [X] T022 [P] [US3] Write edge case tests in `tenant-infra/tests/Invoke-DarkFactoryProvisioning.Tests.ps1` — (1) mock `HasUniqueRoleAssignments = $true` → assert `Set-PnPList -BreakRoleInheritance` NOT called; (2) mock CSP list containing `"not-api.open-meteo.com"` → assert `Add-SPOContentSecurityPolicy` IS called (partial host match must not prevent adding); (3) mock `Get-PnPTeamsTeam` returning empty on first call then populated on retry → assert wait loop handles lag correctly
- [X] T023 [US3] Write partial failure recovery test in `tenant-infra/tests/Invoke-DarkFactoryProvisioning.Tests.ps1` — mock `New-PnPList` to throw an exception; invoke full script; assert: result for "DarkFactory-Settings list" has Status `Failed`; assert modules AFTER the failing one (Teams, Access, AppCatalog, CSP) still execute and return results; assert final exit code is 2; assert `Write-ProvisioningReport` is called with the full results including the failure

**Checkpoint**: All 5 Pester test files pass. Script is verified idempotent, recovers from partial failures, and respects -WhatIf.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation accuracy verification and final test run.

- [X] T024 [P] Verify `tenant-infra/quickstart.md` parameter names exactly match the final `Invoke-DarkFactoryProvisioning.ps1` parameter block — update any discrepancies; verify example invocations are copy-pasteable
- [X] T025 [P] Verify `specs/003-tenant-infra/contracts/script-interface.md` example output matches actual `Write-ProvisioningReport` format — run report module in Pester with fixture data and compare output structure; update doc if format changed during implementation
- [X] T026 Run full Pester test suite: `Invoke-Pester -Path "tenant-infra/tests/" -Output Detailed` — confirm all tests pass; fix any failures before marking this phase complete

**Checkpoint**: 100% Pester pass rate. Docs match code. Script ready for first live tenant run.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — **BLOCKS all user stories** (ProvisioningResult type and report writer needed by every module)
- **US1 (Phase 3)**: Depends on Phase 2; T007 tests written before T008-T012 implemented; T013 wiring after T008-T012
- **US2 (Phase 4)**: Depends on Phase 2; T017 tests written before T014-T016 implemented; T018 wiring after T014-T016; US2 is independent of US1 (no shared tenant resources)
- **US3 (Phase 5)**: Depends on US1 and US2 complete (tests exercise the full orchestrator)
- **Polish (Phase 6)**: Depends on all story phases complete

### Key Within-Phase Dependencies

| Task | Depends on |
|---|---|
| T006 (connection orchestration) | T004 (Report module must exist to import) |
| T010 (List module) | T007 (tests written and failing first) |
| T013 (US1 wiring) | T008, T009, T010, T011, T012 all complete |
| T018 (US2 wiring) | T014, T015, T016 all complete |
| T019-T023 (US3 tests) | T013 and T018 complete (full orchestrator wired) |

### US1 vs US2 Independence

US1 (workload resources) and US2 (tenant-level config) are **independent** from a script execution standpoint — the SharePoint site, config list, and Teams team can be provisioned whether or not the App Catalog exists. The Spec 001 SPFx *deployment* needs the App Catalog, but provisioning the workload infrastructure does not.

### Parallel Opportunities

Tasks marked `[P]` within the same phase can run simultaneously:
- T002, T003: Setup tasks (different files, no dependencies)
- T008, T009, T011, T012: US1 modules (different files, all use ProvisioningResult from T004)
- T014, T015, T016, T017: US2 modules + tests (all independent files)
- T020, T021, T022: US3 tests (different test describe blocks in same file — write independently, merge)
- T024, T025: Polish doc checks (different files)

---

## Parallel Example: US1 Module Implementation

```
# Write T007 tests first — confirm they FAIL
# Then implement all US1 modules in parallel (after T004 report module complete):
Task: "T008 — DarkFactory.Site.psm1 Invoke-SiteProvisioning"
Task: "T009 — DarkFactory.Site.psm1 Invoke-ExternalSharingProvisioning"
Task: "T011 — DarkFactory.Teams.psm1"
Task: "T012 — DarkFactory.Access.psm1"
# Then sequentially:
Task: "T010 — DarkFactory.List.psm1 (depends on T007 tests)"
Task: "T013 — Wire all into orchestrator (depends on T008-T012)"
```

---

## Implementation Strategy

### MVP (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL)
3. Complete Phase 3: US1 (workload provisioning)
4. **STOP and VALIDATE**: Run against a test tenant or with `-WhatIf`; confirm all workload resources provisioned; re-run and confirm idempotency
5. This gives you: DarkFactory site + config list + Teams team + guest access — sufficient to begin Spec 001 SPFx development

### Incremental Delivery

1. Setup + Foundational → script skeleton with report
2. US1 → workload resources live (site, list, Teams, access)
3. US2 → tenant config (App Catalog, CSP) → ready for Spec 001 SPFx deployment
4. US3 → full idempotency verification → script is production-safe
5. Polish → docs verified → hand off to future maintenance

---

## Summary

| Phase | Tasks | Parallelizable | Story |
|---|---|---|---|
| Phase 1: Setup | T001–T003 | T002, T003 | — |
| Phase 2: Foundational | T004–T006 | — | — |
| Phase 3: US1 (P1) | T007–T013 | T008, T009, T011, T012 | US1 |
| Phase 4: US2 (P2) | T014–T018 | T014, T015, T016, T017 | US2 |
| Phase 5: US3 (P3) | T019–T023 | T020, T021, T022 | US3 |
| Phase 6: Polish | T024–T026 | T024, T025 | — |
| **Total** | **26 tasks** | **14 parallelizable** | |

