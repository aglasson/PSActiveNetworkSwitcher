$dir = $PSScriptRoot
Set-Location $dir


Describe "Install-WinActiveNetwork Tests" {
    Import-Module (Join-Path $dir "WinActiveNetworkSwitcher.psm1")

    Context "Positive Success Tests" {
        Mock Invoke-Expression { return "SUCCESS: The scheduled task `"WinActiveNetworkSwitcher Event Runner`" has successfully been created." }
        Mock New-Item { return $Destination } -ParameterFilter { $Destination }
        Mock Copy-Item { return $InputObject.FullName } -ParameterFilter { $InputObject }

        It "SUCCESS Output" {
            Install-WinActiveNetwork -Path (Split-Path $dir) -Destination C:\Test\TestStore
        }
    }
}