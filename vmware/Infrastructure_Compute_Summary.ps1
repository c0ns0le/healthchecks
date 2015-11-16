# This scripts provides some capacity information for an environment and it clusters
# Last updated: 31 March 2011
# Author: teiva.rodiere@gmail.com
#
param([object]$srvConnection,[string]$logDir="output",[string]$comment="",[int]$headerType=1)
logThis -msg "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global
$global:logfile
$global:outputCSV

# Want to initialise the module and blurb using this 1 function
InitialiseModule

#Definitions for max vCPU/core and Mem reservations
$vCPUPerpCorePolicyLimit = 4; #max of 4vCPU per core
$mem = 100; # 100%

logThis -msg "Enumerating datacenters..."

$run1Report = Get-Datacenter -Server $srvConnection | %{
	$dc = $_.Name
	logThis -msg "Enumerating clusters in datacenter $dc..." -ForegroundColor Yellow 
	Get-Cluster -Location $dc -Server $srvConnection | Get-View | Sort Name | %{
		$compute = "" | Select "Datacenters"
		$compute.Datacenters = $dc;
		$clusterName = $_.Name;
		logThis -msg "Processing cluster $clusterName in datacenters $dc..." -ForegroundColor Cyan
		$compute | Add-Member -Type NoteProperty -Name "Clusters" -Value $clusterName;		
		$vms = Get-VM -Location $_.Name | Get-View;

		$ramusage=0; $ramOverCommit = 0;
		$vms | %{$ramusage=$ramusage + $_.Config.Hardware.MemoryMB}; 
		$ramOverCommit = $ramusage / $_.Summary.EffectiveMemory * 100

		$vCPUCount=0; $cpuOverCommit = 0 ;  $vCPUusable = 0
		$vms | %{ $vCPUCount = $vCPUCount + $_.Config.Hardware.NumCPU };

		$vCPUusable = $_.Summary.NumCpuCores * $vCPUPerpCorePolicyLimit - $vCPUCount;

		$cpuOverCommit = $vCPUCount / $_.Summary.NumCpuCores * 100;

		$compute | Add-Member -Type NoteProperty -Name "Physicals" -Value  $_.Summary.NumHosts             
		$compute | Add-Member -Type NoteProperty -Name "Virtuals" -Value  $vms.Count;
		$compute | Add-Member -Type NoteProperty -Name "Networks" -Value  $_.Network.Count;
		$compute | Add-Member -Type NoteProperty -Name "Datastores" -Value  $_.Datastore.Count;
		$compute | Add-Member -Type NoteProperty -Name "MaxCPUOverCommitThreshold%" -Value  "$(1 * $vCPUPerpCorePolicyLimit * 100)%";
		$compute | Add-Member -Type NoteProperty -Name "CurrCPUAlloc%" -Value  "$([math]::round($cpuOverCommit))%";
		$compute | Add-Member -Type NoteProperty -Name "MaxRAMOverCommitThreshold%" -Value  "-";
		$compute | Add-Member -Type NoteProperty -Name "CurrRAMAlloc" -Value  "$([math]::round($ramOverCommit))%";
		$compute | Add-Member -Type NoteProperty -Name "CurrentFailoverLevel" -Value  $_.Summary.CurrentFailoverLevel

		$compute | Add-Member -Type NoteProperty -Name "TotalCpuGhz" -Value  "$([math]::round($($_.Summary.TotalCpu / 1024)))"
		$compute | Add-Member -Type NoteProperty -Name "TotalMemoryGB" -Value "$([math]::round($($_.Summary.TotalMemory / 1GB)))"         
		$compute | Add-Member -Type NoteProperty -Name "NumCpuCores" -Value $_.Summary.NumCpuCores          
		$compute | Add-Member -Type NoteProperty -Name "NumCpuThreads" -Value $_.Summary.NumCpuThreads 
		$compute | Add-Member -Type NoteProperty -Name "EffectiveCpuGhz" -Value  "$([math]::round($($_.Summary.EffectiveCpu / 1024)))"
		$compute | Add-Member -Type NoteProperty -Name "EffectiveMemoryGB" -Value  "$([math]::round($($_.Summary.EffectiveMemory  / 1024)))"  
		$compute | Add-Member -Type NoteProperty -Name "NumEffectiveHosts" -Value  $_.Summary.NumEffectiveHosts 
		$compute | Add-Member -Type NoteProperty -Name "OverallStatus" -Value  $_.Summary.OverallStatus;


		# VM related stats
		#logThis -msg  $vCPUCount;
		$compute | Add-Member -Type NoteProperty -Name "vCPUCount" -Value  "$vCPUCount";
		$compute | Add-Member -Type NoteProperty -Name "vCPU_to_pCore%" -Value "$([math]::round($vCPUCount / $_.Summary.NumCpuCores,2))";

		$compute | Add-Member -Type NoteProperty -Name "vCPULeft" -Value  $vCPUusable;
		$compute | Add-Member -Type NoteProperty -Name "RAMAllocGB" -Value  "$([math]::round($($ramusage  / 1024)))";
		$compute | Add-Member -Type NoteProperty -Name "NumVmotions" -Value  $_.Summary.NumVmotions

		$compute
		logThis -msg $compute 
	}
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

ExportCSV -table $run1Report
AppendToCSVFile -msg ""
AppendToCSVFile -msg ""
#Write-Output "Collected on $(get-date)" >> $of

logThis -msg "Logs written to " $of -ForegroundColor  yellow;

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}