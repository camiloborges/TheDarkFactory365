<#
.SYNOPSIS
    Stub functions for PnP.PowerShell and SPO Management Shell cmdlets.
    Used only in Pester tests — allows mocking without the real modules installed.
#>

function Get-PnPList                   { [CmdletBinding()] param([string]$Identity, $ErrorAction) }
function New-PnPList                   { [CmdletBinding()] param([string]$Title, $Template, $ErrorAction) }
function Add-PnPField                  { [CmdletBinding()] param([string]$List, [string]$DisplayName, [string]$InternalName, $Type, [switch]$Required, $Choices) }
function Set-PnPList                   { [CmdletBinding(SupportsShouldProcess)] param([string]$Identity, [switch]$BreakRoleInheritance, [bool]$CopyRoleAssignments) }
function Set-PnPListPermission         { [CmdletBinding()] param([string]$Identity, [string]$Group, [string]$AddRole) }
function Get-PnPListItem               { [CmdletBinding()] param([string]$List, $Query, $ErrorAction) }
function Add-PnPListItem               { [CmdletBinding()] param([string]$List, $Values) }
function Get-PnPSite                   { [CmdletBinding()] param([string]$Url, $ErrorAction) }
function New-PnPSite                   { [CmdletBinding()] param([string]$Type, [string]$Title, [string]$Alias, $ErrorAction) }
function Get-PnPTenant                 { [CmdletBinding()] param($ErrorAction) }
function Get-PnPTenantSite             { [CmdletBinding()] param([string]$Url, $ErrorAction) }
function Set-PnPTenant                 { [CmdletBinding()] param($SharingCapability, [bool]$EnableAzureADB2BIntegration) }
function Set-PnPTenantSite             { [CmdletBinding()] param([string]$Url, $Sharing) }
function Get-PnPTeamsTeam              { [CmdletBinding()] param() }
function New-PnPTeamsTeam              { [CmdletBinding()] param([string]$DisplayName, $Visibility, $ErrorAction) }
function Get-PnPTeamsChannel           { [CmdletBinding()] param($Team, $ErrorAction) }
function New-PnPTeamsChannel           { [CmdletBinding()] param($Team, [string]$DisplayName) }
function Get-PnPUser                   { [CmdletBinding()] param([string]$Identity, $ErrorAction) }
function Add-PnPUser                   { [CmdletBinding()] param([string]$LoginName, $Group) }
function Add-PnPGroupMember            { [CmdletBinding()] param([string]$LoginName, $Group) }
function Get-PnPTenantAppCatalogUrl    { [CmdletBinding()] param($ErrorAction) }
function Register-PnPAppCatalogSite    { [CmdletBinding()] param([string]$Url, $Owner, $TimeZoneId, $ErrorAction) }
function Connect-PnPOnline             { [CmdletBinding()] param([string]$Url, [switch]$Interactive, $ErrorAction) }
function Connect-SPOService            { [CmdletBinding()] param([string]$Url, $ErrorAction) }
function Add-PowerAppsAccount          { [CmdletBinding()] param($ErrorAction) }
function Get-SPOContentSecurityPolicy  { [CmdletBinding()] param($ErrorAction) }
function Add-SPOContentSecurityPolicy  { [CmdletBinding()] param([string]$Source, $ErrorAction) }
function Get-AdminPowerAppEnvironment  { [CmdletBinding()] param([switch]$Default, $ErrorAction) }

Export-ModuleMember -Function *
