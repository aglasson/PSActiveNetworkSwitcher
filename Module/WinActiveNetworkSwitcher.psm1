    <#
.SYNOPSIS
    Module to automate the switching of network connection states by having certain adapters disabled when other adapters are connected.
.DESCRIPTION
    Can be used in automation or deployed to devices running Windows 8 or later. This module will not work Windows 7 or Earlier (regardless of PS version) due to Get-NetAdapter limitations.  
    Facilitating cleaner network switching when roaming between Ethernet and WiFi, on and off corporate networks and to better control the security of endpoints on the network.  
    It is intended for this script to be used in a scheduled task and triggered by network state change event log.
.EXAMPLE
    TODO:
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    None
.OUTPUTS
    None
.NOTES
    GitHub Source: https://github.com/aglasson/WinActiveNetworkSwitcher
    This script uses an Apache License 2.0 permitting commercial use, modification and distribution.
#>

#---- General Functions ----#
function Switch-WinActiveNetwork {
    [CmdletBinding()]
    Param(
        # If true will instead of selecting ethernet with lowest interface number allow multiple enabled.
        [Parameter(Mandatory=$false)]
        [switch]
        $AllowMultiEth
    )
    # Simple logic: IF ethernet connected THEN switch off wireless ELSE switch on wireless.
    # IF multiple, select the ethernet with lowest interface number.

    # Get network devices and their states
    $PhysicalAdapterList = Get-NetAdapter -Physical | Select-Object Name, ifIndex, MediaType, Status
    Write-Verbose "Output of {Get-NetAdapter -Physical} $($PhysicalAdapterList | Out-String)"

    $WirelessAdapterList = $PhysicalAdapterList | Where-Object {$_.MediaType -in ("Native 802.11","Wireless WAN")}

    $EthernetAdapterList = $PhysicalAdapterList | Where-Object {$_.MediaType -eq "802.3"}
    
    $EthernetAdapterUpList = $EthernetAdapterList | Where-Object {$_.Status -eq "Up"}
    Write-Verbose ("Ethernet Adapater in 'Up' status: " + ($EthernetAdapterUpList | Measure-Object).Count)

    if (($EthernetAdapterUpList | Measure-Object).Count -eq 1) {
        if (($EthernetAdapterList.Count -gt 1) -and ($AllowMultiEth -eq $true)) {
            Write-Verbose "-AllowMultiEth `$True, leaving other ethernet adapters enabled."
        }
        elseif (((($EthernetAdapterList | Measure-Object).Count) -gt 1) -and ($AllowMultiEth -eq $false)) {
            $DisableEthernetList = $EthernetAdapterList | Where-Object {$_ -notin $EthernetAdapterUpList}
            Write-Verbose "-AllowMultiEth `$False, disabling other ethernet adapters: $($DisableEthernetList | Out-String)"
            $DisableEthernetList | ForEach-Object {Get-NetAdapter -ifIndex $_.ifIndex | Disable-NetAdapter -Confirm:$False}
        }
        Write-Verbose "Disabling wireless net adapters. $($WirelessAdapterList | Out-String)"
        $WirelessAdapterList | ForEach-Object {Get-NetAdapter -ifIndex $_.ifIndex | Disable-NetAdapter -Confirm:$False}
    }
    elseif (((($EthernetAdapterUpList | Measure-Object).Count) -gt 1) -and ($AllowMultiEth -eq $true)) {
        Write-Verbose "Multiple up ethernet adapters identified and -AllowMultiEth `$True, enabling wireless net adapters."
    }
    elseif ((($EthernetAdapterUpList | Measure-Object).Count) -eq 0) {
        Write-Verbose "No up ethernet adapters identified, enabling wireless net adapters."
        $WirelessAdapterList | ForEach-Object {Get-NetAdapter -ifIndex $_.ifIndex | Enable-NetAdapter -Confirm:$False}
    }
    else {
        Write-Verbose "Criteria not met, enabling all net adapters."
        Get-NetAdapter | Enable-NetAdapter -Confirm:$False
    }
}

#---- Deploy Functions ----#
# TODO:
function Install-WinActiveNetwork {
    param (
        # The path to store the script and module that will be run by the scheduled task
        [Parameter( Mandatory=$true,
                    HelpMessage="Path to a single location for scheduled task to run script.")]
        [Alias("PSPath")]
        [string]
        $Path
    )
    
    <# TODO:
    - Deploy runner script and module to specified path
    - Create scheduled task
    #>
    
}