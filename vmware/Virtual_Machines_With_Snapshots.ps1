# Scripts scans virtual machines and outputs a list of VMs with Snapshot and exports it to a CSV
# Version : 1.0
# Updated : 23 March 2015
# Author  : teiva.rodiere@gmail.com
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$verbose=$true,[bool]$outToScreen=$false,[string]$appendOutputToFile="",[int]$headerType=1)
Write-Host "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global
$global:logfile
$global:outputCSV

# Want to initialise the module and blurb using this 1 function
InitialiseModule


$metaInfo = @()
$metaInfo +="tableHeader=Snapshots"
$metaInfo +="introduction=The table below lists Virtual Machines with snapshots. For performance reasons and reducing the risk to your virtual machines, we recommend that you delete snapshots in a timely manner (for examples after you have completed your application testing process). "
$metaInfo +="chartable=false"
$metaInfo +="titleHeaderType=h$($headerType)"

# do the job here#####################################
$vms = Get-VM * -Server $srvConnection
$index=1
$Report = $vms | %{
	$vm = $_
	logThis -msg "Processing $index\$($vms.Count) :- $($vm.Name)"
	$row = New-Object System.Object	
	$row = GetVMSnapshots -vm $_
	if($row)
	{
		logThis -msg $row
		$row
	}
	$index++
}

if ($returnReportOnly)
{ 
	return $Report
} else {
	#ExportCSV -table ($Report | sort -Property VMs -Descending) 
	ExportCSV -table $Report -sortBy "Count"
}

# Post Creation of Report
if ($metaAnalytics)
{
	$metaInfo += "analytics="+$metaAnalytics
}
ExportMetaData -meta $metaInfo

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}