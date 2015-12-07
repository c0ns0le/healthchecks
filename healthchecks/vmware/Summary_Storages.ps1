# This scripts provides some capacity information for an environment 
# The results is used as an input into a Capacity Review Report
# Last updated: 8 March 2012
# Author: teiva.rodiere-at-gmail.com
#
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$showDate=$false)
logThis -msg "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global
$global:logfile
$global:outputCSV

# Want to initialise the module and blurb using this 1 function
#InitialiseModule


#Definitions for max vCPU/core and Mem reservations
$vCPUPerpCorePolicyLimit = 4; #max of 4vCPU per core
$mem = 100; # 100%

$datastoresCount = 0
$xivCount = 0
$v7000Count = 0
$svcCount = 0
$otherCount = 0
$totalSize = 0
$totalFree = 0
$thinLUNs = 0
$thickLUNs = 0



$table = @{}

logThis -msg "Processing VMs in vCenter $_" -Foregroundcolor Green
logThis -msg "Datastores" -ForegroundColor Yellow
if ($clusterName)
{
	$datastores = Get-Cluster $clusterName -Server $srvConnection | Get-VMhosts -Server $srvconnection | Get-Datastore -Server $srvconnection
} else {
	$datastores = Get-Datastore * -Server $srvconnection
}

# Exporting all $srvconnection
$sharedStorageCapacityMB = $datastores | measure CapacityMB -sum
$datastoresCapacityTB = [math]::ROUND($sharedStorageCapacityMB.Sum / 1024 / 1024 , 2)
$sharedStorageFreeMB = $datastores | measure FreeSpaceMB -sum
$sharedStorageFreeTB = [math]::ROUND($sharedStorageFreeMB.Sum / 1024 / 1024, 2)
$freeperc = [math]::ROUND($sharedStorageFreeTB / $datastoresCapacityTB * 100, 2)
$table.Add("Total Datastores Count",($datastores | select Name -unique).Count)
$table.Add("Total Datastores Size (TB)",[math]::ROUND($datastoresCapacityTB,2))
$table.Add("Total Datastores Freespace","$([math]::ROUND($freeperc,2))%")

#$vmsView = Get-VM -Server $srvconnection | Get-View
#$table.Add("Disk",$count);

logThis -msg "Get SCSI LUNs to determine the different types of storage" -ForegroundColor Yellow
$scsiLuns = $datastores | Get-ScsiLUN

$scsiLunVendorModel = $scsiLUNs | %{
      $_ | %{
         Write-output "$($_.Vendor.Trim()) $($_.Model.Trim())"
      }
}
#$scsiLunVendorModel 
$uniqueLUNTypes = $scsiLunVendorModel | select -unique
$count = 0;
$uniqueLUNTypes | %{
    $lunTypeName = $_
    #remove-variable $_.replace(" ","")
    #new-variable -name $_.replace(" ","") -visibility public -value 0
    $luns = $scsiLUNs | select CanonicalName,Model,Vendor,CapacityMB -unique | ?{$($_.Vendor.Trim() + " " + $_.Model.Trim()) -match $lunTypeName.Trim()}
    $count = $luns.Count
    $capacityMB = $luns | measure CapacityMB -sum
    $capacityTB = [math]::ROUND($capacityMB.Sum / 1024 / 1024,2)
    #set-variable -name $_.replace(" ","") -value $count
    #logThis -msg $count
    $table.Add($lunTypeName +" Count",$count);
    $table.Add($lunTypeName + " Capacity (TB)",$capacityTB);
    $count = 0;
}
logThis -msg $table

ExportCSV -table ($table.GetEnumerator() | select -property Name,Value)

logThis -msg "Logs written to " $of -ForegroundColor  yellow;

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}