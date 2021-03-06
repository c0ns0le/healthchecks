# Documents a cluster configuration
#Version : 0.7
#Updated : 13-Nov 2015
#Author  : teiva.rodiere-at-gmail.com
param(
	[object]$srvConnection="",
	[string]$logDir="output",
	[string]$comment="",
	[bool]$verbose=$false,
	[int]$headerType=1,
	[bool]$returnResults=$true
)
$silencer = Import-Module -Name .\vmwareModules.psm1 -Force -PassThru -Verbose:$false
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global


# Want to initialise the module and blurb using this 1 function


# Meta data needed by the porting engine to 
$metaInfo = @()
$metaInfo +="tableHeader=VMware Clusters"
$metaInfo +="introduction=This section provides detailed configurations and capacity information for your VMware Clusters"
$metaInfo +="chartable=false"
$metaInfo +="titleHeaderType=h$($headerType)"
$metaInfo +="displayTableOrientation=List" # options are List or Table

LogThis -msg "Enumerating datacenters..."
$allclusters = GetClusters -Server $srvConnection
$allvmhosts = getVmhosts -Server $srvConnection

$dataTable = $allclusters | %{
	$cluster=$_
	#$vmhosts = $allvmhosts | ?{$_.Cluster.Name -eq $cluster.Name } | Select NumCPU
	$clusterConfig = new-Object System.Object;
	LogThis -msg "Exporting cluster settings for $($cluster.Name) datacenter $($cluster.Datacenter.Name)..."
	$clusterConfig | Add-Member -Type NoteProperty -Name "Name" -Value $cluster.Name
	$clusterConfig | Add-Member -Type NoteProperty -Name "Hypervisors" -Value "Total of $($cluster.ExtensionData.Summary.NumHosts) ( $($cluster.ExtensionData.Summary.NumEffectiveHosts) effective )";
	$clusterConfig | Add-Member -Type NoteProperty -Name "CPU" -Value "$([math]::round(($cluster.ExtensionData.Summary.TotalCpu / 1024),2)) Ghz, $($cluster.ExtensionData.Summary.NumCpuCores) Cores, $($cluster.ExtensionData.Summary.NumCpuThreads) Threads"
	$clusterConfig | Add-Member -Type NoteProperty -Name "Memory" -Value "$(getsize -unit 'B' -val $($cluster.ExtensionData.Summary.TotalMemory)), $(getsize -unit 'MB' -val $($cluster.ExtensionData.Summary.EffectiveMemory)) is usable "
	$cluster.ExtensionData.Network.Count
	if ($cluster.ExtensionData.Configuration.DrsConfig.Enabled)
	{
		$drsEnabled="Enabled"
	} else {
		$drsEnabled="Disabled"
	}
	$clusterConfig | Add-Member -Type NoteProperty -Name "DRS" -Value "$drsEnabled ( $($cluster.ExtensionData.Configuration.DrsConfig.DefaultVMBehavior), level $($cluster.ExtensionData.Configuration.DrsConfig.VmotionRate))";
	if ($cluster.ExtensionData.Configuration.DasConfig.Enabled)
	{
		$haEnabled="Enabled"
	} else {
		$haEnabled="Disabled"
	}
	if ($cluster.ExtensionData.Configuration.DasConfig.AdmissionControlEnabled)
	{
		$haAdmissionControl = "Enabled"
	} else {
		$haAdmissionControl = "Disabled"
	}
	$haFailoverString = "Configured for $($cluster.ExtensionData.Configuration.DasConfig.FailoverLevel) host(s) failure, but the actual is $($cluster.ExtensionData.Summary.CurrentFailoverLevel) host(s)"
	$clusterConfig | Add-Member -Type NoteProperty -Name "HA" -Value "$haEnabled, $haFailoverString, VM restart priority is $($cluster.ExtensionData.Configuration.DasConfig.DefaultVmSettings.RestartPriority)"
	$clusterConfig | Add-Member -Type NoteProperty -Name "Enhanced VMotion" -Value "$($cluster.ExtensionData.Summary.CurrentEVCModeKey), $($cluster.ExtensionData.Summary.CurrentBalance)";
	#$clusterConfig | Add-Member -Type NoteProperty -Name "Data Power Management" -Value $cluster.ExtensionData.Configuration.DpmConfigInfo.Enabled;
			
			
	#$swap = $cluster.VMSwapfilePolicy;
	$clusterConfig | Add-Member -Type NoteProperty -Name "Swap File Location" -Value $cluster.VMSwapfilePolicy;
	if ($clusterConfig.TotalServerCount)
	{
			$clusterConfig | Add-Member -Type NoteProperty -Name "Guest Mem Usage Limit" -Value "$([math]::ROUND(($clusterConfig.TotalServerCount - 1)/$clusterConfig.TotalServerCount * 100))";
	} else {
			$clusterConfig | Add-Member -Type NoteProperty -Name "Guest Mem Usage Limit" -Value "your choice";
	}
			
	$clusterConfig | Add-Member -Type NoteProperty -Name "Data center" -Value $cluster.Datacenter.Name;
	if ($srvConnection.Count -gt 1)
	{
		$clusterConfig | Add-Member -Type NoteProperty -Name "vCenter" -Value $cluster.vCenter;
	}
	$clusterConfig
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