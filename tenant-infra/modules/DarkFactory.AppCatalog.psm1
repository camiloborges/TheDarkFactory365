<#
.SYNOPSIS
    SharePoint tenant App Catalog provisioning.
#>

$AppCatalogUrl   = 'https://aiwhisperer.sharepoint.com/sites/appcatalog'
$AppCatalogOwner = 'camilo.borges@aiwhisperer.onmicrosoft.com'
$AppCatalogTZ    = 17  # (UTC+12:00) Auckland, Wellington

function Invoke-AppCatalogProvisioning {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $existingUrl = Get-PnPTenantAppCatalogUrl -ErrorAction SilentlyContinue

    if ($existingUrl) {
        return New-ProvisioningResult -Resource 'App Catalog' -Status 'AlreadyExists' -Detail $existingUrl
    }

    if ($PSCmdlet.ShouldProcess($AppCatalogUrl, 'Register App Catalog site')) {
        Register-PnPAppCatalogSite -Url $AppCatalogUrl -Owner $AppCatalogOwner -TimeZoneId $AppCatalogTZ -ErrorAction Stop
        return New-ProvisioningResult -Resource 'App Catalog' -Status 'Created' -Detail "$AppCatalogUrl — ⚠ Wait 30 minutes before Spec 001 SPFx deployment"
    }

    return New-ProvisioningResult -Resource 'App Catalog' -Status 'AlreadyExists' -Detail "[WhatIf] Would register $AppCatalogUrl"
}

Export-ModuleMember -Function Invoke-AppCatalogProvisioning
