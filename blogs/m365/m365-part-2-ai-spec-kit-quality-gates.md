# The AI Spec Kit: Quality Gates You Can't Skip

_Part 2 of the M365 series_

**TL;DR**  
Part 0 promised a GitHub-Issues-based Spec Kit. We didn't use it. We built something better: a set of AI skills in Claude Code that enforce the full SDD gate sequence through conversation and file output, with a project constitution that acts as a standing compliance check on every feature. This post is the honest account of what that looks like in practice.

---

## 1. Why We Didn't Use GitHub Issues

Part 0 laid out a workflow where requirements live as GitHub Issues, research as Discussions, and pull requests reference the spec issues they fulfil. It's a reasonable approach, and plenty of teams use it. We tried it mentally for about five minutes and then didn't.

The problem is friction at the writing stage. GitHub Issues are optimised for tracking — not for thinking. The GIVEN/WHEN/THEN structure, the surface matrix, the architecture decision records, the research decisions — none of these fit naturally into issue templates. You end up with either a wall of prose in one issue or a scattered mess of linked issues that's hard to read as a coherent specification.

What we wanted was a workflow where the spec lived as readable, reviewable files alongside the code — where a developer (or an AI) could read `spec.md`, `plan.md`, and `tasks.md` and know exactly what to build without context from anywhere else. GitHub Pull Requests still carry the code review and the merge decision. But the spec lives in the repo.

The tooling that makes this work is Claude Code and a set of skills we call the Spec Kit.

---

## 2. What the Spec Kit Is

The Spec Kit is a set of slash commands (skills) for Claude Code that guide a feature through the SDD gate sequence and produce spec artifacts as files. The skills are defined in `.claude/skills/` and run inside Claude Code sessions.

The gate sequence:

```
/speckit-specify   →  spec.md
/speckit-clarify   →  spec.md (updated with clarification answers)
/speckit-plan      →  plan.md + research.md + data-model.md + quickstart.md + contracts/
/speckit-tasks     →  tasks.md
/speckit-implement →  code
                   ↓
[Spec Drift Sync]  →  all artifacts verified against the code
```

Each gate produces a file. Each file is reviewed before the next gate opens. The AI does not move forward until the human signs off.

This matters because AI-assisted development has a specific failure mode: the model fills in what it thinks you mean and moves on. The gate sequence prevents that. `/speckit-clarify` literally cannot produce a plan until ambiguities are resolved. `/speckit-plan` literally cannot produce tasks until the research is complete. The workflow is the discipline.

---

## 3. The Skills, One by One

### `/speckit-specify`

Takes a natural language feature description and produces a `spec.md` with:

- User stories in priority order (P1–P3), each with an independent test description and GIVEN/WHEN/THEN acceptance scenarios
- Edge cases enumerated explicitly
- Functional requirements numbered (FR-001, FR-002, ...)
- Success criteria (measurable outcomes, not vague goals)
- Assumptions listed (what the spec takes as given)

For the weather web part, this produced the surface matrix decision (Teams channel tab only, Viva Connections deferred) and the configuration architecture decision (SharePoint list, not property pane) before a line of planning happened.

### `/speckit-clarify`

Asks up to five targeted questions to close the ambiguities in the spec. Not general questions — surgical ones that, if unanswered, would cause an implementation decision to be made by default by whoever picks up the task.

For the weather web part, the clarifications that mattered:

- _How should "today remaining" be broken up?_ → Period blocks: Morning / Afternoon / Evening / Tonight
- _After how long should cached data be considered stale?_ → Never expire, but show a staleness banner after 30 minutes
- _Who can edit the configuration store?_ → Administrator only; family members are read-only

These answers were encoded back into `spec.md`. Not in a separate document. In the spec itself, so the spec is always self-contained.

### `/speckit-plan`

Produces the implementation plan from the approved spec. The output covers:

- **Research phase**: every unknown that could block implementation, resolved before planning. For the weather web part, this is where the API selection was decided (Open-Meteo vs OpenWeatherMap vs MSN) and the CSP enforcement risk was identified and documented.
- **Technical context**: language, dependencies, testing approach, platform constraints
- **Constitution Check**: every plan.md must verify each of the seven constitutional principles before implementation begins. A failing gate is a blocker.
- **Project structure**: the exact directory layout and what lives where
- **Implementation phases**: phased delivery with checkpoints
- **Key design decisions**: every significant architectural choice, with its rationale, recorded in the plan

For M365 features, this phase is where the most platform-specific knowledge is required. The skill has an M365 variant — the `m365-spec-advisor` — that asks M365-specific questions before the plan is written: subscription tier, SPFx version, surface matrix, CSP status, connector licensing. It surfaces the gotchas before they become failures.

### `/speckit-tasks`

Takes the approved plan and produces `tasks.md`: a dependency-ordered list of implementation tasks. Each task is specific enough that it has one clear definition of done. Parallelisable tasks are marked `[P]`. Tests are written before the implementation they test.

For the weather web part: 73 unit tests, covering service logic, WMO weather code mapping, period-block grouping, error and loading states, and the configuration read path. All written as tasks, all tracked.

### `/speckit-implement`

Works through `tasks.md` sequentially, marking each task complete when it passes its definition of done. The key discipline here is that the AI does not jump ahead. One task at a time, in dependency order.

---

## 4. The M365-Specific Skills

### `m365-spec-advisor`

Runs before `/speckit-specify` for any M365 feature. Asks the questions that M365 development requires before writing a spec:

- What Microsoft 365 subscription tier is confirmed? (Different tiers change what's possible — dramatically.)
- Which surfaces must the solution support? (SharePoint page, Teams tab, Teams personal tab, Viva Connections — each has different constraints.)
- Is there a premium connector dependency? (HTTP connector in Power Automate is premium; this killed the original Spec 002 design and redirected it to Azure Logic Apps.)
- Has CSP enforcement been checked? (Active since March 2026 — any external API call from an SPFx web part requires a tenant-level allowlist entry.)

These questions are not optional. They are the M365 analogue of the "surface matrix" — the step that catches production failures before they are production failures.

### `m365-technical-reviewer`

Runs against specs, plans, and code to verify compliance with M365 platform constraints. For the weather web part, this is what caught that Fluent UI v9 (which is what you find in most 2025 tutorials) is not yet production-stable for SPFx at this SPFx version. The implementation used Fluent UI v8. The spec was updated before a line of component code was written.

This skill is also what enforces the "no unsupported APIs" principle in the constitution. MSN Weather is a common shortcut in community samples. It is not a supported API. The technical reviewer flags it; the spec document records the rejection and the reason.

---

## 5. The Constitution

Every project in the Spec Kit workflow has a constitution — a set of principles that every plan must pass before implementation begins. Ours lives at `.specify/memory/constitution.md` and is the single highest-authority document in the repository.

For TheDarkFactory365, the seven principles are:

| Principle | What it enforces |
|---|---|
| I. Automation-First | Every recurring operation runs unattended |
| II. Platform-Native | Only official M365 extension points |
| III. Spec-Driven | No code without an approved spec and plan |
| IV. SOLID | Single responsibility, injected dependencies |
| V. DRY | One source of truth for every value |
| VI. YAGNI | Complexity justified by current need only |
| VII. Accessibility | WCAG 2.1 AA non-negotiable |

Every `plan.md` includes a Constitution Check section — a table that explicitly evaluates each principle against the feature. A failing gate blocks implementation. There are no exceptions without a documented justification in a Complexity Tracking entry.

The constitution is versioned. When we added the config-driven provisioning pattern (all static values in `config.psd1`, modules stateless) to Spec 003, that was a MINOR amendment to Principle V — extending DRY to explicitly cover provisioning script configuration. The amendment procedure produces a Sync Impact Report so you know what changed, what was affected, and why.

---

## 6. The Gate That Gets Skipped: Spec Drift Sync

Here is the gate that most SDD workflows treat as optional. We made it mandatory.

During implementation, decisions get made that weren't in the plan. An implementation detail turns out to work differently than expected. A module gets an extra parameter. A config file gets added. A design decision gets changed mid-task.

If you don't sync these back into the spec artifacts, you end up with documentation that describes a system that doesn't exist. This is spec drift, and it compounds. Six months later you're reading a plan that describes the architecture before three refactors and wondering which one is current.

The Spec Drift Sync gate requires — before a PR is opened — that the following are verified against the code:

| Artifact | What to check |
|---|---|
| `contracts/` | Parameter block, output format, example invocations match the final code |
| `quickstart.md` | Run instructions are accurate; all prerequisites are listed |
| `plan.md` project structure | File tree matches what was actually created |
| `plan.md` Key Design Decisions | All significant implementation decisions recorded |
| `plan.md` Constitution Check | Notes reflect the final design, not the planned design |
| `tasks.md` | Any divergence from the plan recorded as a completed post-implementation task |

This is enforced in two places. The plan template (`plan-template.md`) includes a Spec Drift Sync Checkpoint section — a checkbox table that has to be completed before the PR is opened. And the constitution's Development Workflow section names it as a required gate.

For the config-driven refactor on Spec 003 — extracting all hardcoded constants to `config.psd1` — this gate caught six artifacts that needed updating: the script interface contract, the plan project structure, the Key Design Decisions table, the Constitution Check DRY note, the quickstart, and the tasks list. All updated in the same session as the refactor, before the PR.

---

## 7. What This Looks Like End-to-End

Here is the actual sequence for the weather web part:

1. **`/speckit-specify`**: describe the feature in natural language → `spec.md` produced with user stories, acceptance scenarios, functional requirements, success criteria
2. **`/speckit-clarify`**: five questions answered (period blocks, staleness behaviour, permissions model) → answers encoded into `spec.md`
3. **M365 Technical Reviewer**: validates the spec → surfaces Fluent UI v8 requirement, CSP enforcement status, surface matrix decisions → spec updated
4. **`/speckit-plan`**: research phase (API selection, subscription risk, CSP risk all resolved) → `plan.md`, `research.md`, `data-model.md`, `quickstart.md`, `contracts/` produced → Constitution Check passed
5. **`/speckit-tasks`**: `tasks.md` produced, tests-first order enforced, parallel tasks identified
6. **`/speckit-implement`**: 73 unit tests written and passing; web part deployed and pinned as Teams tab; all tasks marked complete
7. **Spec Drift Sync**: contracts, quickstart, and plan verified against the shipped code; no drift found

Total time for the spec-through-implementation cycle on Spec 001: one session. The quality of the specification made implementation fast because there were no decisions left to make during coding.

---

## 8. The Honest Assessment

This workflow has a cost: **you have to know enough to review the spec.** The AI produces good structure and catches obvious gaps, but if you don't know that MSN Weather is undocumented, you won't know to ask whether the API is supported. If you don't know that Fluent UI v8 and v9 are different things for SPFx, the spec will pass review and the build will break.

This is a feature, not a bug. SDD is not a way to produce code without expertise. It is a way to make sure expertise produces the right code. The AI accelerates the writing, the structure, and the enforcement. The domain knowledge — what M365 can and cannot do, what is supported and what is a community hack — still has to come from somewhere.

For this project, that somewhere is a former Microsoft Certified Master who took a long detour through .NET and AI and came back to the M365 platform. The Spec Kit is the structure that captures the knowledge and makes it executable. It is not a substitute for the knowledge.

---

_Part 3 coming: the rain alert — where Power Automate ran into a licensing wall and Azure Logic Apps became the answer._
