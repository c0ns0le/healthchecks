# Documents VMs with vSphere Replication configurations
#Version : 0.1
#Updated : 3th Feb 2015
#Author  : teiva.rodiere-at-gmail.com
param(
	[object]$srvConnection="",
	[string]$logDir="output",
	[string]$comment="",
	[bool]$verbose=$false,
	[int]$headerType=1,
	[bool]$returnResults=$true,
	[bool]$showDate=$false
)
$silencer = Import-Module -Name .\vmwareModules.psm1 -Force -PassThru -Verbose:$false
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global



$metaInfo = @()
$metaInfo +="tableHeader=VMs configured for Replication"
$metaInfo +="introduction=The table contains a list of Virtual Machines configured for vSphere Replication. Verify each setting to ensure they are compliant."
$metaInfo +="chartable=false"
$metaInfo +="titleHeaderType=h$($headerType)"
$metaInfo +="displayTableOrientation=Table" # options are List or Table

$dataTable = GetVMs -Server $srvConnection | %{
	$vm = $_
	logThis -msg "Checking VM $vm"
	$advanceSettings = $vm.ExtensionData.Config.ExtraConfig
	if ($($advanceSettings | ?{$_.Key -like "*hbr_filter*"}).Count -gt 0)
	{
		logThis -msg "`t-> VM Configured for vSphere Replication"
		$row = "" | Select-Object "Name"
		$row.Name = $vm.Name
		$row | Add-Member -Type NoteProperty -Name "RPO (minutes)" -Value  $($advanceSettings | ?{$_.Key -eq "hbr_filter.rpo"}).Value
		$row | Add-Member -Type NoteProperty -Name "ConfigGen" -Value  $($advanceSettings | ?{$_.Key -eq "hbr_filter.configGen"}).Value
		$row | Add-Member -Type NoteProperty -Name "Destination Server" -Value  $($advanceSettings | ?{$_.Key -eq "hbr_filter.destination"}).Value
		$row | Add-Member -Type NoteProperty -Name "Quiesce Memory" -Value  $($advanceSettings | ?{$_.Key -eq "hbr_filter.quiesce"}).Value
		$row | Add-Member -Type NoteProperty -Name "Disks Count Replicated" -Value  $($advanceSettings | ?{$_.Key -like "scsi*filters"}).Count
		$row | Add-Member -Type NoteProperty -Name "Status" -Value  $vm.ExtensionData.OverallStatus
		logThis -msg "`t-> $row"
		$row
	}
}

############### THIS IS WHERE THE STUFF HAPPENS

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
