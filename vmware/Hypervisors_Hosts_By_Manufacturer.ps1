# Groups Hypervisors by Server hardware Manufacturer type and spits out a small table with the quantity of servers in each.
# The results is used as an input into a Capacity Review Report
# Last updated: 23 March 2015
# Author: teiva.rodiere@gmail.com
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$showDate=$false,[int]$headerType=1)
Write-Host "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global
$global:logfile
$global:outputCSV

# Want to initialise the module and blurb using this 1 function
InitialiseModule


# Report Meta Data
$metaInfo = @()
$metaInfo +="tableHeader=VMware Hypervisors by Manufacturer"
$metaInfo +="introduction=The table below groups Hyperivsor by Server Hardware Types."
$metaInfo +="titleHeaderType=h$($headerType)"
$metaInfo +="displayTableOrientation=Table" # options are List or Table
$metaInfo +="chartable=false"

$vmhosts = Get-VMhost -Server $srvconnection
$stats = $vmhosts | Group-Object -property Manufacturer | select-Object -property "Name","Count"
$Report = $stats | %{
	$row  = New-Object System.Object
	$row | Add-Member -MemberType NoteProperty -Name "System Type" -Value $_.Name
	$row | Add-Member -MemberType NoteProperty -Name "Count" -Value $_.Count
	logThis -msg $row
	$row
}

ExportCSV -table  $Report 
if ($metaAnalytics)
{
	$metaInfo += "analytics="+$metaAnalytics
}
ExportMetaData -meta $metaInfo
if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}