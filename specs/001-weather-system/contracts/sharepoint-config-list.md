# Contract: SharePoint Configuration List
**List name**: `DarkFactory-Settings` | **Date**: 2026-05-10
**Site**: `https://{tenant}.sharepoint.com/sites/DarkFactory` (DarkFactory team site)

---

## List Schema

| Column display name | Internal name | SharePoint type | Required | Unique | Notes |
|---|---|---|---|---|---|
| Title | Title | Single line text (255) | Yes | Yes | Config key — enforced unique via list setting |
| Value | DFValue | Single line text (255) | Yes | No | Config value as string |
| Description | DFDescription | Note (multi-line, plain text) | No | No | Human-readable purpose |
| Category | DFCategory | Choice | No | No | Grouping for admin UI |

**Category choices**: `Weather`, `Alerts`, `General`

---

## Permissions

Break inheritance from parent site on the list (not the site). Apply:

| Principal | Permission level |
|---|---|
| DarkFactory Owners | Full Control |
| DarkFactory Members | Read |
| DarkFactory Visitors | Read |

All family members must have at minimum Visitor access to the DarkFactory team site so their M365 session token can read the list via `spHttpClient`.

---

## Read API

The web part reads config items using the SharePoint REST API via `spHttpClient`:

```
GET {siteUrl}/_api/web/lists/getbytitle('{listName}')/items
  ?$filter=Title eq '{key}'
  &$select=Title,DFValue
```

All config reads happen at web part initialisation. The `ConfigService` reads all required keys in parallel (Promise.all), assembles an `IWeatherConfig`, and fails with `DisplayState.SetupRequired` if any required key is missing or empty.

---

## Required Keys — Spec 001

| Title (Key) | Example value | Required | Notes |
|---|---|---|---|
| `Weather.Latitude` | `-36.8509` | Yes | WGS84 decimal — negative = South |
| `Weather.Longitude` | `174.7645` | Yes | WGS84 decimal — positive = East |
| `Weather.Timezone` | `Pacific/Auckland` | Yes | IANA timezone identifier |
| `Weather.LocationName` | `Home` | Yes | Shown in web part header |
| `Weather.City` | `Auckland` | No | Shown in web part subheader |
| `Weather.ApiBaseUrl` | `https://api.open-meteo.com/v1/forecast` | Yes | Allows provider URL override |
| `Weather.TemperatureUnit` | `celsius` | No | `celsius` or `fahrenheit`; defaults to `celsius` |
| `Weather.RefreshIntervalMinutes` | `5` | No | Integer; defaults to `5` |

**Reserved keys for Spec 002** (do not use):
- `Alerts.*` — owned by the Rain Alert Automation spec

---

## Setup Validation

When the web part loads, `ConfigService.validate()` checks:
1. All keys marked `Required = Yes` above are present and non-empty
2. `Weather.Latitude` and `Weather.Longitude` parse as valid floats
3. `Weather.RefreshIntervalMinutes` parses as a positive integer ≥ 1

If validation fails, the web part renders `DisplayState.SetupRequired` with a message listing the missing or invalid keys and directing the administrator to the `DarkFactory-Settings` list.
