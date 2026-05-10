# TheDarkFactory365 — Release v1.0

**Released**: May 2026
**Specs delivered**: 001 Weather Display, 002 Rain Alert, 003 Tenant Infrastructure

---

## What we built

TheDarkFactory365 is a home automation layer on top of your existing Microsoft 365 Business Basic subscription. Version 1.0 delivers three things that work together: the plumbing to run the whole system, a live weather display in Teams, and a rain alert that messages you before you get caught outside.

---

## Spec 003 — Tenant Infrastructure

**The short version**: Before anything else could exist, we needed to set up the home base. Spec 003 built that.

This is the provisioning layer — a single PowerShell script that creates the DarkFactory SharePoint site, sets up the central settings store (a SharePoint list called `DarkFactory-Settings`), creates the DarkFactory Teams team, and configures the tenant so that SPFx web parts can be deployed and the weather API can be called from the browser without being blocked.

You run it once. It checks whether everything already exists before touching anything, so re-running it is always safe. Family member accounts are invited as B2B guests and given read access to the settings list so they can see the weather display but can't accidentally change the config.

The tenant-level changes this script makes — App Catalog, Content Security Policy, Power Platform environment — are the kind of thing that would normally require half an hour clicking around admin portals. Now it's one command.

---

## Spec 001 — Weather Display System

**The short version**: A dark-themed weather widget in your Teams tab that shows current conditions and a multi-day forecast, without any API key or paid subscription.

The weather data comes from Open-Meteo, a free and open weather API that doesn't require registration. The SPFx web part reads your home coordinates from the `DarkFactory-Settings` SharePoint list — the same list that Spec 003 created — and pulls current temperature, humidity, wind, UV index, sunrise/sunset, and a forecast broken into named periods (Morning, Afternoon, Evening, Tonight) plus the next two days.

The whole thing lives inside Teams as a tab on the DarkFactory team's General channel. It auto-refreshes every 5 minutes. If the network drops or the API is unavailable, it falls back to the last cached reading and shows a "Data may be outdated" banner so nobody's looking at stale data and thinking it's live.

The palette is a dark blue-grey theme that looks at home on a Teams dashboard at any time of day. All colours were tested for WCAG 2.1 AA contrast — every piece of text and every status indicator has enough contrast to be readable.

**What's in the box:**

- Current temperature, feels-like, humidity, wind speed and direction, UV index
- Sunrise and sunset times
- Today's remaining forecast in period blocks (only shows periods that are still ahead)
- Two-day daily forecast
- Rainy-day indicator changes the accent colour from cyan to blue
- "Setup Required" state walks you through the settings list if config is missing
- 73 unit tests covering all the service logic, mappers, and hooks

---

## Spec 002 — Rain Alert Automation

**The short version**: An Azure Logic App that checks the weather every 5 minutes and sends you a Teams message when it's raining or about to rain, so you don't need to check the display yourself.

This one lives in Azure rather than Microsoft 365. We chose Azure Logic Apps (Consumption plan) because Power Automate's HTTP connector — which you'd need to call the Open-Meteo API — is a premium feature not included in Business Basic. Logic Apps gives you the same SharePoint and Teams connectors, plus the free built-in HTTP connector, for about $1–2 a month.

The Logic App runs every 5 minutes. When it fires, it reads your location from `DarkFactory-Settings`, calls Open-Meteo, and checks two things in parallel:

1. **Is it raining right now?** If yes, and it hasn't sent you a current-rain alert in the last hour, it sends a Teams message.
2. **Is rain forecast in the next 48 hours?** If yes, and it hasn't sent a forecast alert in the last 3 hours, it sends a different Teams message.

Both suppression windows (how long to wait before sending the same alert again) are configurable settings in the SharePoint list. Set them to 0 to test, then restore them to sensible defaults.

The alert state — when each type of alert was last sent — is stored in a new SharePoint list called `DarkFactory-AlertState`. The Logic App reads that list and writes to it when it sends an alert. Nothing is stored inside the Logic App itself, which means the state survives a Logic App redeploy or region move.

**What we handled carefully:**

- The OAuth connections (SharePoint and Teams) are user-delegated. They're tied to the admin account's credentials. They expire after 90 days of inactivity. We added a section to the deployment guide explaining how to set up an Azure Monitor alert so you find out about this before it becomes a silent failure.
- The Teams connector's "notify user" action is user-delegated, which means it can only send messages from the account that authorised the connection. The `Alert.RecipientId` setting tells the connector who to send to, but in practice that has to match the authorising account.
- Error handling wraps the whole workflow in a Scope/Catch pattern. If anything fails — network error, expired OAuth, missing config row — the run is marked Failed in the run history and the next scheduled run starts clean. No manual intervention needed.

---

## How the three specs fit together

```
Spec 003: Tenant Infrastructure
  └─ Creates DarkFactory SharePoint site
  └─ Creates DarkFactory-Settings list
  └─ Creates DarkFactory Teams team
  └─ Configures App Catalog, CSP, Power Platform environment
       │
       ├── Spec 001: Weather Display System
       │     └─ SPFx web part reads Weather.* keys from DarkFactory-Settings
       │     └─ Deployed to App Catalog → pinned as Teams tab
       │
       └── Spec 002: Rain Alert Automation
             └─ Logic App reads Weather.* and Alert.* keys from DarkFactory-Settings
             └─ Writes suppression state to DarkFactory-AlertState
             └─ Sends Teams messages from the admin's connected account
```

You run Spec 003 first, always. Spec 001 and 002 can be deployed in either order after that.

---

## Things that need to happen manually

Logic Apps OAuth connections can't be authorised by a script. After you run the deployment:

1. Open the Logic App in the Azure portal
2. Go to API connections → authorise SharePoint (sign in as the admin)
3. Go to API connections → authorise Teams (same account)
4. Run the SharePoint seed script to add the Alert.* config rows and create the AlertState list
5. Enable the Logic App

The first run should succeed immediately. If it fails, the run history in the portal shows exactly which action failed and why.

---

## Estimated running costs

| Component | Monthly cost |
|---|---|
| Microsoft 365 Business Basic | Already paying |
| Azure Logic Apps (Consumption) | $0.50 – $2.00 |
| Azure resource group / subscription | Free tier |
| Open-Meteo API | Free, no key required |
| **Total new Azure spend** | **~$1–2/month** |

---

## What's not in v1.0

- **Multi-location support** — The weather display and alert system are configured for one home location. Adding a second location would require a separate web part instance and a second Logic App.
- **Push notifications outside Teams** — Alerts go to a Teams 1:1 chat only. Email or SMS would need a different connector or a separate workflow.
- **Historical weather data** — The display shows current and short-term forecast only. No logging or charting of past readings.
- **Family member alerts** — The Logic App sends to one recipient (the admin). Sending to family members would need a For Each loop over a list of recipients, which carries per-action billing.

These were deliberate YAGNI decisions. The system is designed so that new alert types or locations can be added as new parallel branches or new web part instances without changing what's already there.
