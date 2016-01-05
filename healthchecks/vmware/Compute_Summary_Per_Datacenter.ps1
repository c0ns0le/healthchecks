# This scripts provides some capacity information for an environment and it clusters
# Last updated: 31 March 2011
# Author: teiva.rodiere-at-gmail.com
#
param(	[object]$srvConnection,
		[string]$logDir="output",
		[string]$comment="",
		[bool]$showDate=$false,
		[bool]$returnReportOnly=$false,
		[bool]$showExtra=$true,
		[string]$configFile=".\customerEnvironmentSettings-ALL.ini"
	)
logThis -msg "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global




# Want to initialise the module and blurb using this 1 function



#Definitions for max vCPU/core and Mem reservations
$vCPUPerpCorePolicyLimit = 4; #max of 4vCPU per core
$mem = 100; # 100%

$run1Report = $srvConnection | %{
	$vCenter=$_
	
	logThis -msg "Processing [$vCenter]..." -ForegroundColor $global:colours.Information
	$compute = "" | Select "Environment"	
	if (logThis -msg)
	{
		$ifConfig=Import-Csv logThis -msg
		$currentConfig = $ifConfig | ?{$_.vCenterSrvName -eq $vCenter.Name}
		$compute.Environment = $currentConfig.MoreInfo
	} else {
		$compute.Environment = $vCenter.Name
	}
		
	
	logThis -msg "    --> VMs" -ForegroundColor $global:colours.Information 
	$vms = Get-VM -Server $vCenter ;
	# Get datastore usage information only for those VMs
	logThis -msg "    --> datastores" -ForegroundColor $global:colours.Information 
	$datastores = get-datastore -Server $vCenter
	logThis -msg "    --> ESX Servers" -ForegroundColor $global:colours.Information
	$vmhosts = Get-vmhost -Server $vCenter
	logThis -msg "    --> Clusters" -ForegroundColor $global:colours.Information
	$clusters = Get-Cluster -Server $vCenter | %{ 
		$row = "" | Select Name,MemoryGB,CpuGhz,NumCpuCores; 
		$row.Name=$_.Name; 
		$row.MemoryGB = [Math]::Round($_.ExtensionData.Summary.EffectiveMemory / 1024,2)
		$row.CpuGhz = [Math]::Round($_.ExtensionData.Summary.EffectiveCpu / 1024,2); 
		$row.NumCpuCores =$_.ExtensionData.Summary.NumCpuCores
		$row
	}
	
	
	$vmsCount=0
	if ($vms)
	{
		if ($vms.Count)
		{
			$vmsCount = $vms.Count
		} else {
			$vmsCount = 1
		}
	}
	$compute | Add-Member -Type NoteProperty -Name "Virtuals" -Value  $vmsCount;


	
	
	

	$datastoreFreeTB = 0
	$datastoreFreeTB = [math]::round($(($datastores | measure FreeSpaceMB -Sum).Sum/1024/1024),2)
	$datastoreCapacityTB = [math]::round($(($datastores | measure CapacityMB -Sum).Sum/1024/1024),2)
	$datastoreUsedTB = [math]::round($(($datastores | measure CapacityMB -Sum).Sum - ($datastores | measure FreeSpaceMB -Sum).Sum)/1024/1024,2)
	$datastoreUsedPercTB = [math]::round(($datastoreUsedTB / $datastoreCapacityTB * 100),2)
	$datastoreFreePercTB = [math]::round(($datastoreFreeTB / $datastoreCapacityTB * 100),2)
	
	$compute | Add-Member -Type NoteProperty -Name "Total Storage" -Value  "$datastoreCapacityTB TB";
	$compute | Add-Member -Type NoteProperty -Name "Disk Usage" -Value  "$datastoreUsedTB TB ($datastoreUsedPercTB%)";
	$compute | Add-Member -Type NoteProperty -Name "Disk Free" -Value  "$datastoreFreeTB TB ($datastoreFreePercTB%)";
			
	#$compute | Add-Member -Type NoteProperty -Name "Disk Usage (TB)" -Value  $datastoreUsedTB;
	#$compute | Add-Member -Type NoteProperty -Name "Storage Free (TB)" -Value  $datastoreFreeTB;
	
	$totalMemoryGB =  $($clusters | measure -Property MemoryGB -Sum).Sum
	$compute | Add-Member -Type NoteProperty -Name "Total Memory" -Value  "$totalMemoryGB GB";
	
	$ramusage=0; $ramOverCommit = 0;
	$ramDeployedGB = [math]::round($($vms | measure -Property "MemoryMB" -Sum).Sum/1024,2)
	$ramOverCommit = [Math]::Round($ramDeployedGB / $totalMemoryGB * 100,2)
	#$compute | Add-Member -Type NoteProperty -Name "RAM allocation" -Value  "$ramOverCommit %";
	$compute | Add-Member -Type NoteProperty -Name "Memory Allocated" -Value  "$ramDeployedGB GB ($ramOverCommit%)";
	
	
	if ($showExtra)
	{	
		#logThis -msg "   --> Getting list of root Resource Pools"
		#$rootPools = Get-ResourcePool -Server $vCenter -Location (get-datacenter -Server $vCenter) | ?{$_.Parent.gettype().Name-eq "ClusterWrapper"}
		
		
		
		
		$totalCpuGhz = $($clusters | measure -Property CpuGhz -Sum).Sum
		$compute | Add-Member -Type NoteProperty -Name "Total CPU" -Value  "$totalCpuGhz Ghz";
		
		$totalNumCores = $($clusters | measure -Property NumCpuCores -Sum).Sum
		$compute | Add-Member -Type NoteProperty -Name "Total NumCpuCores" -Value  "$totalNumCores";
		
		
		
		$allocVCPUs = $($vms | measure -Property "NumCpu" -Sum).Sum

		$vCPUusable = $totalNumCores * $vCPUPerpCorePolicyLimit - $allocVCPUs;

		$cpuOverCommit = $vCPUCount / $totalNumCores * 100;


		$compute | Add-Member -Type NoteProperty -Name "Physicals" -Value  "$($vmhosts.Count)"
		
		#$compute | Add-Member -Type NoteProperty -Name "Networks" -Value  $_.ExtensionData.Network.Count;
		#$compute | Add-Member -Type NoteProperty -Name "Datastores" -Value  $_.ExtensionData.Datastore.Count;
		#$compute | Add-Member -Type NoteProperty -Name "MaxCPUOverCommitThreshold%" -Value  "$(1 * $vCPUPerpCorePolicyLimit * 100)%";
		#$compute | Add-Member -Type NoteProperty -Name "CurrCPUAlloc%" -Value  "$([math]::round($cpuOverCommit))%";
		
		#$compute | Add-Member -Type NoteProperty -Name "CurrRAMAlloc" -Value  "$([math]::round($ramOverCommit))%";
		#$compute | Add-Member -Type NoteProperty -Name "CurrentFailoverLevel" -Value  $_.ExtensionData.Summary.CurrentFailoverLevel

		#$compute | Add-Member -Type NoteProperty -Name "TotalCpuGhz" -Value  "$([math]::round($($_.ExtensionData.Summary.TotalCpu / 1024)))"
		#$compute | Add-Member -Type NoteProperty -Name "TotalMemoryGB" -Value "$([math]::round($($_.ExtensionData.Summary.TotalMemory / 1GB)))"         
		#$compute | Add-Member -Type NoteProperty -Name "NumCpuCores" -Value $_.ExtensionData.Summary.NumCpuCores          
		#$compute | Add-Member -Type NoteProperty -Name "NumCpuThreads" -Value $_.ExtensionData.Summary.NumCpuThreads 
		#$compute | Add-Member -Type NoteProperty -Name "EffectiveCpuGhz" -Value  "$([math]::round($($_.ExtensionData.Summary.EffectiveCpu / 1024)))"
		#$compute | Add-Member -Type NoteProperty -Name "EffectiveMemoryGB" -Value  "$([math]::round($($_.ExtensionData.Summary.EffectiveMemory  / 1024)))"  
		#$compute | Add-Member -Type NoteProperty -Name "NumEffectiveHosts" -Value  $_.ExtensionData.Summary.NumEffectiveHosts 
		#$compute | Add-Member -Type NoteProperty -Name "OverallStatus" -Value  $_.ExtensionData.Summary.OverallStatus;


		# VM related stats
		#logThis -msg  $vCPUCount;
		#$compute | Add-Member -Type NoteProperty -Name "vCPUCount" -Value  "$vCPUCount";
		#$compute | Add-Member -Type NoteProperty -Name "vCPU_to_pCore%" -Value "$([math]::round($vCPUCount / $_.Summary.NumCpuCores,2))";

		$compute | Add-Member -Type NoteProperty -Name "vCPULeft" -Value  $vCPUusable;
		#$compute | Add-Member -Type NoteProperty -Name "RAMAllocGB" -Value  "$([math]::round($($ramusage  / 1024)))";
		#$compute | Add-Member -Type NoteProperty -Name "NumVmotions" -Value  $_.ExtensionData.Summary.NumVmotions
	}
	$compute
	logThis -msg $compute
}
# Fix the object array, ensure all objects within the 
# array contain the same members (required for Format-Table / Export-CSV)
 
#$Members = $run1Report | Select-Object `
  #@{n='MemberCount';e={ ($_ | Get-Member).Count }}, `
 # @{n='Members';e={ $_.PsObject.Properties | %{ $_.Name } }}
#$AllMembers = ($Members | Sort-Object MemberCount -Descending)[0].Members

#$Report = $run1Report | %{
  #ForEach ($Member in $AllMembers)
  #{
    #If (!($_ | Get-Member -Name $Member))
    #{ 
      #$_ | Add-Member -Type NoteProperty -Name $Member -Value ""
    #}
  #}
  #Write-Output $_
#}


if ($returnReportOnly)
{
	return $run1Report
} else {
	ExportCSV -table $run1Report 
	logThis -msg "Logs written to " $of -ForegroundColor  yellow;
}

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}