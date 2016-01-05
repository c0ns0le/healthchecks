# Scripts scans virtual machines and outputs a list of VMs with Snapshot and exports it to a CSV
# Version : 1.0
# Updated : 23 March 2015
# Author  : teiva.rodiere-at-gmail.com
param(
	[object]$srvConnection="",
	[string]$logDir="output",
	[string]$comment="",
	[bool]$verbose=$false,
	[int]$headerType=1,
	[bool]$returnResults=$true,
	[bool]$showDate=$false
)
[bool]$global:logTofile = $false
[bool]$global:logInMemory = $true
[bool]$global:logToScreen = $true
$silencer = Import-Module -Name .\vmwareModules.psm1 -Force -PassThru -Verbose:$false
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global

$metaInfo = @()
$metaInfo +="tableHeader=Snapshots"
$metaInfo +="introduction=The table below lists Virtual Machines with snapshots. For performance reasons and reducing the risk to your virtual machines, we recommend that you delete snapshots in a timely manner (for examples after you have completed your application testing process). "
$metaInfo +="chartable=false"
$metaInfo +="titleHeaderType=h$($headerType)"

# do the job here#####################################
if ($srvConnection.count -gt 1)
{
	$dataTable = getSnapshots -Server $srvConnection | Select VM,Created,PowerState,Description,vCenter,Age
} else {
	$dataTable = getSnapshots -Server $srvConnection | Select VM,Created,PowerState,Description,Age
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