<#
.SYNOPSIS
    Guest user access provisioning for the DarkFactory SharePoint site.
#>

function Invoke-GuestAccessProvisioning {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]   $SiteUrl,
        [Parameter(Mandatory)][string[]] $GuestEmails
    )

    $results = @()

    foreach ($email in $GuestEmails) {
        if (-not $email) { continue }

        $user = Get-PnPUser -Identity $email -ErrorAction SilentlyContinue

        if (-not $user) {
            $results += New-ProvisioningResult -Resource "Guest: $email" -Status 'SkippedWithWarning' -Detail "Account not found in tenant — send B2B invitation first"
            continue
        }

        if ($PSCmdlet.ShouldProcess($email, 'Add to DarkFactory Visitors group')) {
            # Add-PnPGroupMember adds user to a named SharePoint group (correct for Visitor access)
            Add-PnPGroupMember -LoginName $email -Group 'DarkFactory Visitors' | Out-Null
            $results += New-ProvisioningResult -Resource "Guest: $email" -Status 'Created' -Detail 'Added to DarkFactory Visitors group'
        } else {
            $results += New-ProvisioningResult -Resource "Guest: $email" -Status 'AlreadyExists' -Detail '[WhatIf] Would add to DarkFactory Visitors group'
        }
    }

    return $results
}

Export-ModuleMember -Function Invoke-GuestAccessProvisioning
