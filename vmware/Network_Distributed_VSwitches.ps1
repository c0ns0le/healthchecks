# Exports Distributed vSwitches configurations and essential information from vCenter for documentation purposes
#Version : 0.1
#Updated : 3th Feb 2015
#Author  : teiva.rodiere@gmail.com
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$showDate=$false)
logThis -msg "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global
$global:logfile
$global:outputCSV

# Want to initialise the module and blurb using this 1 function
InitialiseModule


$Report = Get-VDSwitch * -Server $srvConnection | %{
	$dvSwitch = $_
	
	# define an object to capture all the information needed
	$row = "" | select "Name"
	$row.Name = $dvSwitch.Name
	$row | Add-Member -Type NoteProperty -Name "Datacenter" -Value $dvSwitch.Datacenter
	$row | Add-Member -Type NoteProperty -Name "NumPorts" -Value $dvSwitch.NumPorts
	$row | Add-Member -Type NoteProperty -Name "Mtu" -Value $dvSwitch.Mtu
	$row | Add-Member -Type NoteProperty -Name "Version" -Value $dvSwitch.Version
	$row | Add-Member -Type NoteProperty -Name "Vendor" -Value $dvSwitch.Vendor
	$row | Add-Member -Type NoteProperty -Name "PortGroups" -Value $dvSwitch.ExtensionData.Portgroup.Count
	$row | Add-Member -Type NoteProperty -Name "Created" -Value $dvSwitch.ExtensionData.Config.CreateTime
	$row | Add-Member -Type NoteProperty -Name "LinkDiscoveryProtocol" -Value $dvSwitch.ExtensionData.Config.LinkDiscoveryProtocolConfig.Protocol
	$row | Add-Member -Type NoteProperty -Name "LinkDiscoveryProtocolSetting" -Value $dvSwitch.ExtensionData.Config.LinkDiscoveryProtocolConfig.Operation
	$row | Add-Member -Type NoteProperty -Name "AllowPromiscuous" -Value $dvSwitch.ExtensionData.Config.DefaultPortConfig.SecurityPolicy.AllowPromiscuous.Value
	$row | Add-Member -Type NoteProperty -Name "MacChanges" -Value $dvSwitch.ExtensionData.Config.DefaultPortConfig.SecurityPolicy.MacChanges.Value
	$row | Add-Member -Type NoteProperty -Name "ForgedTransmits" -Value $dvSwitch.ExtensionData.Config.DefaultPortConfig.SecurityPolicy.ForgedTransmits.value
	
	# output
	logThis -msg $row -ForegroundColor green
	$row
}

############### THIS IS WHERE THE STUFF HAPPENS
ExportCSV -table $Report 

logThis -msg "Logs written to " $of -ForegroundColor  yellow;
if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}