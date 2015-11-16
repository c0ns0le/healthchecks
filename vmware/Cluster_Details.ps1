# Documents a cluster configuration
#Version : 0.7
#Updated : 13-Nov 2015
#Author  : teiva.rodiere@gmail.com
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[int]$headerType=1)
LogThis -msg"Importing Module vmwareModules.psm1 (force)"
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
$metaInfo +="tableHeader=VMware Clusters"
$metaInfo +="introduction=This section provides detailed configurations and capacity information for your VMware Clusters"
$metaInfo +="chartable=false"
$metaInfo +="titleHeaderType=h$($headerType)"
$metaInfo +="displayTableOrientation=List" # options are List or Table

LogThis -msg "Enumerating datacenters..."
$Report = $srvConnection | %{
	$vcenter=$_
	Get-Datacenter -Server $vcenter | %{
		$dc = $_
		LogThis -msg"Enumerating all Clusters in datacenter $dc..."
		Get-Cluster -Location $_.Name -Server $srvConnection | Get-View | %{ 
			$cluster=$_
			$clusterConfig = new-Object System.Object;
			LogThis -msg "Exporting cluster settings for $($cluster.Name) datacenter $dc..."
			$clusterConfig | Add-Member -Type NoteProperty -Name "Name" -Value $cluster.Name
			$clusterConfig | Add-Member -Type NoteProperty -Name "Hypervisors" -Value "$($cluster.Summary.NumHosts), $($cluster.Summary.NumEffectiveHosts) are effective";
			$clusterConfig | Add-Member -Type NoteProperty -Name "CPU" -Value "$($cluster.Summary.TotalCpu) Mhz, $($cluster.Summary.NumCpuCores) Cores, $($cluster.Summary.NumCpuThreads) Threads"
			$clusterConfig | Add-Member -Type NoteProperty -Name "Memory" -Value "$(getsize -unit 'B' -val $cluster.Summary.TotalMemory), $(getsize -unit 'MB' -val $cluster.Summary.EffectiveMemory) is effective "
			$clusterConfig | Add-Member -Type NoteProperty -Name "DRS" -Value $cluster.ConfigurationEx.DrsConfig.Enabled ;
			$clusterConfig | Add-Member -Type NoteProperty -Name "DRS Automation" -Value $cluster.ConfigurationEx.DrsConfig.DefaultVMBehavior ;
			$clusterConfig | Add-Member -Type NoteProperty -Name "DRS Automation Level" -Value $cluster.ConfigurationEx.DrsConfig.VmotionRate ;
			$clusterConfig | Add-Member -Type NoteProperty -Name "HA" -Value $cluster.ConfigurationEx.DasConfig.Enabled;
			$clusterConfig | Add-Member -Type NoteProperty -Name "HA Fail Over Capacity" -Value $cluster.ConfigurationEx.DasConfig.FailoverLevel;
			$clusterConfig | Add-Member -Type NoteProperty -Name "HA Admission Control" -Value $cluster.ConfigurationEx.DasConfig.AdmissionControlEnabled;
			$clusterConfig | Add-Member -Type NoteProperty -Name "HA Default Vm Settings Restart" -Value $cluster.ConfigurationEx.DasConfig.DefaultVmSettings.RestartPriority;
			$clusterConfig | Add-Member -Type NoteProperty -Name "HA Isolation Response" -Value $cluster.ConfigurationEx.DasConfig.DefaultVmSettings.IsolationResponse;
			#$clusterConfig | Add-Member -Type NoteProperty -Name "EVC Status" -Value "needs fixing";
			$clusterConfig | Add-Member -Type NoteProperty -Name "Data Power Management" -Value $cluster.ConfigurationEx.DpmConfigInfo.Enabled;
			
			$swap = $cluster.ConfigurationEx.VMSawpPlacement;
			if ($swap)
			{
					$clusterConfig | Add-Member -Type NoteProperty -Name "Swap File Location" -Value $cluster.ConfigurationEx.VMSawpPlacement;
			} else {
					$clusterConfig | Add-Member -Type NoteProperty -Name "Swap File Location" -Value "WithVM";
			}
			if ($clusterConfig.TotalServerCount)
			{
					$clusterConfig | Add-Member -Type NoteProperty -Name "Guest Mem Usage Limit" -Value "$([math]::ROUND(($clusterConfig.TotalServerCount - 1)/$clusterConfig.TotalServerCount * 100))";
			} else {
					$clusterConfig | Add-Member -Type NoteProperty -Name "Guest Mem Usage Limit" -Value "your choice";
			}
			
			$clusterConfig | Add-Member -Type NoteProperty -Name "Data center" -Value $dc.Name;
			if ($srvConnection.Count -gt 1)
			{
				$clusterConfig | Add-Member -Type NoteProperty -Name "vCenter" -Value $vcenter.Name;
			}
			$clusterConfig
		}
	} 
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