# Quickstart: Weather Display System
**Branch**: `001-weather-system` | **Date**: 2026-05-10

---

## Prerequisites

### Subscription (REQUIRED FIRST)
- Microsoft 365 **Business** subscription (Business Basic or higher)
- You must be the Global Administrator or SharePoint Administrator of the tenant
- Verify at: https://admin.microsoft.com → Users → Active users

### Development machine
- Node.js 22 LTS — https://nodejs.org/en/download
- Verify: `node --version` → should print `v22.x.x`
- npm 10+ (bundled with Node 22)
- Yeoman and SPFx generator: `npm install -g yo @microsoft/generator-sharepoint@1.22.2`
- PnP PowerShell: `Install-Module PnP.PowerShell -Scope CurrentUser`
- Microsoft 365 CLI (optional, for CSP): `npm install -g @pnp/cli-microsoft365`

---

## One-Time Tenant Setup

### 1. Add Open-Meteo to CSP allowlist

```powershell
Connect-SPOService -Url "https://{tenant}-admin.sharepoint.com"
Add-SPOContentSecurityPolicy -Source "https://api.open-meteo.com"
Get-SPOContentSecurityPolicy  # Verify it appears in the list
```

### 2. Verify or create the tenant App Catalog

```powershell
Connect-PnPOnline -Url "https://{tenant}-admin.sharepoint.com" -Interactive
$catalog = Get-PnPTenantAppCatalogUrl
if (-not $catalog) {
    Register-PnPAppCatalogSite `
        -Url "https://{tenant}.sharepoint.com/sites/appcatalog" `
        -Owner "{admin-email}" `
        -TimeZoneId 17  # 17 = Auckland; use Get-PnPTimeZoneId for other zones
}
```

### 3. Create the DarkFactory Settings list

```powershell
Connect-PnPOnline -Url "https://{tenant}.sharepoint.com/sites/DarkFactory" -Interactive

# Create list
New-PnPList -Title "DarkFactory-Settings" -Template GenericList

# Add columns
Add-PnPField -List "DarkFactory-Settings" -DisplayName "Value" -InternalName "DFValue" -Type Text
Add-PnPField -List "DarkFactory-Settings" -DisplayName "Description" -InternalName "DFDescription" -Type Note
Add-PnPField -List "DarkFactory-Settings" -DisplayName "Category" `
    -InternalName "DFCategory" -Type Choice `
    -Choices @("Weather","Alerts","General")

# Enforce unique Title (Key)
Set-PnPList -Identity "DarkFactory-Settings" -EnableVersioning $true

# Break permissions and set read-only for non-owners
# (Do this via SharePoint UI: List Settings → Permissions → Stop inheriting)
```

### 4. Populate config keys

```powershell
# Replace values with your actual home coordinates and timezone
$items = @(
    @{ Title="Weather.Latitude";              DFValue="-36.8509";                                   DFCategory="Weather" },
    @{ Title="Weather.Longitude";             DFValue="174.7645";                                    DFCategory="Weather" },
    @{ Title="Weather.Timezone";              DFValue="Pacific/Auckland";                            DFCategory="Weather" },
    @{ Title="Weather.LocationName";          DFValue="Home";                                        DFCategory="Weather" },
    @{ Title="Weather.City";                  DFValue="Auckland";                                    DFCategory="Weather" },
    @{ Title="Weather.ApiBaseUrl";            DFValue="https://api.open-meteo.com/v1/forecast";      DFCategory="Weather" },
    @{ Title="Weather.TemperatureUnit";       DFValue="celsius";                                     DFCategory="Weather" },
    @{ Title="Weather.RefreshIntervalMinutes"; DFValue="5";                                          DFCategory="Weather" }
)

foreach ($item in $items) {
    Add-PnPListItem -List "DarkFactory-Settings" -Values $item
}
```

---

## Development Setup

### 1. Scaffold the SPFx project

```bash
# In your local dev directory (not inside this spec repo)
mkdir dark-factory-weather && cd dark-factory-weather
yo @microsoft/sharepoint
```

Answer the generator prompts:
- Solution name: `dark-factory-weather`
- Target environment: **SharePoint Online only (latest)**
- Enable Teams: **Yes**
- Component type: **WebPart**
- Web part name: `DarkFactoryWeather`
- Framework: **React**

### 2. Install additional dependencies

```bash
npm install @fluentui/react@8
npm install --save-dev jest @testing-library/react @testing-library/jest-dom jest-axe jest-fetch-mock
```

### 3. Configure local workbench

Edit `config/serve.json`:
```json
{
  "initialPage": "https://{tenant}.sharepoint.com/sites/DarkFactory/_layouts/workbench.aspx"
}
```

### 4. Run local development server

```bash
gulp serve
```

Opens the SharePoint workbench on your DarkFactory team site. Add the web part from the toolbox to test live against the real config list and API.

---

## Build and Deploy

### Build production package

```bash
gulp bundle --ship
gulp package-solution --ship
```

Output: `sharepoint/solution/dark-factory-weather.sppkg`

### Deploy to App Catalog

```powershell
Connect-PnPOnline -Url "https://{tenant}.sharepoint.com/sites/appcatalog" -Interactive
Add-PnPApp -Path "./sharepoint/solution/dark-factory-weather.sppkg" `
    -Publish `
    -SkipFeatureDeployment  # Makes available tenant-wide without per-site install
```

### Add to Teams

1. Go to the DarkFactory team site: `https://{tenant}.sharepoint.com/sites/DarkFactory`
2. Create a new **modern page** → add the `DarkFactoryWeather` web part → **Publish** the page
3. In Microsoft Teams → DarkFactory team → General channel → `+` (Add tab)
4. Choose **SharePoint** (not Website) → select the published page
5. The weather web part is now live as a Teams tab

---

## Verify Deployment

- [ ] Open the Teams tab — web part loads and shows current weather
- [ ] Weather data refreshes automatically without page reload (wait 5 minutes)
- [ ] Stale data warning appears after 30 minutes if API is unavailable (test by temporarily blocking api.open-meteo.com in browser DevTools)
- [ ] Web part renders correctly when opened directly on the SharePoint page (outside Teams)
- [ ] Mobile: open the Teams tab on a mobile device — layout stacks vertically
- [ ] Run axe accessibility check in browser DevTools
