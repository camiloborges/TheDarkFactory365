# SDD Meets Office 365: Why SharePoint Development Needs a Discipline Reset

_Part 0 of the M365 series_

**TL;DR**  
SharePoint and Microsoft 365 development has a specification problem disguised as a tooling problem. Teams wrestle with SPFx scaffolding, Graph API permissions, and tenant configuration nightmares while skipping the one thing that would actually save them: writing down exactly what they're building before they build it. This series applies Specification Driven Development to the M365 ecosystem, starting with a deceptively simple Weather Web Part that exposes every trap in the platform.

---

## 1. The M365 Developer's Dirty Secret

Here's a confession from every SharePoint developer who has shipped something: they figured out the real requirements _after_ deploying to production.

The tenant had a different locale. The Graph API permissions weren't in the app catalog package. The property pane worked fine in the Workbench but exploded in a Teams tab context. The SharePoint Framework (SPFx) version in the pipeline didn't match what the developer tested locally.

None of these are code failures. They are **specification failures dressed up as platform failures.**

The platform is genuinely complex. But complexity is not an excuse for skipping intent. It's the reason you can't afford to.

### Why M365 Development Breaks Specs

The Microsoft 365 ecosystem has a property that punishes spec-skippers particularly hard: **everything is a surface.**

Your web part might render in:
- A SharePoint modern page
- A Teams personal app tab
- A Teams channel tab
- A Viva Connections dashboard card
- A Viva Connections adaptive card extension

Same code, wildly different behavior, different API surface areas, different authentication flows, different size constraints. If your spec doesn't identify the _surfaces_, you're not writing a spec—you're writing a vague wish.

---

## 2. What This Series Covers

This series teaches SDD in the M365 context through a concrete, end-to-end example: a **modern Weather Web Part** built with SPFx.

A Weather Web Part sounds trivial. It isn't. It touches every hard problem in M365 development:

| Problem | Why It Bites in M365 |
|---|---|
| External API calls | CSP headers, blocked domains, CORS, service principal auth |
| User context | Logged-in user locale, timezone, regional settings |
| Configuration management | Property pane vs. tenant-wide config vs. user preferences |
| Hosting surfaces | SharePoint page, Teams tab, Viva Connections card — each needs different handling |
| Caching | SPFx has no built-in cache; naive implementations hammer APIs on every page load |
| Testing | Workbench vs. production tenant behavior diverge constantly |

Each post in this series addresses one of these problems through the SDD lens: spec first, then build.

### The GitHub Spec Kit

Throughout this series we use the **GitHub Spec Kit** as the operational home for our specifications. Every specification artifact lives in GitHub:

- **Issues** carry individual requirements with GIVEN/WHEN/THEN acceptance criteria
- **Milestones** group related requirements into shippable slices
- **Discussions** capture research: what we considered, what we rejected, and why
- **Labels** classify requirements by surface, risk tier, and spec status (`spec:draft`, `spec:approved`, `spec:validated`)
- **Pull Requests** reference the spec issues they fulfil, creating a traceable thread from intent to code

This isn't bureaucracy. It's a feedback loop. When a requirement fails in production, you update the issue, close the PR, and open a new one. The spec stays alive.

---

## 3. The Principles We Carry In

Everything from the Dark Factory series applies here. The M365-specific overlays are:

**1. Surface first.** Before writing a single acceptance criterion, name every surface your feature must work on. Each surface is a separate context with its own constraints.

**2. Permissions are part of the spec.** Microsoft Graph and SharePoint REST API permissions are not a deployment afterthought. They are requirements. If your spec doesn't list the OAuth scopes your solution needs, your spec is incomplete.

**3. Tenant variance is a requirement category.** Your solution will run in tenants with different locale settings, different CSP policies, different external sharing configurations. Document the baseline assumptions your spec makes. Anything outside that baseline is explicitly out of scope or is its own requirement.

**4. The Workbench lies.** The local SPFx Workbench (`localhost`) runs without real tenant policies. Production behavior is the only ground truth. Specs must be validated in a developer tenant, not just a local gulp server.

---

## 4. The Bet

Here is the bet this series makes: if you write the full specification for the Weather Web Part before you write a single line of TypeScript, you will ship a better solution in fewer iterations than a team that dives straight into `yo @microsoft/sharepoint`.

The spec is not overhead. For M365 development, where the surface complexity is genuinely high and mistakes are hard to roll back in production tenants, the spec is the only rational way to work.

Let's build it right.

---

_Next: [Part 1 — The Weather Web Part Specification](./m365-part-1-weather-webpart-spec.md)_
