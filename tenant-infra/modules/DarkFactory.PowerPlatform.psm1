<#
.SYNOPSIS
    Reads the default Power Platform environment URL (read-only — Business Basic cannot create environments).
#>

function Get-PowerPlatformEnvironmentUrl {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    try {
        $env = Get-AdminPowerAppEnvironment -Default -ErrorAction Stop
        $instanceUrl = $env.Properties.LinkedEnvironmentMetadata.InstanceUrl

        if (-not $instanceUrl) {
            return New-ProvisioningResult -Resource 'Power Platform environment' -Status 'SkippedWithWarning' -Detail 'Default environment found but InstanceUrl was empty'
        }

        return New-ProvisioningResult -Resource 'Power Platform environment' -Status 'AlreadyExists' -Detail "Default environment: $instanceUrl"
    } catch {
        return New-ProvisioningResult -Resource 'Power Platform environment' -Status 'SkippedWithWarning' -Detail "Could not retrieve Power Platform environment: $_"
    }
}

Export-ModuleMember -Function Get-PowerPlatformEnvironmentUrl
