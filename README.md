# TheDarkFactory365

> Bringing Dark Factory practices to Microsoft 365, one spec at a time.

---

## What this is

A working example of what happens when you apply **Spec-Driven Development (SDD)** and **AI-assisted engineering** to real Microsoft 365 development in 2026.

This is not a template library, a starter kit, or a polished product. It is a learning project — one where every decision is documented, every architectural trade-off is justified, and every implementation starts with a written specification. The specs, plans, tasks, and contracts are as much the deliverable as the code.

If any of it is useful to you, go ahead and use it.

---

## Background

I'm a former **Microsoft Certified Master** (SharePoint 2010 — back when that certification still existed) who spent the last several years deep in .NET engineering, AI, and Specification-Driven Development. Returning to the Microsoft 365 ecosystem in 2026 after a long gap, I wanted to see what it looks like to engage with the platform properly — not just "get it working" but apply the same rigour I'd use on any serious engineering project.

The twist: I'm doing it with AI as a genuine collaborator. Every spec, plan, and implementation in this repo was produced through **Claude Code** using a structured workflow called Spec Kit. The AI doesn't replace engineering judgment — it enforces it. You still have to know what you're building and why. But the spec process keeps the AI grounded and keeps the output traceable.

This repo is the evidence of that experiment. The blog series in [`blogs/m365/`](blogs/m365/) runs alongside it and explains the thinking.

---

## What's built

Three specifications, implemented end-to-end and working against a real Microsoft 365 Business Basic tenant.

### Spec 003 — Tenant Infrastructure (`tenant-infra/`)

A single idempotent PowerShell provisioning script that brings a fresh M365 tenant to the state every other spec depends on. Run it once; re-run it safely forever.

What it creates:
- The DarkFactory SharePoint team site
- The `DarkFactory-Settings` configuration list (the central settings store for all solutions)
- The DarkFactory Microsoft Teams team and General channel
- Tenant App Catalog (required for SPFx deployment)
- Content Security Policy allowlist entry for the Open-Meteo API
- B2B guest access for family member accounts

All static configuration (tenant URLs, resource names, group names, CSP sources) lives in a single `config.psd1` file. The modules are stateless — they receive every value as an explicit parameter, making them reusable across tenants. The script accepts home location as runtime parameters; no placeholder coordinates are ever written.

**Demonstrates**: PowerShell idempotency patterns, M365 admin automation with PnP PowerShell + SPO Management Shell + Power Apps Administration module, config-driven architecture for provisioning scripts.

---

### Spec 001 — Weather Display System (`weather-webpart/`)

A dark-themed SPFx web part pinned as a Teams tab in the DarkFactory team. Shows current weather conditions and a multi-day forecast using the Open-Meteo API — free, no API key, no registration required.

Reads home coordinates from the `DarkFactory-Settings` SharePoint list. Auto-refreshes every 5 minutes. Falls back to cached data with a visible "Data may be outdated" banner if the API is unavailable. All colours verified at WCAG 2.1 AA contrast ratios.

**What's visible in Teams:**
- Current temperature, feels-like, humidity, wind speed/direction, UV index, sunrise/sunset
- Today's remaining forecast in named period blocks (Morning, Afternoon, Evening, Tonight)
- Two-day daily forecast
- Rain accent (cyan → blue) when precipitation is active

73 unit tests covering service logic, mappers, and hooks.

**Demonstrates**: SPFx web part development, Fluent UI v8, SharePoint configuration list patterns, error/loading/fallback states, Teams tab deployment, WCAG compliance in dark-theme UIs.

---

### Spec 002 — Rain Alert Automation (`rain-alert/`)

An Azure Logic App (Consumption plan) that polls Open-Meteo every 5 minutes and sends a Teams message when it's raining now or rain is forecast in the next 48 hours.

Deployed to Azure rather than Power Automate because the HTTP connector (needed to call Open-Meteo) is a premium Power Automate feature not included in Business Basic. Logic Apps gives the same SharePoint and Teams connectors plus a free built-in HTTP connector for about $1–2/month.

Alert suppression windows (how long to wait before resending the same alert type) are configurable settings in `DarkFactory-Settings`. Alert state (when each alert type was last sent) is stored in a `DarkFactory-AlertState` SharePoint list — nothing is held inside the Logic App itself, so state survives a redeploy.

**Demonstrates**: Azure Logic Apps as a cost-effective Power Automate alternative, external API integration from Logic Apps, SharePoint-backed state management, Teams connector patterns, OAuth connection lifecycle management.

---

## How the three specs fit together

```
Spec 003: Tenant Infrastructure
  └─ Creates DarkFactory SharePoint site
  └─ Creates DarkFactory-Settings list (central config store)
  └─ Creates DarkFactory Teams team + General channel
  └─ Configures App Catalog, CSP allowlist, Power Platform environment
       │
       ├── Spec 001: Weather Display System
       │     └─ SPFx web part reads Weather.* keys from DarkFactory-Settings
       │     └─ Deployed to App Catalog → pinned as Teams tab
       │
       └── Spec 002: Rain Alert Automation
             └─ Logic App reads Weather.* and Alert.* keys from DarkFactory-Settings
             └─ Writes suppression timestamps to DarkFactory-AlertState
             └─ Sends Teams messages via user-delegated OAuth connection
```

Run Spec 003 first. Spec 001 and 002 can be deployed in either order after that.

---

## The workflow: Spec Kit

Every feature in this repo follows the same process, enforced by a set of AI skills called **Spec Kit**:

```
/speckit-specify   →  write the feature specification
/speckit-clarify   →  surface ambiguities, encode answers into the spec
/speckit-plan      →  produce the implementation plan and resolve research unknowns
/speckit-tasks     →  generate a dependency-ordered task list
/speckit-implement →  execute the tasks
                   ↓
[Spec Drift Sync]  →  verify all spec artifacts match the code before opening a PR
```

The output of each step lives in `specs/00X-feature-name/`:

```
specs/001-weather-system/
├── spec.md          ← what and why (business/user requirements)
├── plan.md          ← how (technical approach, design decisions, constitution check)
├── research.md      ← unknowns resolved before planning (platform constraints, API behaviours)
├── data-model.md    ← data shapes and state transitions
├── quickstart.md    ← how to run it
├── tasks.md         ← what was built, in order
└── contracts/       ← interface contracts (API shapes, script parameters, output formats)
```

The spec and the code are both deliverables. When an implementation decision diverges from the plan, the spec artifacts are updated before the PR is opened. This is enforced by the project constitution.

---

## The constitution

The project's engineering principles live in [`.specify/memory/constitution.md`](.specify/memory/constitution.md). Every plan must pass a Constitution Check before implementation begins. The active principles:

| # | Principle | Short form |
|---|---|---|
| I | Automation-First | Every recurring operation runs without human intervention |
| II | Platform-Native | Only official Microsoft extension points — no hacks, no unsupported APIs |
| III | Spec-Driven | No implementation without an approved spec and plan |
| IV | SOLID | Single responsibility, injected dependencies, no god objects |
| V | DRY | One source of truth for every config value, lookup, and style token |
| VI | YAGNI | Every complexity decision justified by a current, documented need |
| VII | Accessibility | WCAG 2.1 AA non-negotiable for all user-facing solutions |

The constitution is versioned. Changes follow a documented amendment procedure with a Sync Impact Report.

---

## Prerequisites

To run any of these solutions you need:

- A **Microsoft 365 Business Basic** subscription (or higher)
- Global Administrator access to the tenant
- A Windows machine running **PowerShell 7.4+**
- An **Azure subscription** for Spec 002 (Logic Apps, Consumption plan)

Start with the Spec 003 quickstart: [`specs/003-tenant-infra/quickstart.md`](specs/003-tenant-infra/quickstart.md)

---

## Repo structure

```
TheDarkFactory365/
├── specs/                    # Specification artifacts for every feature
│   ├── 001-weather-system/
│   ├── 002-rain-alert-automation/
│   └── 003-tenant-infra/
├── tenant-infra/             # Spec 003 — PowerShell provisioning script + modules + tests
├── weather-webpart/          # Spec 001 — SPFx web part source
├── rain-alert/               # Spec 002 — Azure Logic App ARM template
├── blogs/m365/               # Blog series: SDD meets Microsoft 365
├── docs/                     # Release notes
└── .specify/                 # Spec Kit configuration, templates, and project constitution
```

---

## Estimated running cost

| Component | Monthly cost |
|---|---|
| Microsoft 365 Business Basic | What you're already paying |
| Azure Logic Apps (Consumption) | ~$1–2 |
| Open-Meteo API | Free, no key required |
| **Total new Azure spend** | **~$1–2/month** |

---

## Blog series

The [`blogs/m365/`](blogs/m365/) directory runs alongside the implementation and explains the reasoning behind the SDD approach in the M365 context:

- [Part 0 — SDD Meets Office 365: Why SharePoint Development Needs a Discipline Reset](blogs/m365/m365-part-0-sdd-meets-office365.md)
- [Part 1 — The Weather Web Part Specification](blogs/m365/m365-part-1-weather-webpart-spec.md)

---

## Licence

MIT. If any of this is useful to you — the code, the spec process, the constitution, the workflow — take it.
