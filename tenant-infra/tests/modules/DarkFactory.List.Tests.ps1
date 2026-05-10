<#
.SYNOPSIS
    Pester 5 unit tests for DarkFactory.List.psm1
#>

BeforeAll {
    $StubsPath  = Join-Path $PSScriptRoot '..\Stubs\PnP.Stubs.psm1'
    $ReportPath = Join-Path $PSScriptRoot '..\..\modules\DarkFactory.Report.psm1'
    $ListPath   = Join-Path $PSScriptRoot '..\..\modules\DarkFactory.List.psm1'
    Import-Module $StubsPath  -Force
    Import-Module $ReportPath -Force
    Import-Module $ListPath   -Force
}

Describe 'Invoke-ListProvisioning' {
    Context 'When list does not exist' {
        BeforeEach {
            Mock Get-PnPList   -ModuleName DarkFactory.List { return $null }
            Mock New-PnPList   -ModuleName DarkFactory.List { return [PSCustomObject]@{ Title = 'DarkFactory-Settings' } }
            Mock Add-PnPField  -ModuleName DarkFactory.List { return $null }
        }

        It 'Calls New-PnPList when list is absent' {
            Invoke-ListProvisioning -SiteUrl 'https://t.com/sites/DF' -Confirm:$false
            Should -Invoke New-PnPList -ModuleName DarkFactory.List -Times 1 -Exactly
        }

        It 'Creates all 3 extra columns' {
            Invoke-ListProvisioning -SiteUrl 'https://t.com/sites/DF' -Confirm:$false
            Should -Invoke Add-PnPField -ModuleName DarkFactory.List -Times 3 -Exactly
        }

        It 'Returns Created status' {
            $r = Invoke-ListProvisioning -SiteUrl 'https://t.com/sites/DF' -Confirm:$false
            $r.Status | Should -Be 'Created'
        }
    }

    Context 'When list already exists' {
        BeforeEach {
            Mock Get-PnPList  -ModuleName DarkFactory.List { return [PSCustomObject]@{ Title = 'DarkFactory-Settings' } }
            Mock New-PnPList  -ModuleName DarkFactory.List { }
        }

        It 'Does NOT call New-PnPList' {
            Invoke-ListProvisioning -SiteUrl 'https://t.com/sites/DF' -Confirm:$false
            Should -Invoke New-PnPList -ModuleName DarkFactory.List -Times 0
        }

        It 'Returns AlreadyExists status' {
            $r = Invoke-ListProvisioning -SiteUrl 'https://t.com/sites/DF' -Confirm:$false
            $r.Status | Should -Be 'AlreadyExists'
        }
    }
}

Describe 'Invoke-ListPermissionsProvisioning' {
    Context 'When HasUniqueRoleAssignments is false (needs breaking)' {
        BeforeEach {
            Mock Get-PnPList -ModuleName DarkFactory.List {
                [PSCustomObject]@{
                    Title                    = 'DarkFactory-Settings'
                    HasUniqueRoleAssignments = $false
                }
            }
            Mock Set-PnPList            -ModuleName DarkFactory.List { }
            Mock Set-PnPListPermission  -ModuleName DarkFactory.List { }
        }

        It 'Calls Set-PnPList -BreakRoleInheritance' {
            Invoke-ListPermissionsProvisioning -SiteUrl 'https://t.com/sites/DF' -Confirm:$false
            Should -Invoke Set-PnPList -ModuleName DarkFactory.List -Times 1 -Exactly
        }

        It 'Sets permissions for Owners, Members, and Visitors' {
            Invoke-ListPermissionsProvisioning -SiteUrl 'https://t.com/sites/DF' -Confirm:$false
            Should -Invoke Set-PnPListPermission -ModuleName DarkFactory.List -Times 3 -Exactly
        }

        It 'Returns Created status' {
            $r = Invoke-ListPermissionsProvisioning -SiteUrl 'https://t.com/sites/DF' -Confirm:$false
            $r.Status | Should -Be 'Created'
        }
    }

    Context 'When HasUniqueRoleAssignments is true (idempotency guard)' {
        BeforeEach {
            Mock Get-PnPList -ModuleName DarkFactory.List {
                [PSCustomObject]@{
                    Title                    = 'DarkFactory-Settings'
                    HasUniqueRoleAssignments = $true
                }
            }
            Mock Set-PnPList            -ModuleName DarkFactory.List { }
            Mock Set-PnPListPermission  -ModuleName DarkFactory.List { }
        }

        It 'Does NOT call Set-PnPList (critical idempotency guard)' {
            Invoke-ListPermissionsProvisioning -SiteUrl 'https://t.com/sites/DF' -Confirm:$false
            Should -Invoke Set-PnPList -ModuleName DarkFactory.List -Times 0
        }

        It 'Returns AlreadyExists status' {
            $r = Invoke-ListPermissionsProvisioning -SiteUrl 'https://t.com/sites/DF' -Confirm:$false
            $r.Status | Should -Be 'AlreadyExists'
        }
    }
}

Describe 'Invoke-ConfigSeedProvisioning' {
    BeforeAll {
        $script:seedEntries = @(
            [PSCustomObject]@{ Key = 'Weather.Latitude'; Value = '-36.85'; Category = 'Weather'; Description = 'lat' }
            [PSCustomObject]@{ Key = 'Weather.City';     Value = 'Auckland'; Category = 'Weather'; Description = 'city' }
        )
    }

    Context 'When config key does not exist yet' {
        BeforeEach {
            Mock Get-PnPListItem -ModuleName DarkFactory.List { return $null }
            Mock Add-PnPListItem -ModuleName DarkFactory.List { return [PSCustomObject]@{ Id = 1 } }
        }

        It 'Calls Add-PnPListItem for each seed entry' {
            Invoke-ConfigSeedProvisioning -SiteUrl 'https://t.com/sites/DF' -SeedEntries $script:seedEntries -Confirm:$false
            Should -Invoke Add-PnPListItem -ModuleName DarkFactory.List -Times 2 -Exactly
        }

        It 'Returns Created for each new entry' {
            $results = Invoke-ConfigSeedProvisioning -SiteUrl 'https://t.com/sites/DF' -SeedEntries $script:seedEntries -Confirm:$false
            $results | ForEach-Object { $_.Status | Should -Be 'Created' }
        }
    }

    Context 'When config key already exists' {
        BeforeEach {
            Mock Get-PnPListItem -ModuleName DarkFactory.List { return [PSCustomObject]@{ FieldValues = @{ DFValue = 'existing' } } }
            Mock Add-PnPListItem -ModuleName DarkFactory.List { }
        }

        It 'Does NOT call Add-PnPListItem' {
            Invoke-ConfigSeedProvisioning -SiteUrl 'https://t.com/sites/DF' -SeedEntries $script:seedEntries -Confirm:$false
            Should -Invoke Add-PnPListItem -ModuleName DarkFactory.List -Times 0
        }

        It 'Returns AlreadyExists for each existing entry' {
            $results = Invoke-ConfigSeedProvisioning -SiteUrl 'https://t.com/sites/DF' -SeedEntries $script:seedEntries -Confirm:$false
            $results | ForEach-Object { $_.Status | Should -Be 'AlreadyExists' }
        }
    }

    It 'Returns one result per seed entry' {
        Mock Get-PnPListItem -ModuleName DarkFactory.List { return $null }
        Mock Add-PnPListItem -ModuleName DarkFactory.List { return [PSCustomObject]@{ Id = 1 } }
        $results = Invoke-ConfigSeedProvisioning -SiteUrl 'https://t.com/sites/DF' -SeedEntries $script:seedEntries -Confirm:$false
        $results.Count | Should -Be 2
    }
}
