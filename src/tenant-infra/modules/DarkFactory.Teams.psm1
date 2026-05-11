<#
.SYNOPSIS
    Microsoft Teams team and channel provisioning via PnP PowerShell.
#>

function Invoke-TeamsProvisioning {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string] $TeamName,
        [Parameter(Mandatory)][string] $ChannelName
    )

    $results = @()

    $existingTeam = Get-PnPTeamsTeam | Where-Object { $_.DisplayName -eq $TeamName }

    if ($existingTeam) {
        $results += New-ProvisioningResult -Resource "$TeamName Teams team" -Status 'AlreadyExists' -Detail "TeamId: $($existingTeam.GroupId)"
    } else {
        if ($PSCmdlet.ShouldProcess($TeamName, 'Create Microsoft Teams team')) {
            $team = New-PnPTeamsTeam -DisplayName $TeamName -Visibility Private -ErrorAction Stop

            Write-Host "$TeamName Teams team created. Waiting for M365 Group provisioning..." -ForegroundColor Yellow

            # Retry loop — M365 Group provisioning can take 1–5 minutes; poll up to 20 × 15s = 5 min
            $teamId = $team.GroupId
            $attempts = 0
            do {
                Start-Sleep -Seconds 15
                $attempts++
                $resolvedTeam = Get-PnPTeamsTeam | Where-Object { $_.GroupId -eq $teamId }
            } while (-not $resolvedTeam -and $attempts -lt 20)

            if (-not $resolvedTeam) {
                $results += New-ProvisioningResult -Resource "$TeamName Teams team" -Status 'Failed' -Detail 'Team was created but GroupId did not become accessible within 5 minutes'
                return $results
            }

            $results += New-ProvisioningResult -Resource "$TeamName Teams team" -Status 'Created' -Detail "TeamId: $teamId — provisioned after $($attempts * 15)s"
            $existingTeam = $resolvedTeam
        } else {
            $results += New-ProvisioningResult -Resource "$TeamName Teams team" -Status 'AlreadyExists' -Detail "[WhatIf] Would create $TeamName team"
            $results += New-ProvisioningResult -Resource "$ChannelName channel"  -Status 'AlreadyExists' -Detail "[WhatIf] Would verify $ChannelName channel"
            return $results
        }
    }

    # Verify/create the configured channel
    $teamId = if ($existingTeam.GroupId) { $existingTeam.GroupId } else { $existingTeam.Id }
    $channels = Get-PnPTeamsChannel -Team $teamId -ErrorAction SilentlyContinue
    $targetChannel = $channels | Where-Object { $_.DisplayName -eq $ChannelName }

    if ($targetChannel) {
        $results += New-ProvisioningResult -Resource "$ChannelName channel" -Status 'AlreadyExists' -Detail 'Auto-created with team'
    } else {
        if ($PSCmdlet.ShouldProcess($teamId, "Create $ChannelName channel")) {
            New-PnPTeamsChannel -Team $teamId -DisplayName $ChannelName | Out-Null
            $results += New-ProvisioningResult -Resource "$ChannelName channel" -Status 'Created' -Detail "Created in $TeamName team"
        } else {
            $results += New-ProvisioningResult -Resource "$ChannelName channel" -Status 'AlreadyExists' -Detail "[WhatIf] Would create $ChannelName channel"
        }
    }

    return $results
}

Export-ModuleMember -Function Invoke-TeamsProvisioning
