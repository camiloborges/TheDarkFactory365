# DarkFactory.ActivityAdvisor.psm1
# Provisions the DarkFactory-ActivityRequests SharePoint list and DarkFactory-Settings keys
# for the Outdoor Activity Weather Advisor (Spec 005).
# Idempotent — safe to re-run on an already-provisioned tenant.

function Invoke-ActivityAdvisorProvisioning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $SiteUrl,

        [Parameter(Mandatory)]
        [string] $AgentEndpoint,

        [Parameter(Mandatory)]
        [string] $NotificationRecipient
    )

    Write-Host "[ActivityAdvisor] Starting provisioning..." -ForegroundColor Cyan

    # ── DarkFactory-ActivityRequests list ─────────────────────────────────────────

    $listName = "DarkFactory-ActivityRequests"
    $existingList = Get-PnPList -Identity $listName -ErrorAction SilentlyContinue

    if (-not $existingList) {
        Write-Host "[ActivityAdvisor] Creating list: $listName"
        New-PnPList -Title $listName -Template GenericList | Out-Null

        # Activity — free text, required
        Add-PnPField -List $listName -DisplayName "Activity" -InternalName "Activity" `
            -Type Text -Required | Out-Null

        # Location — free text, required
        Add-PnPField -List $listName -DisplayName "Location" -InternalName "Location" `
            -Type Text -Required | Out-Null

        # RequestedDateTime — date + time, required
        Add-PnPField -List $listName -DisplayName "RequestedDateTime" -InternalName "RequestedDateTime" `
            -Type DateTime -Required | Out-Null

        # RiskLevel — choice, optional (populated by automation)
        Add-PnPFieldFromXml -List $listName -FieldXml @"
<Field Type="Choice" DisplayName="RiskLevel" Name="RiskLevel" Required="FALSE">
  <CHOICES>
    <CHOICE>Safe</CHOICE>
    <CHOICE>Caution</CHOICE>
    <CHOICE>Unsafe</CHOICE>
  </CHOICES>
</Field>
"@ | Out-Null

        # AssessmentReason — multiline plain text, optional (populated by automation)
        Add-PnPField -List $listName -DisplayName "AssessmentReason" -InternalName "AssessmentReason" `
            -Type Note | Out-Null

        # RequestedBy — person column, required
        Add-PnPField -List $listName -DisplayName "RequestedBy" -InternalName "RequestedBy" `
            -Type User -Required | Out-Null

        # Status — choice with default Pending, required
        Add-PnPFieldFromXml -List $listName -FieldXml @"
<Field Type="Choice" DisplayName="Status" Name="Status" Required="TRUE" Default="Pending">
  <CHOICES>
    <CHOICE>Pending</CHOICE>
    <CHOICE>Complete</CHOICE>
    <CHOICE>Error</CHOICE>
  </CHOICES>
</Field>
"@ | Out-Null

        # Index Status for efficient trigger queries
        Set-PnPField -List $listName -Identity "Status" -Values @{ Indexed = $true } | Out-Null

        Write-Host "[ActivityAdvisor] [OK] $listName provisioned with all columns" -ForegroundColor Green
    }
    else {
        Write-Host "[ActivityAdvisor] [SKIP] $listName already exists" -ForegroundColor Yellow
    }

    # ── DarkFactory-Settings keys ──────────────────────────────────────────────────

    $settingsListName = "DarkFactory-Settings"

    $settingsKeys = @(
        @{ Key = "ActivityAdvisor.AgentEndpoint";          Value = $AgentEndpoint },
        @{ Key = "ActivityAdvisor.NotificationRecipient";  Value = $NotificationRecipient }
    )

    foreach ($setting in $settingsKeys) {
        $existing = Get-PnPListItem -List $settingsListName `
            -Query "<View><Query><Where><Eq><FieldRef Name='Title'/><Value Type='Text'>$($setting.Key)</Value></Eq></Where></Query></View>" `
            -ErrorAction SilentlyContinue

        if (-not $existing) {
            Add-PnPListItem -List $settingsListName -Values @{
                Title = $setting.Key
                Value = $setting.Value
            } | Out-Null
            Write-Host "[ActivityAdvisor] [OK] Settings key '$($setting.Key)' added" -ForegroundColor Green
        }
        else {
            Write-Host "[ActivityAdvisor] [SKIP] Settings key '$($setting.Key)' already exists" -ForegroundColor Yellow
        }
    }

    Write-Host "[ActivityAdvisor] Provisioning complete." -ForegroundColor Cyan
}

Export-ModuleMember -Function Invoke-ActivityAdvisorProvisioning
