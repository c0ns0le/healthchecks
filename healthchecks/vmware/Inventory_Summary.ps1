# This scripts provides some capacity information for an environment 
# The results is used as an input into a Capacity Review Report
# Last updated: 8 March 2012
# Author: teiva.rodiere@gmail.com
#
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$showDate=$false,[string]$clusterName)
Write-Host "Executing script $($MyInvocation.MyCommand.path)" -ForegroundColor  green;
Write-Host "Current path is $($pwd.path)" -ForegroundColor  yellow;

$disconnectOnExist = $true;

if (!$srvConnection)
{ 
	$vcenterName = Read-Host "Enter virtual center server name"
	Write-Host "Connecting to virtual center server $vcenterName.."
	$srvConnection = Connect-VIServer -Server $vcenterName
	$disconnectOnExist = $true;	
} else {
	$disconnectOnExist = $false;
	$vcenterName = $srvConnection.Name;
}

if ((Test-Path -path $logDir) -ne $true) {
	New-Item -type directory -Path $logDir
}

$runtime="$(date -f dd-MM-yyyy)"
$filename = ($($MyInvocation.MyCommand.Name)).TrimEnd('.ps1');
Write-Host "$filename";
if ($comment -eq "" ) {
	$of = $logDir + "\"+$runtime+"_"+$vcenterName.ToUpper()+"_"+$filename+".csv"
} else {
	$of = $logDir + "\"+$runtime+"_"+$vcenterName.ToUpper()+"_"+$filename+"-"+$comment+".csv"
}

Write-Host "This script log to " $of -ForegroundColor Yellow 

#Definitions for max vCPU/core and Mem reservations
$vCPUPerpCorePolicyLimit = 4; #max of 4vCPU per core
$mem = 100; # 100%

function getTableResults([Object]$clusters="",[Object]$vms="",[Object]$vmhosts="",[Object]$datastores="",[Object]$vcenter="")
{
	Write-Host "Processing $clusters"
	$vCPUPerpCorePolicyLimit = 4; #max of 4vCPU per core
	$mem = 100; # 100%
	$clustersCount = 0
	$vmhostsCount = 0
	$datastoresCount = 0
	$datastoresClustersCount = 0
	$sharedStorageCapacityTB = 0
	$sharedStorageFreeTB = 0
	$sharedDatastoresCount = 0
	$cpuGhz = 0
	$ramGB = 0
	$networksCount = 0
	$networkNotSharedCount = 0
	$dvNetworksCount = 0
	$dvNetworksNotSharedCount = 0
	$table = @{}
   # Write-Host "Processing $($_.Name)" -Foregroundcolor Green
	#Write-Host "Getting Clusters" -ForegroundColor Yellow
    #$clusters = Get-Cluster * -Server $_
    if ($clusters) {
        if ($clusters.Count) {
            $clustersCount += $clusters.Count
        } else {
            $clustersCount = 1
        }
    }
    #Write-Host "Getting Hosts" -ForegroundColor Yellow
    #$vmhosts =  $clusters | get-VMhost -Server $_
    if ($vmhosts)
	{
		if ($vmhosts.Count)
		{
			$vmhostsCount += $vmhosts.Count
		} else {
			$vmhostsCount = 1
		}
	}

    #Write-Host "Getting Virtual Machines" -ForegroundColor Yellow
    #$vms = get-vm -Server $_
	$vmsOtherCount=0
	$vmsOffCount=0
	$vmsOnCount=0
    if ($vms)
	{
		if ($vms.Count) {
			$vmsCount = $vms.Count
			
			Write-Host "Powered ON " -ForegroundColor Yellow
    		$vmsOnCount = $($vms | ?{$_.PowerState -eq "PoweredOn"}).Count
    		Write-Host "Powered OFF " -ForegroundColor Yellow
    		$vmsOffCount = $($vms | ?{$_.PowerState -eq "PoweredOff"}).Count
	    	Write-Host "Powered OTHER " -ForegroundColor Yellow
    		$vmsOtherCount = $($vms | ?{$_.PowerState -ne "PoweredOn" -and $_.PowerState -ne "PoweredOff"}).Count
		} else {
			$vmsCount = 1
			if ($vms.PowerState -eq "PoweredOn") {$vmsOnCount = 1}
			if ($vms.PowerState -eq "PoweredOff") {$vmsOffCount = 1}
			if ($vms.PowerState -ne "PoweredOn" -and $vms.PowerState -ne "PoweredOff") {$vmsOtherCount = 1}	
		}
	}
    #Write-Host "Getting Datastores" -ForegroundColor Yellow
    #$datastores = Get-Datastore -Server $_
	
	$datastoresClusters = $vms | get-datastorecluster
	if ($datastoresClusters)
	{
		if ($datastoresClusters.Count)
		{
			$datastoresClustersCount = $datastoresClusters.Count
		} else {
			$datastoresClustersCount = 1
		}
	}
	
	$datastoresCount = 0;
    if ($datastores) {
		if ($datastores.Count)
		{
			$datastoresCount += $datastores.Count
		} else {
			$datastoresCount = 1
		}
    }
    $sharedDatastores = $datastores | ?{$_.ExtensionData.Host.Count -eq $vmhosts.Count}
    $sharedDatastoresCount = $sharedDatastores.Count
    
    $sharedStorageCapacityMB = $($datastores | measure CapacityMB -sum).Sum
    $datastoresCapacityTB = [math]::ROUND($sharedStorageCapacityMB / 1024 / 1024 , 2)

    $sharedStorageFreeMB = $($datastores | measure FreeSpaceMB -sum).Sum
    $sharedStorageFreeTB = [math]::ROUND($sharedStorageFreeMB / 1024 / 1024 , 2)

    Write-Host "Getting CPU" -ForegroundColor Yellow
    $cpuMhz = $($vmhosts | Measure-Object -property "CpuTotalMhz" -sum).Sum
    $cpuGhz += [math]::ROUND($cpuMhz / 1024,2)

    Write-Host "Getting RAM" -ForegroundColor Yellow
    $ramMB = $($vmhosts | measure -property "MemoryTotalMB" -sum).Sum
    $ramGB += [math]::ROUND($ramMB / 1024,2)
    
    Write-Host "Getting Networks" -ForegroundColor Yellow
    $portGroups = $vmhosts | Get-VirtualPortGroup
    $uniquePG = $portGroups | sort -property Name | select -unique
    $networksCount = $uniquePG.Count
    $uniquePG | %{
        $pgName = $_.Name; 
        $pgMatched = $portGroups | ?{$_.Name -eq $pg}; 
        # If the number of port group is less than the number of hosts in the cluster, then this network is not shared
        if ($pgMatched.Count -lt $vmhosts.Count)
        {
            $networkNotSharedCount += 1
        } 
    }	
	$table.Add("Clusters","$($clusters)")
	$table.Add("Clusters Count",$clustersCount)
	$table.Add("Hosts",$vmhostsCount)
	$table.Add("Virtual Machines",$vmsCount)
	$table.Add("Virtual Machines - On",$vmsOnCount)
	$table.Add("Virtual Machines - Off",$vmsOffCount)
	$table.Add("Virtual Machines - Other","$($vmsCount - $vmsOnCount - $vmsOffCount)")
	$table.Add("Datastores", $datastoresCount)
	$table.Add("Datastores Cluster(s)", $datastoresClustersCount)
	#$table.Add("Datastores (Shared)",$sharedDatastoresCount)
	$table.Add("Datastore Capacity (TB)", $datastoresCapacityTB)
	$table.Add("Datastore Freespace (TB)", $sharedStorageFreeTB)
	$table.Add("Total CPU Ghz",$cpuGhz)
	$table.Add("Total Memory GB",$ramGB)
	$table.Add("Networks (Standard Port Groups)", $networksCount)
	$table.Add("Networks (Standard Port Groups - Not Shared)", $networkNotSharedCount);
	$table.Add("Networks (Virtual Distributed Port Groups)", $dvNetworksCount);
	
	return $table
}

# work out the capacity for the entire vCenter instance -- not individual clusters

# Get TOTAL Stats
#	Syntax getTableResults($clusters,$vms,$vmhosts,$datastores,$vcenter)
$results = getTableResults -Clusters (get-cluster -Server $srvConnection) -vms (Get-vm -Server $srvConnection) -vmhosts (Get-vmhost -server $srvConnection) -datastores (Get-datastore -Server $srvConnection) -vcenter $srvConnection
$results | Select-Object -property Name,Value |  Sort-Object -Property Name 
$results.GetEnumerator() | select-object -property "Name","Value" | sort-object -Property Name |  Export-Csv $of -NoTypeInformation
if ($showDate) {
	Write-Output "" >> $of
	Write-Output "" >> $of
	Write-Output "Collected on $(get-date)" >> $of
}
Write-Host "Logs written to " $of -ForegroundColor  yellow;

### Working out for individual clusters now
# work out the capacity for the entire vCenter instance -- not individual clusters
Write-Host "Summarising infrastructure at the clusters level";
get-cluster -Server $srvConnection | %{
	$filename = ($($MyInvocation.MyCommand.Name)).TrimEnd('.ps1');
	$of = $logDir + "\"+$runtime+"_"+$vcenterName.ToUpper()+"_"+$filename+"_"+$($_.Name)+".csv"
	Write-Host "This script log to " $of -ForegroundColor Yellow 
    Write-Host "Getting Hosts" -ForegroundColor Yellow
	$results = getTableResults -Clusters $_ -VMs (Get-vm -Location $_) -Vmhosts (get-vmhost  -Location $_)  -Datastores (get-vmhost  -Location $_ | Get-datastore) -vCenter $srvConnection
	$results | Select-Object -property Name,Value |  Sort-Object -Property Name 
	$results.GetEnumerator() | select-object -property "Name","Value" | sort-object -Property Name |  Export-Csv $of -NoTypeInformation
	if ($showDate) {
		Write-Output "" >> $of
		Write-Output "" >> $of
		Write-Output "Collected on $(get-date)" >> $of
	}
	Write-Host "Logs written to " $of -ForegroundColor  yellow;

}


if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}