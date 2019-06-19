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
    GitHub Source: https://github.com/aglasson/PSActiveNetworkSwitcher
    This script uses an Apache License 2.0 permitting commercial use, modification and distribution.
#>

#---- General Functions ----#

function Switch-PSActiveNetwork {
    [CmdletBinding()]
    Param(
        # If true will instead of selecting ethernet with lowest interface number allow multiple enabled.
        [Parameter(Mandatory = $false)]
        [switch]
        $AllowMultiEth
    )
    Write-Log "Running 'Switch-PSActiveNetwork'"
    # Simple logic: IF ethernet connected THEN switch off wireless ELSE switch on wireless.
    # IF multiple, select the ethernet with lowest interface number.

    $PerfMetricsStart = Get-Date

    # Get network devices and their states
    $PhysicalAdapterList = Get-NetAdapter -Physical | Where-Object { $_.PhysicalMediaType -ne "Unspecified" } | Select-Object Name, ifIndex, PhysicalMediaType, Status
    Write-Verbose "Output of {Get-NetAdapter -Physical} $($PhysicalAdapterList | Out-String)"

    $WirelessAdapterList = $PhysicalAdapterList | Where-Object { $_.PhysicalMediaType -in ("Native 802.11", "Wireless WAN") }

    $WirelessAdapterUpList = $WirelessAdapterList | Where-Object { $_.Status -eq "Up" }

    $EthernetAdapterList = $PhysicalAdapterList | Where-Object { $_.PhysicalMediaType -eq "802.3" }

    $EthernetAdapterUpList = $EthernetAdapterList | Where-Object { $_.Status -eq "Up" }
    Write-Verbose ("Ethernet Adapater in 'Up' status: " + ($EthernetAdapterUpList | Measure-Object).Count)

    if (($EthernetAdapterUpList | Measure-Object).Count -eq 1) {

        Write-Log "Single 'Up' Ethernet Adapter Detected."
        Write-Verbose "Wireless net adapters to be disabled: $($WirelessAdapterList | Out-String)"
        Write-Log "Disabling wireless net adapters."

        $WirelessAdapterList | ForEach-Object { Get-NetAdapter -ifIndex $_.ifIndex | Disable-NetAdapter -Confirm:$False }
    } elseif (((($EthernetAdapterUpList | Measure-Object).Count) -gt 1)) {
        Write-Log "More than one 'Up' Ethernet Adapter Detected."

        if ($AllowMultiEth) {
            Write-Log "-AllowMultiEth `$True so disabling all but Ethernet adapters."

            $WirelessAdapterList | ForEach-Object { Get-NetAdapter -ifIndex $_.ifIndex | Disable-NetAdapter -Confirm:$False }
        } else {
            Write-Log "-AllowMultiEth `$False so disabling all Wirless and 'Up' Ethernet except 'Up' Eth with lowest ifIndex number."

            $WirelessAdapterList | ForEach-Object { Get-NetAdapter -ifIndex $_.ifIndex | Disable-NetAdapter -Confirm:$False }
            $EthernetMultiLowest = ($EthernetAdapterUpList | Measure-Object -Minimum -Property ifIndex).Minimum
            Write-Verbose "'Up' Eth with lowest ifIndex number $($EthernetAdapterUpList | Where-Object {$_.ifIndex -ne $EthernetMultiLowest})"
            $EthernetAdapterUpList | Where-Object { $_.ifIndex -ne $EthernetMultiLowest } | ForEach-Object { Get-NetAdapter -ifIndex $_.ifIndex | Disable-NetAdapter -Confirm:$False }
        }
        Write-Log "Multiple up ethernet adapters identified and -AllowMultiEth `$True, enabling wireless net adapters."
    } elseif (((($EthernetAdapterUpList | Measure-Object).Count) -eq 0) -and (($WirelessAdapterUpList | Measure-Object).Count -gt 0)) {

        Write-Verbose "No 'up' ethernet adapters identified, at least one 'up' wireless adapter."

        if ((($WirelessAdapterUpList | Measure-Object).Count) -ge 2) {

            if ((($WirelessAdapterUpList | Where-Object { $_.PhysicalMediaType -eq "Native 802.11" } | Measure-Object).Count) -eq 1) {
                Write-Log "Only 1 'up' Wireless LAN adapters identified so disabling Wireless WAN adapters only."
                $WirelessAdapterUpList | Where-Object { $_.PhysicalMediaType -eq "Wireless WAN" } | ForEach-Object { Get-NetAdapter -ifIndex $_.ifIndex | Disable-NetAdapter -Confirm:$False }
            } else {
                Write-Log "More than 1 'up' Wireless LAN adapters identified so disabling Wireless WAN and Wireless LAN except with lowest ifIndex number."
                $WirelessLANMultiLowest = ($WirelessAdapterUpList | Where-Object { $_.PhysicalMediaType -eq "Native 802.11" } | Measure-Object -Minimum -Property ifIndex).Minimum
                $WirelessAdapterUpList | Where-Object { $_.ifIndex -ne $WirelessLANMultiLowest } | ForEach-Object { Get-NetAdapter -ifIndex $_.ifIndex | Disable-NetAdapter -Confirm:$False }
            }
        } else {
            Write-Log "Only one 'up' wireless adapter identified, no action required."
        }
    } else {
        Write-Log "Criteria not met, enabling all net adapters."

        Get-NetAdapter | Enable-NetAdapter -Confirm:$False
    }
    $TimeSpan = "{0:g}" -f (New-TimeSpan -Start $PerfMetricsStart -End (Get-Date))
    Write-Log "Switch network time to run: $TimeSpan"
}

#---- Deploy Functions ----#
function Install-PSActiveNetwork {
    [CmdletBinding()]
    param (
        # The path to the module files that will be copied to the task schedule runner location
        [Parameter( Mandatory = $false,
                    HelpMessage = "to the module files that will be copied to the task schedule runner location.")]
        [Alias("PSPath")]
        [ValidateScript( { Test-Path ((Get-ChildItem -Path $_) | Where-Object { $_.Name -eq "SidelineScripts" }).FullName })]
        [string]
        $Path,

        # The path to the module installation location
        [Parameter( Mandatory = $false,
                    HelpMessage = "Path to a location for the module to be installed to. By default `'C:\Program Files\WindowsPowerShell\Modules`'.")]
        [string]
        $Destination = "C:\Program Files\WindowsPowerShell\Modules\PSActiveNetworkSwitcher"
        # TODO:
        # ^ This is currently the only supported destination within the Task Scheduler config that gets imported.
    )

    $PerfMetricsStart = Get-Date

    if (!$Path -and ((Split-Path $PSCommandPath) -eq $Destination)) {
        Write-Log "INSTALL: No path specified but `$PSCommandPath matches `$Destination so skipping module install"
        $Path = $Destination
    }
    elseif ($Path) {
        Write-Log "INSTALL: Path specified, proceeding with copying module files to '$Destination'"

        if (!(Test-Path $Destination)) {
            Write-Log "INSTALL: Destination path does not exist, creating dirs: '$Destination'"
            New-Item -Path $Destination -ItemType Directory
        }
    
        Get-ChildItem -Path $Path -Exclude ".git" | Copy-Item -Destination $Destination -Recurse -Force -ErrorAction Stop
        Write-Log "INSTALL: Module contents copy from source to destination Success."
    }
    else {
        Write-Log "INSTALL: ERROR: No path specified and `$PSCommandPath does NOT match `$Destination so assuming failed intention of installing module."
        Throw "Path required when intending to install module as well."
    }

    # Create/replace scheduled task.
    $Command = "schtasks /create /xml `"$(Join-Path $Path 'SidelineScripts\PSActiveNetworkSwitcher Event Runner.xml')`" /tn `"PSActiveNetworkSwitcher Event Runner`" /ru SYSTEM /F"
    Write-Log "Running create scheduled task (overwrite if exists) `'$Command`'"

    $CmdRun = "cmd.exe /c $Command 2>&1"
    $Results = Invoke-Expression -Command $CmdRun

    if ($Results -like "SUCCESS*") {
        Write-Host $Results
        Write-Log "Create/replace scheduled task completed successfully."
    } else {
        $Results
    }

    # Check for excess counts of scheduled tasks.
    $RelatedSchedTasks = Get-ScheduledTask *networkswitcher*
    if (($RelatedSchedTasks | Measure-Object).Count -gt 1) {
        Write-Warning "Found more than one scheduled tasks matching '*networkswitcher*'."
        Write-Log "INSTALL: WARNING: Found more than one scheduled tasks matching '*networkswitcher*'." -NoVerbose
        Write-Verbose "These scheduled tasks from {Get-ScheduledTask *networkswitcher*} have been found: $($RelatedSchedTasks | Select-Object TaskName | Out-String)"
    }
    $TimeSpan = "{0:g}" -f (New-TimeSpan -Start $PerfMetricsStart -End (Get-Date))
    Write-Log "Install PSActiveNetworkSwitcher time to run: $TimeSpan"
}

#---- Logging/Output Functions ----#

Function Write-Log {
    Param (
        [Parameter(Mandatory = $True)]
        [string]$LogMessage,
        [switch]$NoVerbose
    )

    # Actual function to write append logfile entries
    # Files will be appended with date stamp - essentially rolling daily
    Function Write-LogEntry {
        Param (
            [string]$LogPath,
            [string]$LogFileBase,
            [string]$LogContent
        )

        # if either LogPath or LogFileBase come in empty determine values from current location and script name.
        if (!$LogPath) {
            # $LogPath = "$(Split-Path $PSCommandPath -Parent)\Logs\"
            $LogPath = "C:\Temp\PSActiveNetworkSwitcher_Logs\"
        }
        if (!$LogFileBase) {
            $LogFileBase = (Get-ChildItem $PSCommandPath).BaseName
        }

        $LogFilePath = (Join-Path -Path $LogPath -ChildPath ($LogFileBase + "_" + $(Get-Date -Format "yyyy-MM-dd") + ".log"))

        if (!$VerboseOnce) {
            $Global:VerboseOnce = $True
            Write-Verbose "LogPath determined as `'$LogPath`'"
            Write-Verbose "LogFileBase determined as `'$LogFileBase`'"
            Write-Verbose "LogFile determined as `'$LogFilePath`'"
        }

        # If required log path does not exist create it
        if (!(Test-Path $LogPath)) {
            Write-Verbose "Logging directory/s do no exists, creating path: '$LogPath'"
            New-Item $LogPath -ItemType Directory -Force | Out-Null
        }

        # Write line to logfile prepending the line with date and time
        Add-Content -Path $LogFilePath -Value "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss.ms"): $LogContent"
    }
    Write-LogEntry -LogPath $logPath -LogFileBase $logFileBase -LogContent $LogMessage
    if (!$NoVerbose) {
        Write-Verbose -Message $LogMessage   
    }
}