<#
.SYNOPSIS
    Guest user access provisioning for the DarkFactory SharePoint site.
#>

function Invoke-GuestAccessProvisioning {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]   $SiteUrl,
        [Parameter(Mandatory)][string[]] $GuestEmails,
        [Parameter(Mandatory)][string]   $VisitorsGroup
    )

    $results = @()

    foreach ($email in $GuestEmails) {
        if (-not $email) { continue }

        $user = Get-PnPUser -Identity $email -ErrorAction SilentlyContinue

        if (-not $user) {
            $results += New-ProvisioningResult -Resource "Guest: $email" -Status 'SkippedWithWarning' -Detail "Account not found in tenant — send B2B invitation first"
            continue
        }

        if ($PSCmdlet.ShouldProcess($email, "Add to $VisitorsGroup group")) {
            Add-PnPGroupMember -LoginName $email -Group $VisitorsGroup | Out-Null
            $results += New-ProvisioningResult -Resource "Guest: $email" -Status 'Created' -Detail "Added to $VisitorsGroup group"
        } else {
            $results += New-ProvisioningResult -Resource "Guest: $email" -Status 'AlreadyExists' -Detail "[WhatIf] Would add to $VisitorsGroup group"
        }
    }

    return $results
}

Export-ModuleMember -Function Invoke-GuestAccessProvisioning
