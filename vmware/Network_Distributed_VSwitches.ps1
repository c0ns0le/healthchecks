# Exports Distributed vSwitches configurations and essential information from vCenter for documentation purposes
#Version : 0.1
#Updated : 3th Feb 2015
#Author  : teiva.rodiere@gmail.com
param(
	[object]$srvConnection="",
	[string]$logDir="output",
	[string]$comment="",
	[bool]$verbose=$false,
	[int]$headerType=1,
	[bool]$returnResults=$true,
	[bool]$showDate=$false
)
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru -Verbose $false
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global
InitialiseModule

$metaInfo = @()
$metaInfo +="tableHeader=Distributed Networks"
$metaInfo +="introduction=The table below provides a comprehensive list of Distributed network switches."
$metaInfo +="chartable=false"
$metaInfo +="titleHeaderType=h$($headerType)"
$dataTable = Get-VirtualSwitch -Distributed * -Server $srvConnection | Select -First 1 | %{
	$vswitch = $_
	# define an object to capture all the information needed
	$row = "" | select "Name"
	$row.Name = $vswitch.Name
	$row | Add-Member -Type NoteProperty -Name "Datacenter" -Value $vswitch.Datacenter
	$row | Add-Member -Type NoteProperty -Name "NumPorts" -Value $vswitch.NumPorts
	$row | Add-Member -Type NoteProperty -Name "Mtu" -Value $vswitch.Mtu
	$row | Add-Member -Type NoteProperty -Name "Version" -Value $vswitch.Version
	$row | Add-Member -Type NoteProperty -Name "Vendor" -Value $vswitch.Vendor
	$row | Add-Member -Type NoteProperty -Name "PortGroups" -Value $vswitch.ExtensionData.Portgroup.Count
	$row | Add-Member -Type NoteProperty -Name "Created" -Value $vswitch.ExtensionData.Config.CreateTime
	$row | Add-Member -Type NoteProperty -Name "LinkDiscoveryProtocol" -Value $vswitch.ExtensionData.Config.LinkDiscoveryProtocolConfig.Protocol
	$row | Add-Member -Type NoteProperty -Name "LinkDiscoveryProtocolSetting" -Value $vswitch.ExtensionData.Config.LinkDiscoveryProtocolConfig.Operation
	$row | Add-Member -Type NoteProperty -Name "AllowPromiscuous" -Value $vswitch.ExtensionData.Config.DefaultPortConfig.SecurityPolicy.AllowPromiscuous.Value
	$row | Add-Member -Type NoteProperty -Name "MacChanges" -Value $vswitch.ExtensionData.Config.DefaultPortConfig.SecurityPolicy.MacChanges.Value
	$row | Add-Member -Type NoteProperty -Name "ForgedTransmits" -Value $vswitch.ExtensionData.Config.DefaultPortConfig.SecurityPolicy.ForgedTransmits.value
	
	# output
	logThis -msg $row -ForegroundColor green
	$row
}

if ($dataTable)
{
	#$dataTable $dataTable
	if ($metaAnalytics)
	{
		$metaInfo += "analytics="+$metaAnalytics
	}	
	if ($returnResults)
	{
		return $dataTable,$metaInfo,(getRuntimeLogFileContent)
	} else {
		ExportCSV -table $dataTable
		ExportMetaData -meta $metaInfo
	}
}

logThis -msg "Logs written to " $of -ForegroundColor  yellow;
if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}