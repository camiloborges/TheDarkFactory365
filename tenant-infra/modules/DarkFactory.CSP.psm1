<#
.SYNOPSIS
    SharePoint tenant Content Security Policy (CSP) allowlist management.

.NOTES
    SPO CSP management cmdlets vary by module version. This module attempts the newer
    Add-SPOSiteDesignScript approach first, then falls back to PnP, then provides
    manual-step guidance. The spec (FR-008a) marks this as a deployment prerequisite.

    If programmatic CSP management is not available in the installed module version,
    a SkippedWithWarning result is returned with manual configuration instructions.
#>

function Invoke-CSPProvisioning {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string] $Source
    )

    $results = @()

    # Try SPO Management Shell CSP cmdlets (newer versions only)
    $spoAvailable = $false
    try {
        $policies = Get-SPOContentSecurityPolicy -ErrorAction Stop
        $spoAvailable = $true

        # Exact string match — partial host match must NOT prevent adding
        $existing = $policies | Where-Object { $_ -eq $Source }

        if ($existing) {
            $results += New-ProvisioningResult -Resource "CSP — $Source" -Status 'AlreadyExists' -Detail 'Already in trusted sources'
        } else {
            if ($PSCmdlet.ShouldProcess($Source, 'Add to Content Security Policy trusted sources')) {
                Add-SPOContentSecurityPolicy -Source $Source -ErrorAction Stop
                $results += New-ProvisioningResult -Resource "CSP — $Source" -Status 'Created' -Detail 'Added to trusted sources'
            } else {
                $results += New-ProvisioningResult -Resource "CSP — $Source" -Status 'AlreadyExists' -Detail "[WhatIf] Would add $Source to CSP"
            }
        }
    } catch [System.Management.Automation.CommandNotFoundException] {
        # CSP cmdlets not available in this module version — document as manual step
        $spoAvailable = $false
        $results += New-ProvisioningResult -Resource "CSP — $Source" -Status 'SkippedWithWarning' `
            -Detail "SPO CSP cmdlets unavailable in installed module version. Manual step: SharePoint Admin Center → Settings → Content Security Policy → Add '$Source' to trusted sources"
    } catch {
        $results += New-ProvisioningResult -Resource "CSP — $Source" -Status 'Failed' -Detail "$_"
        return $results
    }

    # Check if enforcement is delayed/disabled — warn even if entry was added
    if ($spoAvailable) {
        try {
            $tenantConfig = Get-PnPTenant -ErrorAction SilentlyContinue
            if ($tenantConfig -and $tenantConfig.DelayContentSecurityPolicyEnforcement -eq $true) {
                $results += New-ProvisioningResult -Resource 'CSP enforcement' -Status 'SkippedWithWarning' `
                    -Detail 'CSP enforcement is delayed — allowlist entry added but may have no effect until enforcement is enabled'
            }
        } catch { }
    }

    return $results
}

Export-ModuleMember -Function Invoke-CSPProvisioning
