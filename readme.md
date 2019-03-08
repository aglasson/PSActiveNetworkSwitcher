# WinActiveNetworkSwitcher 

Powershell Module to automate the switching of network connection states automatically and look to have certain adapters disables when other adapters are connected.  
Can be used in automation or deployed to devices running Windows 8 or later. This module will not work Windows 7 or Earlier (regardless of PS version) due to Get-NetAdapter limitations.  
Facilitating cleaner network switching when roaming between Ethernet and WiFi, on and off corporate networks and to better control the security of endpoints on the network.  
It is intended for this script to be used in a scheduled task and triggered by network state change event log. Ideally it will also have some minor deployment functionality for self-provisioning  its scheduled task.

## Features
* Enable/disable wireless & other ethernet based on ethernet adapter state
* Allow or deny multiple ethernet adapter being enable/connected at once

## Intended Features
* Self deploy script runner and scheduled tasks to monitor event log for network changes and re-run the switcher
* Own organisation network identify - To facilitate for example, no VPNs or dual adapters allowed when in the office but VPNs allowed when working from home.
* Allow or deny VPN adapters