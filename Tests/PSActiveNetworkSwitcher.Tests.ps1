BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\PSActiveNetworkSwitcher.psm1'
    Import-Module $modulePath -Force

    InModuleScope PSActiveNetworkSwitcher {
        foreach ($commandName in 'Get-NetAdapter', 'Get-ScheduledTask') {
            if (-not (Get-Command $commandName -ErrorAction SilentlyContinue)) {
                Set-Item -Path "Function:\$commandName" -Value { }
            }
        }
    }
}

Describe 'Switch-PSActiveNetwork' {
    BeforeEach {
        Mock Write-PSActiveNetworkLog {} -ModuleName PSActiveNetworkSwitcher
        Mock Get-ItemProperty { [pscustomobject]@{ '(default)' = 0 } } -ModuleName PSActiveNetworkSwitcher
        Mock Get-NetAdapter { @() } -ModuleName PSActiveNetworkSwitcher
        Mock Disable-NetworkAdapterByIndex { param($InterfaceIndex) $script:DisabledAdapterIndexes += $InterfaceIndex } -ModuleName PSActiveNetworkSwitcher
        Mock Enable-AllNetworkAdapter { $script:EnabledAdapterCalls++ } -ModuleName PSActiveNetworkSwitcher
        $script:DisabledAdapterIndexes = @()
        $script:EnabledAdapterCalls = 0
    }

    It 'does not inspect or change adapters when airplane mode is enabled' {
        Mock Get-ItemProperty { [pscustomobject]@{ '(default)' = 1 } } -ModuleName PSActiveNetworkSwitcher

        Switch-PSActiveNetwork

        Should -Invoke Get-NetAdapter -Times 0 -Exactly -ModuleName PSActiveNetworkSwitcher
        $script:DisabledAdapterIndexes | Should -BeNullOrEmpty
        $script:EnabledAdapterCalls | Should -Be 0
    }

    It 'disables all wireless adapters when one ethernet adapter is up' {
        Mock Get-NetAdapter {
            param($Physical, $ifIndex)
            $null = $Physical
            $adapters = @(
                [pscustomobject]@{ Name = 'Ethernet'; ifIndex = 10; PhysicalMediaType = '802.3'; Status = 'Up' }
                [pscustomobject]@{ Name = 'Wi-Fi'; ifIndex = 20; PhysicalMediaType = 'Native 802.11'; Status = 'Up' }
                [pscustomobject]@{ Name = 'Cellular'; ifIndex = 30; PhysicalMediaType = 'Wireless WAN'; Status = 'Disabled' }
            )
            if ($ifIndex) { $adapters | Where-Object { $_.ifIndex -eq $ifIndex } } else { $adapters }
        } -ModuleName PSActiveNetworkSwitcher

        Switch-PSActiveNetwork

        $script:DisabledAdapterIndexes | Should -Contain 20
        $script:DisabledAdapterIndexes | Should -Contain 30
    }

    It 'keeps the lowest-index ethernet and disables wireless by default when multiple ethernet adapters are up' {
        Mock Get-NetAdapter {
            param($Physical, $ifIndex)
            $null = $Physical
            $adapters = @(
                [pscustomobject]@{ Name = 'Ethernet A'; ifIndex = 10; PhysicalMediaType = '802.3'; Status = 'Up' }
                [pscustomobject]@{ Name = 'Ethernet B'; ifIndex = 5; PhysicalMediaType = '802.3'; Status = 'Up' }
                [pscustomobject]@{ Name = 'Wi-Fi'; ifIndex = 20; PhysicalMediaType = 'Native 802.11'; Status = 'Up' }
            )
            if ($ifIndex) { $adapters | Where-Object { $_.ifIndex -eq $ifIndex } } else { $adapters }
        } -ModuleName PSActiveNetworkSwitcher

        Switch-PSActiveNetwork

        $script:DisabledAdapterIndexes | Should -Contain 10
        $script:DisabledAdapterIndexes | Should -Contain 20
    }

    It 'allows multiple ethernet adapters but still disables wireless when AllowMultiEth is set' {
        Mock Get-NetAdapter {
            param($Physical, $ifIndex)
            $null = $Physical
            $adapters = @(
                [pscustomobject]@{ Name = 'Ethernet A'; ifIndex = 10; PhysicalMediaType = '802.3'; Status = 'Up' }
                [pscustomobject]@{ Name = 'Ethernet B'; ifIndex = 5; PhysicalMediaType = '802.3'; Status = 'Up' }
                [pscustomobject]@{ Name = 'Wi-Fi'; ifIndex = 20; PhysicalMediaType = 'Native 802.11'; Status = 'Up' }
            )
            if ($ifIndex) { $adapters | Where-Object { $_.ifIndex -eq $ifIndex } } else { $adapters }
        } -ModuleName PSActiveNetworkSwitcher

        Switch-PSActiveNetwork -AllowMultiEth

        $script:DisabledAdapterIndexes | Should -Contain 20
    }

    It 'keeps the only active WLAN and disables other active wireless adapters when no ethernet is up' {
        Mock Get-NetAdapter {
            param($Physical, $ifIndex)
            $null = $Physical
            $adapters = @(
                [pscustomobject]@{ Name = 'Wi-Fi'; ifIndex = 20; PhysicalMediaType = 'Native 802.11'; Status = 'Up' }
                [pscustomobject]@{ Name = 'Cellular'; ifIndex = 30; PhysicalMediaType = 'Wireless WAN'; Status = 'Up' }
            )
            if ($ifIndex) { $adapters | Where-Object { $_.ifIndex -eq $ifIndex } } else { $adapters }
        } -ModuleName PSActiveNetworkSwitcher

        Switch-PSActiveNetwork

        $script:DisabledAdapterIndexes | Should -Contain 30
    }

    It 'keeps the lowest-index WLAN when multiple WLAN adapters are active' {
        Mock Get-NetAdapter {
            param($Physical, $ifIndex)
            $null = $Physical
            $adapters = @(
                [pscustomobject]@{ Name = 'Wi-Fi A'; ifIndex = 20; PhysicalMediaType = 'Native 802.11'; Status = 'Up' }
                [pscustomobject]@{ Name = 'Wi-Fi B'; ifIndex = 10; PhysicalMediaType = 'Native 802.11'; Status = 'Up' }
                [pscustomobject]@{ Name = 'Cellular'; ifIndex = 30; PhysicalMediaType = 'Wireless WAN'; Status = 'Up' }
            )
            if ($ifIndex) { $adapters | Where-Object { $_.ifIndex -eq $ifIndex } } else { $adapters }
        } -ModuleName PSActiveNetworkSwitcher

        Switch-PSActiveNetwork

        $script:DisabledAdapterIndexes | Should -Contain 20
        $script:DisabledAdapterIndexes | Should -Contain 30
    }

    It 'takes no action when one wireless adapter is already up' {
        Mock Get-NetAdapter {
            param($Physical, $ifIndex)
            $null = $Physical
            $adapters = @([pscustomobject]@{ Name = 'Wi-Fi'; ifIndex = 20; PhysicalMediaType = 'Native 802.11'; Status = 'Up' })
            if ($ifIndex) { $adapters | Where-Object { $_.ifIndex -eq $ifIndex } } else { $adapters }
        } -ModuleName PSActiveNetworkSwitcher

        Switch-PSActiveNetwork

        $script:DisabledAdapterIndexes | Should -BeNullOrEmpty
        $script:EnabledAdapterCalls | Should -Be 0
    }

    It 'enables all adapters when neither ethernet nor wireless is up' {
        Mock Get-NetAdapter {
            param($Physical, $ifIndex)
            $null = $Physical
            $adapters = @([pscustomobject]@{ Name = 'Ethernet'; ifIndex = 10; PhysicalMediaType = '802.3'; Status = 'Disconnected' })
            if ($ifIndex) { $adapters | Where-Object { $_.ifIndex -eq $ifIndex } } else { $adapters }
        } -ModuleName PSActiveNetworkSwitcher

        Switch-PSActiveNetwork

        $script:EnabledAdapterCalls | Should -Be 1
    }
}

Describe 'Install-PSActiveNetwork' {
    BeforeEach {
        Mock Write-PSActiveNetworkLog {} -ModuleName PSActiveNetworkSwitcher
        Mock Copy-Item {} -ModuleName PSActiveNetworkSwitcher
        Mock Invoke-Command { 'SUCCESS: The scheduled task was created.' } -ModuleName PSActiveNetworkSwitcher
        Mock Get-ScheduledTask { @() } -ModuleName PSActiveNetworkSwitcher
    }

    It 'rejects a source directory without SidelineScripts' {
        $invalidPath = Join-Path $TestDrive 'invalid'
        New-Item -Path $invalidPath -ItemType Directory -Force | Out-Null

        { Install-PSActiveNetwork -Path $invalidPath -Destination (Join-Path $TestDrive 'destination') } | Should -Throw
    }

    It 'copies module files and creates the scheduled task for a valid source directory' {
        $sourcePath = Join-Path $TestDrive 'source'
        $destinationPath = Join-Path $TestDrive 'destination'
        New-Item -Path (Join-Path $sourcePath 'SidelineScripts') -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $sourcePath 'SidelineScripts\PSActiveNetworkSwitcher Event Runner.xml') -Value '<Task />'

        Install-PSActiveNetwork -Path $sourcePath -Destination $destinationPath

        Should -Invoke Copy-Item -Times 1 -Exactly -ParameterFilter { $Destination -eq $destinationPath } -ModuleName PSActiveNetworkSwitcher
        Should -Invoke Invoke-Command -Times 1 -Exactly -ModuleName PSActiveNetworkSwitcher
        Should -Invoke Get-ScheduledTask -Times 1 -Exactly -ModuleName PSActiveNetworkSwitcher
    }
}

AfterAll {
    Remove-Module PSActiveNetworkSwitcher -Force -ErrorAction SilentlyContinue
    Remove-Variable DisabledAdapterIndexes, EnabledAdapterCalls -Scope Script -ErrorAction SilentlyContinue
}
