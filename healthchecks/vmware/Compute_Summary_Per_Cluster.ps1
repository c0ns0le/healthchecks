# This scripts 
# Last updated: 15 Feb 2010
# Author: teiva.rodiere-at-gmail.com
#
param(	[object]$srvConnection="",
		[string]$logDir="output",
		[string]$comment="",
		[bool]$showDate=$false,
		[bool]$returnReportOnly=$false,
		[bool]$showExtra=$true,
		[string]$configFile=".\customerEnvironmentSettings-ALL.ini"
	)
Write-Host "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global




# Want to initialise the module and blurb using this 1 function


#Definitions for max vCPU/core and Mem reservations
$vCPUPerpCore = 4; #max of 4vCPU per core
$mem = 100; # 100%

logThis -msg "Enumerating datacenters..."
$run1Report = $srvconnection | %{
	$vCenter = $_
	Get-Datacenter -Server $_| %{
		$dc = $_.Name
		logThis -msg "Processing [$vCenter\$dc]..." -ForegroundColor Yellow
		Get-Cluster -Location $dc -Server $vCenter| Sort Name | % {
			$cluster = $_
			logThis -msg "    [$cluster]" -ForegroundColor Yellow
			$compute = "" | Select "Environment"
			if ($configFile)
			{
				$ifConfig=Import-Csv $configFile
				$currentConfig = $ifConfig | ?{$_.vCenterSrvName -eq $vCenter.Name}
				$compute.Environment = $currentConfig.MoreInfo
			} else {
				$compute.Environment = $vCenter.Name
			}

			
			#$compute.Datacenter = $dc;
			$compute | Add-Member -Type NoteProperty -Name "Datacenter" -Value $dc;
			#$clusterName = $cluster.Name;
			
			$compute | Add-Member -Type NoteProperty -Name "Cluster Name" -Value $($cluster.Name);
			
			logThis -msg "             --> VMs" -ForegroundColor Yellow
			$vms = Get-VM -Server $vCenter -Location $cluster ;
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
			$compute | Add-Member -Type NoteProperty -Name "VMs" -Value  $vmsCount;
			logThis -msg "             --> VMHosts " -ForegroundColor Yellow
			$esxhosts = Get-VMHost -Location $_.Name -Server $vCenter
			$esxCount = 0
			if ($esxhosts)
			{
				if ($esxhosts.Count)
				{
					$esxCount = $esxhosts.Count
				} else {
					$esxCount = 1
				}
			}
			$compute | Add-Member -Type NoteProperty -Name "Hosts" -Value  $esxCount
			
			
			# Get datastore usage information only for those VMs
			logThis -msg "             --> Datastores" -ForegroundColor Yellow
			$datastores = Get-datastore -Server $vCenter -VMhost $esxhosts
			$datastoreFreeTB = 0
			$datastoreFreeTB = [math]::round($(($datastores | measure FreeSpaceMB -Sum).Sum/1024/1024),2)
			$datastoreCapacityTB = [math]::round($(($datastores | measure CapacityMB -Sum).Sum/1024/1024),2)
			$datastoreUsedTB = [math]::round($(($datastores | measure CapacityMB -Sum).Sum - ($datastores | measure FreeSpaceMB -Sum).Sum)/1024/1024,2)
			$datastoreUsedPercTB = [math]::round(($datastoreUsedTB / $datastoreCapacityTB * 100),2)
			$datastoreFreePercTB = [math]::round(($datastoreFreeTB / $datastoreCapacityTB * 100),2)
			
			$compute | Add-Member -Type NoteProperty -Name "Disk Usage (TB)" -Value  "$datastoreUsedTB ($datastoreUsedPercTB%)";
			$compute | Add-Member -Type NoteProperty -Name "Storage Free (TB)" -Value  "$datastoreFreeTB ($datastoreFreePercTB%)";
			
			
			if ($showExtra)
			{
				$vCpuCount = 0
				foreach ($vm in $vms) {$vCpuCount += $vm.NumCpu};
				$compute | Add-Member -Type NoteProperty -Name "vCPUCount" -Value  $vCpuCount;
			
				$pCpuCount = 0
				foreach ($esxhost in $esxhosts) { $pCpuCount += $esxhost.ExtensionData.Hardware.CpuInfo.NumCpuCores }
				$compute | Add-Member -Type NoteProperty -Name "PhysicalCPUCore" -Value $pCpuCount
				
				$compute | Add-Member -Type NoteProperty -Name "vCPUperCoreRatio" -Value "$([math]::round($compute.vCPUCount / $compute.PhysicalCPUCore,2))"
				$vCPUusable = $compute.PhysicalCPUCore * $vCPUPerpCore - $compute.vCPUCount
				
				$compute | Add-Member -Type NoteProperty -Name "vCPUusable" -Value  $vCPUusable
			}
			$compute
		}
	}
}
# Fix the object array, ensure all objects within the 
# array contain the same members (required for Format-Table / Export-CSV)
 
$Members = $run1Report | Select-Object `
  @{n='MemberCount';e={ ($_ | Get-Member).Count }}, `
  @{n='Members';e={ $_.PsObject.Properties | %{ $_.Name } }}
$AllMembers = ($Members | Sort-Object MemberCount -Descending)[0].Members

$Report = $run1Report | %{
  ForEach ($Member in $AllMembers)
  {
    If (!($_ | Get-Member -Name $Member))
    { 
      $_ | Add-Member -Type NoteProperty -Name $Member -Value ""
    }
  }
  Write-Output $_
}
if ($returnReportOnly)
{ 
	return $Report
} else {
	ExportCSV -table $Report 
	logThis -msg "Logs written to " $of -ForegroundColor  yellow;
}

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}