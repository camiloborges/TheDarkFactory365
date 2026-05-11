<#
.SYNOPSIS
    SharePoint tenant App Catalog provisioning.
#>

function Invoke-AppCatalogProvisioning {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string] $AppCatalogUrl,
        [Parameter(Mandatory)][string] $Owner,
        [Parameter(Mandatory)][int]    $TimeZoneId
    )

    $existingUrl = Get-PnPTenantAppCatalogUrl -ErrorAction SilentlyContinue

    if ($existingUrl) {
        return New-ProvisioningResult -Resource 'App Catalog' -Status 'AlreadyExists' -Detail $existingUrl
    }

    if ($PSCmdlet.ShouldProcess($AppCatalogUrl, 'Register App Catalog site')) {
        Register-PnPAppCatalogSite -Url $AppCatalogUrl -Owner $Owner -TimeZoneId $TimeZoneId -ErrorAction Stop
        return New-ProvisioningResult -Resource 'App Catalog' -Status 'Created' -Detail "$AppCatalogUrl — ⚠ Wait 30 minutes before Spec 001 SPFx deployment"
    }

    return New-ProvisioningResult -Resource 'App Catalog' -Status 'AlreadyExists' -Detail "[WhatIf] Would register $AppCatalogUrl"
}

Export-ModuleMember -Function Invoke-AppCatalogProvisioning
