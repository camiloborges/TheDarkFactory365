<#
.SYNOPSIS
    SharePoint list provisioning: DarkFactory-Settings schema, permissions, and seed data.
#>

function Invoke-ListProvisioning {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]   $SiteUrl,
        [Parameter(Mandatory)][string]   $ListName,
        [Parameter(Mandatory)][string[]] $Categories
    )

    $list = Get-PnPList -Identity $ListName -ErrorAction SilentlyContinue

    if ($list) {
        return New-ProvisioningResult -Resource "$ListName list" -Status 'AlreadyExists' -Detail $SiteUrl
    }

    if ($PSCmdlet.ShouldProcess($SiteUrl, "Create list $ListName")) {
        New-PnPList -Title $ListName -Template GenericList -ErrorAction Stop | Out-Null

        Add-PnPField -List $ListName -DisplayName 'DFValue'       -InternalName 'DFValue'       -Type Text     -Required | Out-Null
        Add-PnPField -List $ListName -DisplayName 'DFDescription' -InternalName 'DFDescription' -Type Note               | Out-Null
        Add-PnPField -List $ListName -DisplayName 'DFCategory'    -InternalName 'DFCategory'    -Type Choice   -Choices $Categories | Out-Null

        return New-ProvisioningResult -Resource "$ListName list" -Status 'Created' -Detail '4 columns added (Title, DFValue, DFDescription, DFCategory)'
    }

    return New-ProvisioningResult -Resource "$ListName list" -Status 'AlreadyExists' -Detail "[WhatIf] Would create $ListName on $SiteUrl"
}

function Invoke-ListPermissionsProvisioning {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string] $SiteUrl,
        [Parameter(Mandatory)][string] $ListName,
        [Parameter(Mandatory)][string] $OwnersGroup,
        [Parameter(Mandatory)][string] $MembersGroup,
        [Parameter(Mandatory)][string] $VisitorsGroup
    )

    $list = Get-PnPList -Identity $ListName -ErrorAction SilentlyContinue

    if (-not $list) {
        return New-ProvisioningResult -Resource "$ListName permissions" -Status 'Failed' -Detail "List $ListName not found — run Invoke-ListProvisioning first"
    }

    if ($list.HasUniqueRoleAssignments) {
        return New-ProvisioningResult -Resource "$ListName permissions" -Status 'AlreadyExists' -Detail 'Unique permissions already set'
    }

    if ($PSCmdlet.ShouldProcess($ListName, 'Break role inheritance and set permissions')) {
        Set-PnPList -Identity $ListName -BreakRoleInheritance -CopyRoleAssignments:$false | Out-Null
        Set-PnPListPermission -Identity $ListName -Group $OwnersGroup   -AddRole 'Full Control'
        Set-PnPListPermission -Identity $ListName -Group $MembersGroup  -AddRole 'Read'
        Set-PnPListPermission -Identity $ListName -Group $VisitorsGroup -AddRole 'Read'

        return New-ProvisioningResult -Resource "$ListName permissions" -Status 'Created' -Detail "Unique permissions set ($OwnersGroup=FC, $MembersGroup/$VisitorsGroup=Read)"
    }

    return New-ProvisioningResult -Resource "$ListName permissions" -Status 'AlreadyExists' -Detail '[WhatIf] Would break inheritance and set permissions'
}

function Invoke-ConfigSeedProvisioning {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]          $SiteUrl,
        [Parameter(Mandatory)][string]          $ListName,
        [Parameter(Mandatory)][PSCustomObject[]] $SeedEntries
    )

    $results = @()

    foreach ($entry in $SeedEntries) {
        $camlQuery = "<View><Query><Where><Eq><FieldRef Name='Title'/><Value Type='Text'>$($entry.Key)</Value></Eq></Where></Query></View>"
        $existing  = Get-PnPListItem -List $ListName -Query $camlQuery -ErrorAction SilentlyContinue

        if ($existing) {
            $results += New-ProvisioningResult -Resource "Seed: $($entry.Key)" -Status 'AlreadyExists' -Detail $existing.FieldValues.DFValue
            continue
        }

        if ($PSCmdlet.ShouldProcess($entry.Key, "Add config seed entry to $ListName")) {
            Add-PnPListItem -List $ListName -Values @{
                Title         = $entry.Key
                DFValue       = $entry.Value
                DFCategory    = $entry.Category
                DFDescription = $entry.Description
            } | Out-Null

            $results += New-ProvisioningResult -Resource "Seed: $($entry.Key)" -Status 'Created' -Detail $entry.Value
        } else {
            $results += New-ProvisioningResult -Resource "Seed: $($entry.Key)" -Status 'AlreadyExists' -Detail "[WhatIf] Would add $($entry.Key) = $($entry.Value)"
        }
    }

    return $results
}

Export-ModuleMember -Function Invoke-ListProvisioning, Invoke-ListPermissionsProvisioning, Invoke-ConfigSeedProvisioning
