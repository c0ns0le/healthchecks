# List VMs needing VMware Tools attention and provides a table summary
#Version : 1.0
#Updated : 23 March 2015
#Author  : teiva.rodiere@gmail.com
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$showDate=$false,[bool]$launchReport=$false,[int]$headerType=1)
Write-host "Importing Module vmwareModules.psm1 (force)" -ForegroundColor Yellow
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global
$global:logfile
$global:outputCSV

# Want to initialise the module and blurb using this 1 function
InitialiseModule

# Meta data needed by the porting engine to 
$metaInfo = @()
$metaInfo +="tableHeader=Virtual Machines List without VMware Tools"
$metaInfo +="introduction=This report exports a list Virtual Machines with tools missing or out-of-date. It is recommended to run an up to date version of VMware Tools inside each Virtual Machine. Idealy this list should be empty."
$metaInfo +="chartable=false"
$metaInfo +="titleHeaderType=h$($headerType)"

# Get the needed data
logThis -msg "Collecting VMs..."
$vms =  Get-VM * -Server $srvConnection | ?{ ($_.ExtensionData.Guest.ToolsStatus -ne "toolsOk") -and ($_.ExtensionData.Guest.ToolsStatus -ne "") } 
$index=1
$Report = $vms | %{
	logThis -msg "Processing $index\$($vms.Count) :- $($_.Name)"
	$row  = New-Object System.Object
	$row | Add-Member -MemberType NoteProperty -Name "Name" -Value $_.Name
	$row | Add-Member -MemberType NoteProperty -Name "State" -Value $_.PowerState
	$row | Add-Member -MemberType NoteProperty -Name "Tool Version" -Value $_.ExtensionData.Config.Tools.ToolsVersion
	$row | Add-Member -MemberType NoteProperty -Name "Update Policy" -Value $_.ExtensionData.Config.Tools.ToolsUpgradePolicy
	#logThis -msg $row
	$row
	$index++
}

# Export Report to file (CSV)
ExportCSV -table $Report 

# Post Creation of Report
if ($metaAnalytics)
{
	$metaInfo += "analytics="+$metaAnalytics
}
ExportMetaData -meta $metaInfo

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}