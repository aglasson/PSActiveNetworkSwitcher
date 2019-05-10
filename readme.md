# WinActiveNetworkSwitcher 
https://github.com/aglasson/WinActiveNetworkSwitcher

Powershell Module to automate the switching of network connection states by having certain adapters disabled when other adapters are connected.  
Can be used in automation or deployed to devices running Windows 8 or later. This module will not work Windows 7 or Earlier (regardless of PS version) due to Get-NetAdapter limitations.  
Facilitating cleaner network switching when roaming between Ethernet and WiFi, on and off corporate networks.  

## Features
* Enable/disable wireless & other ethernet based on ethernet adapter state
* Allow or deny multiple ethernet adapter being enable/connected at once
* Self deploy script runner and scheduled tasks to monitor event log for network changes and re-run the switcher

## Installation
#### Manual Import Method
* Copy contents of Master Branch to a desired local directory or a Powershell Module Path directory (`$ENV:PSModulePath`)
* Import the module:
  ```powershell
  PS> Import-Module -Name C:\MyDesired\LocalDirectory\WinActiveNetworkSwitcher\Module\WinActiveNetworkSwitcher.psd1 # Unless placed in a PSModulePath directory.
  PS> Import-Module -Name WinActiveNetworkSwitcher # If already in PSModulePath. New Powershell session after copy.
  ```

## Example Usage
#### Install Scheduled Task
```powershell
PS> Install-WinActiveNetwork -Path 'C:\MyDesired\LocalDirectory\WinActiveNetworkSwitcher' # For now this will only copy to 'C:\Support\ScheduledTasks\WinActiveNetworkSwitcher\'
```
#### Running the Network Switcher
This *without arguments* is run by the scheduled task.
```
PS> Switch-WinActiveNetwork
```
##### Arguments
`-AllowMultiEth` If specified will allow Multiple Ethernet Adapters in 'Up' state at the same time. See Logic.

## Logic
Order of priority in which if one is in the 'Up' state the others can not be. When Ethernet connected, wireless is disabled due to wireless being a "connect when possible" medium. Ethernet not disabled when wireless connected so connecting a network cable will trigger the task and switch WiFi off.
1. Ethernet
2. Wireless LAN (WiFi)
3. Wireless WAN (Mobile Broadband/Cellular)

## Intended Features
#### Major Features
* Allow or deny VPN adapters
* Own organisation network identify - To facilitate for example, no VPNs or dual adapters allowed when in the office but VPNs allowed when working from home.
* Availability on the Powershell Gallery
* Mac OSX and Linux Support - **May not be possible and needs investigation**

#### Minor Features
* Support alternate destinations in 'Install-WinActiveNetwork' and replacement of path in task schedule XML file