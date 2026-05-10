<#
.SYNOPSIS
    ProvisioningResult factory and report writer for DarkFactory tenant provisioning.
#>

function New-ProvisioningResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Resource,
        [Parameter(Mandatory)][string] $Status,
        [string] $Detail = ''
    )
    [PSCustomObject]@{
        Resource = $Resource
        Status   = $Status
        Detail   = $Detail
    }
}

function Write-ProvisioningReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][PSCustomObject[]] $Results,
        [string] $TenantDomain    = 'aiwhisperer.onmicrosoft.com',
        [string] $AppCatalogUrl   = '',
        [string] $PowerPlatformUrl = ''
    )

    $runAt       = (Get-Date).ToUniversalTime()
    $timestamp   = $runAt.ToString('yyyy-MM-dd HH:mm:ss') + ' UTC'

    $createdCount  = ($Results | Where-Object { $_.Status -eq 'Created' }).Count
    $skippedCount  = ($Results | Where-Object { $_.Status -in @('AlreadyExists','AlreadyCorrect') }).Count
    $warningCount  = ($Results | Where-Object { $_.Status -eq 'SkippedWithWarning' }).Count
    $failedCount   = ($Results | Where-Object { $_.Status -eq 'Failed' }).Count

    $overallStatus = if ($failedCount -gt 0) { 'Failed' }
                     elseif ($warningCount -gt 0) { 'PartialSuccess' }
                     else { 'Success' }

    $divider = '=' * 55

    $lines = @()
    $lines += "DarkFactory Provisioning Report — $timestamp"
    $lines += "Tenant: $TenantDomain"
    $lines += $divider
    $lines += ''
    $lines += '{0,-32} {1,-20} {2}' -f 'Resource', 'Status', 'Detail'
    $lines += '{0,-32} {1,-20} {2}' -f ('-' * 32), ('-' * 20), ('-' * 42)

    foreach ($r in $Results) {
        $lines += '{0,-32} {1,-20} {2}' -f $r.Resource, $r.Status, $r.Detail
    }

    $lines += ''
    $lines += $divider
    $lines += "Summary: $createdCount Created | $skippedCount AlreadyExists/Correct | $warningCount SkippedWithWarning | $failedCount Failed"
    $lines += "Overall: $overallStatus"

    if ($AppCatalogUrl) {
        $lines += ''
        $lines += "App Catalog URL: $AppCatalogUrl"
    }
    if ($PowerPlatformUrl) {
        $lines += "Power Platform Default Environment: $PowerPlatformUrl"
    }

    $reportPath = Join-Path (Get-Location) 'darkfactory-provisioning-report.txt'
    $lines += "Report saved to: $reportPath"

    # Console output with colour
    foreach ($r in $Results) {
        $colour = switch ($r.Status) {
            'Created'             { 'Green' }
            'AlreadyExists'       { 'Gray' }
            'AlreadyCorrect'      { 'Gray' }
            'SkippedWithWarning'  { 'Yellow' }
            'Failed'              { 'Red' }
            default               { 'White' }
        }
        Write-Host ('{0,-32} {1,-20} {2}' -f $r.Resource, $r.Status, $r.Detail) -ForegroundColor $colour
    }

    Write-Host ''
    Write-Host $divider
    Write-Host "Summary: $createdCount Created | $skippedCount AlreadyExists/Correct | $warningCount SkippedWithWarning | $failedCount Failed"

    $overallColour = switch ($overallStatus) {
        'Success'       { 'Green' }
        'PartialSuccess'{ 'Yellow' }
        'Failed'        { 'Red' }
    }
    Write-Host "Overall: $overallStatus" -ForegroundColor $overallColour

    $lines | Out-File -FilePath $reportPath -Encoding UTF8

    $exitCode = switch ($overallStatus) {
        'Success'        { 0 }
        'PartialSuccess' { 1 }
        'Failed'         { 2 }
    }
    return $exitCode
}

Export-ModuleMember -Function New-ProvisioningResult, Write-ProvisioningReport
