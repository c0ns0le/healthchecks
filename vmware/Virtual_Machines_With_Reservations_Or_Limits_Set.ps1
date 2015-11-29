# Lists all VMs compute settings, Resevations and limits
# Exports a list of VMs with Resource Reservations and Limits
#Version : 1.0
#Updated : 23 March 2015
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
$metaInfo +="tableHeader=Reservations and Limits"
$metaInfo +="introduction=The table below provides a list of Virtual Machines identified to have compute resource reservations and/or limits. Limts can have adverse effect on your VM operations and Reservations can impact your HA Cluster in a negative way."
$metaInfo +="chartable=false"
$metaInfo +="titleHeaderType=h$($headerType)"
$metaInfo +="displayTableOrientation=Table" # options are List or Table


logThis -msg "Enumerating VMs..."
$vms = Get-VM * -Server $srvConnection 
$index=1
$dataTable = $vms | %{
	logThis -msg "Processing $index\$($vms.Count) :- $($_.name)"
	$vm = $_
	if ( ($vm.ExtensionData.ResourceConfig.CpuAllocation.Reservation -gt 0) -or
	($vm.ExtensionData.ResourceConfig.CpuAllocation.Limit -gt 0) -or ($vm.ExtensionData.ResourceConfig.MemoryAllocation.Reservation -gt 0) -or 
	($vm.ExtensionData.ResourceConfig.MemoryAllocation.Limit -gt 0))
	{
		$row = New-Object System.Object 
		$row | Add-Member -Type NoteProperty -Name "Name" -Value $vm.Name
		$row | Add-Member -Type NoteProperty -Name "CPU" -Value $vm.NumCPU
		$row | Add-Member -Type NoteProperty -Name "CPU Reservation" -Value $vm.ExtensionData.ResourceConfig.CpuAllocation.Reservation ;
		$row | Add-Member -Type NoteProperty -Name "CPU Limits" -Value $vm.ExtensionData.ResourceConfig.CpuAllocation.Limit ;
		$row | Add-Member -Type NoteProperty -Name "Memory (MB)" -Value $vm.MemoryMB
		$row | Add-Member -Type NoteProperty -Name "Memory Reservation (MB)" -Value $vm.ExtensionData.ResourceConfig.MemoryAllocation.Reservation;
		$row | Add-Member -Type NoteProperty -Name "Memory Limit" -Value $vm.ExtensionData.ResourceConfig.MemoryAllocation.Limit;
		logThis -msg "`t-> Found something on this server" -ForegroundCOlor Green
		$row
	}
	$index++
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

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}