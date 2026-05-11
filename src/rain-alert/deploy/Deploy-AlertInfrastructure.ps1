<#
.SYNOPSIS
    Deploys the DarkFactory Rain Alert Azure infrastructure.

.DESCRIPTION
    Creates the rg-darkfactory resource group, deploys SharePoint and Teams API connections,
    and creates the la-darkfactory-rain-alert Logic App (Consumption plan) with an empty
    workflow placeholder. OAuth authorisation for both connections is performed manually
    in the Azure portal after this script completes (see quickstart.md).

.PARAMETER SubscriptionId
    Azure subscription ID to deploy into.

.PARAMETER Location
    Azure region. Defaults to australiaeast.

.PARAMETER ResourceGroupName
    Resource group name. Defaults to rg-darkfactory.

.PARAMETER LogicAppName
    Logic App name. Defaults to la-darkfactory-rain-alert.

.PARAMETER SharePointConnectionName
    SharePoint connection resource name. Defaults to connection-sharepoint-darkfactory.

.PARAMETER TeamsConnectionName
    Teams connection resource name. Defaults to connection-teams-darkfactory.

.EXAMPLE
    .\Deploy-AlertInfrastructure.ps1 -SubscriptionId "00000000-0000-0000-0000-000000000000"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [string]$Location = 'australiaeast',
    [string]$ResourceGroupName = 'rg-darkfactory',
    [string]$LogicAppName = 'la-darkfactory-rain-alert',
    [string]$SharePointConnectionName = 'connection-sharepoint-darkfactory',
    [string]$TeamsConnectionName = 'connection-teams-darkfactory'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Step { param([string]$Message) Write-Host "`n==> $Message" -ForegroundColor Cyan }
function Write-Done  { param([string]$Message) Write-Host "    OK: $Message" -ForegroundColor Green }
function Write-Warn  { param([string]$Message) Write-Host "    WARN: $Message" -ForegroundColor Yellow }

# ── 1. Set active subscription ──────────────────────────────────────────────
Write-Step "Setting subscription to $SubscriptionId"
az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) { throw "Failed to set subscription" }
Write-Done "Subscription set"

# ── 2. Create resource group (idempotent) ────────────────────────────────────
Write-Step "Creating resource group: $ResourceGroupName"
$rgExists = az group exists --name $ResourceGroupName | ConvertFrom-Json
if ($rgExists) {
    Write-Warn "Resource group $ResourceGroupName already exists — skipping create"
} else {
    az group create --name $ResourceGroupName --location $Location | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to create resource group" }
    Write-Done "Resource group created"
}

# ── 3. Deploy SharePoint connection ARM template ─────────────────────────────
Write-Step "Deploying SharePoint API connection: $SharePointConnectionName"
$spDeployOutput = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file "$ScriptDir\..\connections\sharepoint-connection.json" `
    --parameters connectionName=$SharePointConnectionName location=$Location `
    --name "deploy-sp-connection" `
    --mode Incremental `
    --query "properties.outputs" -o json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw "Failed to deploy SharePoint connection" }
$spConnectionRuntimeUrl = $spDeployOutput.connectionRuntimeUrl.value
Write-Done "SharePoint connection deployed (requires OAuth authorisation in portal)"

# ── 4. Deploy Teams connection ARM template ──────────────────────────────────
Write-Step "Deploying Teams API connection: $TeamsConnectionName"
$teamsDeployOutput = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file "$ScriptDir\..\connections\teams-connection.json" `
    --parameters connectionName=$TeamsConnectionName location=$Location `
    --name "deploy-teams-connection" `
    --mode Incremental `
    --query "properties.outputs" -o json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw "Failed to deploy Teams connection" }
$teamsConnectionRuntimeUrl = $teamsDeployOutput.connectionRuntimeUrl.value
Write-Done "Teams connection deployed (requires OAuth authorisation in portal)"

# ── 5. Create Logic App with empty workflow placeholder ──────────────────────
Write-Step "Creating Logic App: $LogicAppName"

# Empty workflow definition — connections are wired in after OAuth authorisation
$emptyDefinition = @{
    '$schema'    = 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
    contentVersion = '1.0.0.0'
    triggers    = @{}
    actions     = @{}
    outputs     = @{}
} | ConvertTo-Json -Depth 10 -Compress

$laExists = az logic workflow show --resource-group $ResourceGroupName --name $LogicAppName 2>$null
if ($laExists) {
    Write-Warn "Logic App $LogicAppName already exists — skipping create"
} else {
    az logic workflow create `
        --resource-group $ResourceGroupName `
        --name $LogicAppName `
        --location $Location `
        --definition $emptyDefinition `
        --state Disabled | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to create Logic App" }
    Write-Done "Logic App created (Disabled — enable after OAuth authorisation and workflow deployment)"
}

# ── 6. Deploy the Logic App workflow (with connection wiring) ────────────────
Write-Step "Deploying workflow definition: logic-app-definition.json"
Write-Warn "This step requires connections to be authorised first."
Write-Warn "If connections are not yet authorised, skip this step and run Deploy-WorkflowDefinition.ps1 after authorising."

$WorkflowDefinitionPath = Resolve-Path "$ScriptDir\..\logic-app-definition.json" -ErrorAction SilentlyContinue
$ConnectionParamsTemplate = "$ScriptDir\connection-parameters.json.template"

if ($WorkflowDefinitionPath -and (Test-Path $ConnectionParamsTemplate)) {
    # Build connection parameters with actual subscription ID, resource group, and runtime URLs
    $connectionParamsJson = Get-Content $ConnectionParamsTemplate -Raw
    $connectionParamsJson = $connectionParamsJson -replace '\{SUBSCRIPTION_ID\}', $SubscriptionId
    $connectionParamsJson = $connectionParamsJson -replace '\{RESOURCE_GROUP\}', $ResourceGroupName
    $connectionParamsJson = $connectionParamsJson -replace '\{LOCATION\}', $Location

    # Inject connectionRuntimeUrl values from ARM deployment outputs
    if ($spConnectionRuntimeUrl) {
        $spRuntimeHost = $spConnectionRuntimeUrl -replace 'https?://', ''
        $connectionParamsJson = $connectionParamsJson -replace '\{SHAREPOINT_RUNTIME_URL\}', $spRuntimeHost
    }
    if ($teamsConnectionRuntimeUrl) {
        $teamsRuntimeHost = $teamsConnectionRuntimeUrl -replace 'https?://', ''
        $connectionParamsJson = $connectionParamsJson -replace '\{TEAMS_RUNTIME_URL\}', $teamsRuntimeHost
    }

    $tempParamsFile = [System.IO.Path]::GetTempFileName() + '.json'
    $connectionParamsJson | Out-File -FilePath $tempParamsFile -Encoding utf8

    az logic workflow update `
        --resource-group $ResourceGroupName `
        --name $LogicAppName `
        --definition "@$($WorkflowDefinitionPath.Path)" `
        --parameters "@$tempParamsFile" | Out-Null

    Remove-Item $tempParamsFile -Force -ErrorAction SilentlyContinue

    if ($LASTEXITCODE -ne 0) {
        throw "Workflow deployment failed. Ensure connections are authorised in the portal before deploying the workflow definition."
    }
    Write-Done "Workflow deployed (Logic App remains Disabled until connections are authorised and verified)"
} else {
    Write-Warn "logic-app-definition.json not found — skipping workflow deployment"
}

# ── Summary ──────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "============================================================" -ForegroundColor White
Write-Host " Deployment complete. Next steps:" -ForegroundColor White
Write-Host "  1. Open Azure portal -> Logic Apps -> $LogicAppName" -ForegroundColor White
Write-Host "  2. Go to API connections -> $SharePointConnectionName -> Edit -> Authorise" -ForegroundColor White
Write-Host "  3. Go to API connections -> $TeamsConnectionName -> Edit -> Authorise" -ForegroundColor White
Write-Host "  4. Run Invoke-AlertSeedData.ps1 to provision SharePoint data" -ForegroundColor White
Write-Host "  5. Re-run this script OR run Deploy-WorkflowDefinition.ps1 to deploy workflow" -ForegroundColor White
Write-Host "  6. Enable the Logic App" -ForegroundColor White
Write-Host "============================================================" -ForegroundColor White
