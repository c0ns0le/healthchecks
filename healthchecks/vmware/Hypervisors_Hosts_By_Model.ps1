# Groups Hypervisors by Server Hardware Model and spits out a small table with the quantity of servers in each.
# The results is used as an input into a Capacity Review Report
# Last updated: 23 March 2015
# Author: teiva.rodiere-at-gmail.com
param(
	[object]$srvConnection="",
	[string]$logDir="output",
	[string]$comment="",
	[bool]$showDate=$false,
	[int]$headerType=1,
	[bool]$returnResults=$true
)

$silencer = Import-Module -Name .\vmwareModules.psm1 -Force -PassThru -Verbose:$false
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global


# Want to initialise the module and blurb using this 1 function


# Report Meta Data
$metaInfo = @()
$metaInfo +="tableHeader=VMware Hypervisors by Hardware Model"
$metaInfo +="introduction=The table below groups Hypervisor Servers by the type of Hardware they are using. Although VMware supports heterogeneous clusters, we is recommended to have consistent hardware and software versions within common clusters."
$metaInfo +="titleHeaderType=h$($headerType)"
$metaInfo +="displayTableOrientation=Table" # options are List or Table
$metaInfo +="chartable=false"

$vmhosts = Get-VMhost -Server $srvconnection
$stats = $vmhosts | Group-Object -property Model | select-Object -property "Name","Count"
$dataTable = $stats | %{
	$row  = New-Object System.Object
	$row | Add-Member -MemberType NoteProperty -Name "System" -Value $_.Name
	$row | Add-Member -MemberType NoteProperty -Name "Count" -Value $_.Count
	logThis -msg $row
	$row
}

if ($dataTable)
{
	
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
if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}