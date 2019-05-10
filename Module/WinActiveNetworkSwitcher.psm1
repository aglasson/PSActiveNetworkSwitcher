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
Function Write-Log
{
    Param(
        [Parameter(Mandatory=$True,Position=0)]
        [string]$LogMessage
    )

    # Actual function to write append logfile entries
    # Files will be appended with datestamp - essentially rolling daily
    Function Write-LogEntry
    {
        Param(
            [string]$LogPath,
            [string]$LogFileBase,
            [string]$LogContent
        )
    
        # if either LogPath or LogFileBase come in empy determine values from current location and script name.
        if (!$LogPath)
        {
            $LogPath = "$(Split-Path $PSCommandPath -Parent)\Logs\"
        }
        if (!$LogFileBase)
        {
            $LogFileBase = $(Get-ChildItem $PSCommandPath).Name.Replace(".ps1","")
        }    
    
        # If required log path does not exist create it
        if(!(Test-Path $LogPath))
        {
            New-Item $LogPath -ItemType Directory -Force
        }
        
        # Write line to logfile prepending the line with date and time 
        Add-Content -Path "$LogPath$LogFileBase`_$(Get-Date -Format "yyyy-MM-dd").log" -Value "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss.ms"): $LogContent"
        
    }
    Write-LogEntry -LogPath $logPath -LogFileBase $logFileBase -LogContent $LogMessage
}

function Switch-WinActiveNetwork {
    [CmdletBinding()]
    Param(
        # If true will instead of selecting ethernet with lowest interface number allow multiple enabled.
        [Parameter(Mandatory=$false)]
        [switch]
        $AllowMultiEth
    )
    Write-Log -LogMessage "Running 'Switch-WinActiveNetwork'"
    # Simple logic: IF ethernet connected THEN switch off wireless ELSE switch on wireless.
    # IF multiple, select the ethernet with lowest interface number.

    # Get network devices and their states
    $PhysicalAdapterList = Get-NetAdapter -Physical | Select-Object Name, ifIndex, PhysicalMediaType, Status
    Write-Verbose "Output of {Get-NetAdapter -Physical} $($PhysicalAdapterList | Out-String)"

    $WirelessAdapterList = $PhysicalAdapterList | Where-Object {$_.PhysicalMediaType -in ("Native 802.11","Wireless WAN")}

    $WirelessAdapterUpList = $WirelessAdapterList | Where-Object {$_.Status -eq "Up"}
    
    $EthernetAdapterList = $PhysicalAdapterList | Where-Object {$_.PhysicalMediaType -eq "802.3"}
    
    $EthernetAdapterUpList = $EthernetAdapterList | Where-Object {$_.Status -eq "Up"}
    Write-Verbose ("Ethernet Adapater in 'Up' status: " + ($EthernetAdapterUpList | Measure-Object).Count)

    if (($EthernetAdapterUpList | Measure-Object).Count -eq 1) {
        
        Write-Verbose "Single 'Up' Ethernet Adapter Detected."
        Write-Verbose "Disabling wireless net adapters. $($WirelessAdapterList | Out-String)"
        Write-Log -LogMessage "Disabling wireless net adapters."

        $WirelessAdapterList | ForEach-Object {Get-NetAdapter -ifIndex $_.ifIndex | Disable-NetAdapter -Confirm:$False}
        }
    elseif (((($EthernetAdapterUpList | Measure-Object).Count) -gt 1) <# -and ($AllowMultiEth -eq $true) #>) {
        Write-Verbose "More than one 'Up' Ethernet Adapter Detected."

        if ($AllowMultiEth) {
            Write-Verbose "-AllowMultiEth `$True so disabling all but Ethernet adapters."

        $WirelessAdapterList | ForEach-Object {Get-NetAdapter -ifIndex $_.ifIndex | Disable-NetAdapter -Confirm:$False}
    }
        else {
            Write-Verbose "-AllowMultiEth `$False so disabling all Wirless and 'Up' Ethernet except 'Up' Eth with lowest ifIndex number."

            $WirelessAdapterList | ForEach-Object {Get-NetAdapter -ifIndex $_.ifIndex | Disable-NetAdapter -Confirm:$False}
            $EthernetMultiLowest = ($EthernetAdapterUpList | Measure-Object -Minimum -Property ifIndex).Minimum
            Write-Verbose "'Up' Eth with lowest ifIndex number $($EthernetAdapterUpList | Where-Object {$_.ifIndex -ne $EthernetMultiLowest})"
            $EthernetAdapterUpList | Where-Object {$_.ifIndex -ne $EthernetMultiLowest} | ForEach-Object {Get-NetAdapter -ifIndex $_.ifIndex | Disable-NetAdapter -Confirm:$False}
        }
        Write-Verbose "Multiple up ethernet adapters identified and -AllowMultiEth `$True, enabling wireless net adapters."
        Write-Log -LogMessage "Multiple up ethernet adapters identified and -AllowMultiEth `$True, enabling wireless net adapters."
    }
    elseif (((($EthernetAdapterUpList | Measure-Object).Count) -eq 0) -and (($WirelessAdapterList.Status -eq "Up" | Measure-Object).Count -gt 0)) {

        Write-Verbose "No 'up' ethernet adapters identified, at least one 'up' wireless adapter."

        if ((($WirelessAdapterUpList | Measure-Object).Count) -ge 2) {
            # Write-Verbose "At least 2 'up' wireless adapters identified so disabling all 'Up' Wirless except 'Up' Wireless LAN with lowest ifIndex number."

            if ((($WirelessAdapterUpList | Where-Object {$_.PhysicalMediaType -eq "Native 802.11"} | Measure-Object).Count) -eq 1) {
                Write-Verbose "Only 1 'up' Wireless LAN adapters identified so disabling Wireless WAN adapters only."
                $WirelessAdapterUpList | Where-Object {$_.PhysicalMediaType -eq "Wireless WAN"} | ForEach-Object {Get-NetAdapter -ifIndex $_.ifIndex | Disable-NetAdapter -Confirm:$False}
            }
            else {
                Write-Verbose "More than 1 'up' Wireless LAN adapters identified so disabling Wireless WAN and Wireless LAN except with lowest ifIndex number."
                $WirelessLANMultiLowest = ($WirelessAdapterUpList | Where-Object {$_.PhysicalMediaType -eq "Native 802.11"} | Measure-Object -Minimum -Property ifIndex).Minimum
                $WirelessAdapterUpList | Where-Object {$_.ifIndex -ne $WirelessLANMultiLowest} | ForEach-Object {Get-NetAdapter -ifIndex $_.ifIndex | Disable-NetAdapter -Confirm:$False}
            }
        }
        else {
            Write-Verbose "Only one 'up' wireless adapter identified, no action required."
            # exit
        }
    }
    else {
        Write-Verbose "Criteria not met, enabling all net adapters."
        Write-Log -LogMessage "Criteria not met, enabling all net adapters."

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