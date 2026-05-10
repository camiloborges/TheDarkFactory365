<#
.SYNOPSIS
    SharePoint site provisioning and external sharing configuration.
#>

function Invoke-SiteProvisioning {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string] $SiteUrl
    )

    $existing = Get-PnPSite -Url $SiteUrl -ErrorAction SilentlyContinue
    if ($existing) {
        return New-ProvisioningResult -Resource 'DarkFactory site' -Status 'AlreadyExists' -Detail $SiteUrl
    }

    if ($PSCmdlet.ShouldProcess($SiteUrl, 'Create SharePoint Team Site')) {
        New-PnPSite -Type TeamSite -Title 'DarkFactory' -Alias 'DarkFactory' -ErrorAction Stop | Out-Null

        # Poll until site is accessible (up to 10 × 15s = 2.5 min)
        $attempts = 0
        do {
            Start-Sleep -Seconds 15
            $attempts++
            $site = Get-PnPSite -Url $SiteUrl -ErrorAction SilentlyContinue
        } while (-not $site -and $attempts -lt 10)

        if (-not $site) {
            return New-ProvisioningResult -Resource 'DarkFactory site' -Status 'Failed' -Detail 'Site did not become accessible within 2.5 minutes'
        }

        return New-ProvisioningResult -Resource 'DarkFactory site' -Status 'Created' -Detail $SiteUrl
    }

    return New-ProvisioningResult -Resource 'DarkFactory site' -Status 'AlreadyExists' -Detail "[WhatIf] Would create $SiteUrl"
}

function Invoke-ExternalSharingProvisioning {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string] $SiteUrl
    )

    $results = @()
    $tenantSharing = (Get-PnPTenant).SharingCapability

    if ($tenantSharing -eq 'ExternalUserAndGuestSharing') {
        $results += New-ProvisioningResult -Resource 'External sharing (tenant)' -Status 'AlreadyCorrect' -Detail "SharingCapability = $tenantSharing"
    } else {
        if ($PSCmdlet.ShouldProcess('Tenant', 'Set SharingCapability to ExternalUserAndGuestSharing')) {
            Set-PnPTenant -SharingCapability 'ExternalUserAndGuestSharing' -EnableAzureADB2BIntegration $true
            $results += New-ProvisioningResult -Resource 'External sharing (tenant)' -Status 'Created' -Detail 'Set to ExternalUserAndGuestSharing'
        } else {
            $results += New-ProvisioningResult -Resource 'External sharing (tenant)' -Status 'AlreadyCorrect' -Detail '[WhatIf] Would set ExternalUserAndGuestSharing'
        }
    }

    $siteSharing = (Get-PnPTenantSite -Url $SiteUrl).SharingCapability
    if ($siteSharing -eq 'ExternalUserAndGuestSharing') {
        $results += New-ProvisioningResult -Resource 'External sharing (site)' -Status 'AlreadyCorrect' -Detail "SharingCapability = $siteSharing"
    } else {
        if ($PSCmdlet.ShouldProcess($SiteUrl, 'Set site SharingCapability to ExternalUserAndGuestSharing')) {
            Set-PnPTenantSite -Url $SiteUrl -Sharing 'ExternalUserAndGuestSharing'
            $results += New-ProvisioningResult -Resource 'External sharing (site)' -Status 'Created' -Detail 'Set to ExternalUserAndGuestSharing'
        } else {
            $results += New-ProvisioningResult -Resource 'External sharing (site)' -Status 'AlreadyCorrect' -Detail '[WhatIf] Would set ExternalUserAndGuestSharing'
        }
    }

    return $results
}

Export-ModuleMember -Function Invoke-SiteProvisioning, Invoke-ExternalSharingProvisioning
