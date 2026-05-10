<#
.SYNOPSIS
    Microsoft Teams team and channel provisioning via PnP PowerShell.
#>

function Invoke-TeamsProvisioning {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $results = @()
    $teamName = 'DarkFactory'

    $existingTeam = Get-PnPTeamsTeam | Where-Object { $_.DisplayName -eq $teamName }

    if ($existingTeam) {
        $results += New-ProvisioningResult -Resource 'DarkFactory Teams team' -Status 'AlreadyExists' -Detail "TeamId: $($existingTeam.GroupId)"
    } else {
        if ($PSCmdlet.ShouldProcess($teamName, 'Create Microsoft Teams team')) {
            $team = New-PnPTeamsTeam -DisplayName $teamName -Visibility Private -ErrorAction Stop

            Write-Host "DarkFactory Teams team created. Waiting for M365 Group provisioning..." -ForegroundColor Yellow

            # Retry loop — M365 Group provisioning can take 1–5 minutes; poll up to 20 × 15s = 5 min
            $teamId = $team.GroupId
            $attempts = 0
            do {
                Start-Sleep -Seconds 15
                $attempts++
                $resolvedTeam = Get-PnPTeamsTeam | Where-Object { $_.GroupId -eq $teamId }
            } while (-not $resolvedTeam -and $attempts -lt 20)

            if (-not $resolvedTeam) {
                $results += New-ProvisioningResult -Resource 'DarkFactory Teams team' -Status 'Failed' -Detail 'Team was created but GroupId did not become accessible within 5 minutes'
                return $results
            }

            $results += New-ProvisioningResult -Resource 'DarkFactory Teams team' -Status 'Created' -Detail "TeamId: $teamId — provisioned after $($attempts * 15)s"
            $existingTeam = $resolvedTeam
        } else {
            $results += New-ProvisioningResult -Resource 'DarkFactory Teams team' -Status 'AlreadyExists' -Detail '[WhatIf] Would create DarkFactory team'
            $results += New-ProvisioningResult -Resource 'General channel' -Status 'AlreadyExists' -Detail '[WhatIf] Would verify General channel'
            return $results
        }
    }

    # Verify/create General channel
    $teamId = if ($existingTeam.GroupId) { $existingTeam.GroupId } else { $existingTeam.Id }
    $channels = Get-PnPTeamsChannel -Team $teamId -ErrorAction SilentlyContinue
    $generalChannel = $channels | Where-Object { $_.DisplayName -eq 'General' }

    if ($generalChannel) {
        $results += New-ProvisioningResult -Resource 'General channel' -Status 'AlreadyExists' -Detail 'Auto-created with team'
    } else {
        if ($PSCmdlet.ShouldProcess($teamId, 'Create General channel')) {
            New-PnPTeamsChannel -Team $teamId -DisplayName 'General' | Out-Null
            $results += New-ProvisioningResult -Resource 'General channel' -Status 'Created' -Detail 'Created in DarkFactory team'
        } else {
            $results += New-ProvisioningResult -Resource 'General channel' -Status 'AlreadyExists' -Detail '[WhatIf] Would create General channel'
        }
    }

    return $results
}

Export-ModuleMember -Function Invoke-TeamsProvisioning
