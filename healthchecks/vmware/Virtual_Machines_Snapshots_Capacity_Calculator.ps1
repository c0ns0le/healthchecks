# This scripts calculates the amount of disk capacity required for a VM to be snapshots
# Syntax: snapshotCapacityCalculator.ps1 -vmname <NAME> [ -SpercValue 0-100 ]
# Version : 0.1
#Author : 16/06/2010, by teiva.rodiere-at-gmail.com
# More information
# This minimum value represents the capacity value on top of the disk requirement of a VM that must be available for that VM prior to taking snapshot
# Example: 
#		if the expectedCapacity is set to 100, then double the amount of VMDK size must exist on the datastore where the guest VMX lives
#		therefore; if a vm has a VMX config file on DATASTORE-01, then all it's snapshots will be taken on the same datastore. The a SUM of non-independent VMDK is taken
#		then a precentage define by the expectedCapacity value is added on top, then compare with the free space on the same datastore. If that value is larger
#		than freespace then we have a problem, otherwise we are deemed safe.
param([object]$srvConnection="",[string]$logDir="output",[int]$percValue=100,[string]$comment="")
logThis -msg "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global
$global:logfile
$global:outputCSV

# Want to initialise the module and blurb using this 1 function
#InitialiseModule


logThis -msg "Enumerating datacenters..." -ForegroundColor Cyan
$run1Report = Get-Datacenter -Server $srvConnection | %{
	$dc = $_.Name;
	logThis -msg "Enumerating clusters in datacenter $dc..." -ForegroundColor Cyan
	Get-Cluster -Location $dc | % { 
		$clustername = $_.Name;
		logThis -msg "Enumerating Hosts in cluster "$clustername"..." -ForegroundColor Cyan
		Get-VMHost -Location $clustername | Select-Object -First 1 | %{
			$vmhost = $_;
			logThis -msg "Enumerating Datastores on first cluster node"($vmhost.Name)"..." -ForegroundColor Cyan
			Get-Datastore -VMHost $vmhost | Get-View | % {
				$datastoreView = $_;
				logThis -msg "Processing Datastores "$($datastoreView.info.Name)"..." -ForegroundColor Yellow
				$datastoreFreeSpaceKB = $_.Summary.FreeSpace; # In KB
				foreach ($vmItem in $datastoreView.Vm) {
					$vmView = Get-View $vmItem;
					# only process VMs with VMX on current datastore
					if ( ($vmView.Config.Files.VmPathName).Contains($datastoreView.info.Name) )
					{
						$row = "" | Select-Object "Guest";
						$row.Guest = $vmView.Name
						$row | Add-Member -Type NoteProperty -Name "Datacenter" -Value  $dc; 
						$row | Add-Member -Type NoteProperty -Name "Cluster" -Value  $clustername;
						$row | Add-Member -Type NoteProperty -Name "Datastore" -Value  $datastoreView.info.Name

						# Calculate VM VMDK requirement				
						$diskKB = 0; 
						$vmView.Config.hardware.Device | ?{ ($_.DeviceInfo.Label -match "Hard Disk") -and !($_.Backing.DiskMode -match "independent") }  | %{
							$diskKB = $diskKB + $_.CapacityInKB; # It shows as KB, but it is in Mb already
						}
						$row | Add-Member -Type NoteProperty -Name "TotalDependentStorageSumGB" -Value "$([math]::ROUND($diskKB/1Mb))" ;
						
						$diskCount = 0;
						$vmView.Config.hardware.Device | ?{ ($_.DeviceInfo.Label -match "Hard Disk")} | % {
							$diskCount++;
						}
						$row | Add-Member -Type NoteProperty -Name "DiskCount" -Value $diskCount;
						
						$VMDKCOUNTINDEPENDENT = 0;
						$vmView.Config.hardware.Device | ?{ ($_.DeviceInfo.Label -match "Hard Disk") -and ($_.Backing.DiskMode -match "independent") } | %{
							$VMDKCOUNTINDEPENDENT++;
						}
						$row | Add-Member -Type NoteProperty -Name "IndependentDisks" -Value $VMDKCOUNTINDEPENDENT; 
						
						$DCUSERD = ($vmView.Config.DatastoreUrl).Count
						$row | Add-Member -Type NoteProperty -Name "ConnectedDatastores" -Value  $DCUSERD; 
						
						# Calculate Free space needed for Snapshoting the VM
						# 1) Sum of snapshotable VMDK
						# 2) Add (Swap size=Mem allocation - Mem Reservation
						# 3) Add Log file size
						$totalVMDiskReqKB = $diskKB; # Add TOTAL VMDK Size (non-independent disks only) Convert GB to MB *1Mb
						if ($vmView.Config.SwapPlacement -eq "inherit")
						{
							# Currently assuming that the swap file location is with set to live with the VMX file
							$vmResourcReqMB = $vmView.Summary.Config.MemorySizeMB - $vmView.ResourceConfig.MemoryAllocation.Reservation; # Convert to KB
							$totalVMDiskReqKB = $totalVMDiskReqKB + ($vmResourcReqMB * 1Kb);
						} 
						
						$oneLogFile = ($vmView.Config.ExtraConfig | ?{$_.Key -match "log.rotatesize"}).Value
						if ($oneLogFile)
						{
							$totalVMDiskReqKB += $oneLogFile; # Value in KB
						}
						$spaceNeededKB = ($totalVMDiskReqKB * $percValue) / 100 ;
						$spaceNeededGB = $spaceNeededKB / 1Mb;
						$row | Add-Member -Type NoteProperty -Name "SpaceReqOnVMFSGB" -Value $spaceNeededGB;
						
						$datastoreFreeSpaceGB = $datastoreFreeSpaceKB / 1Gb;
						$row | Add-Member -Type NoteProperty -Name "SpaceAvailOnVMFSGB" -Value $datastoreFreeSpaceGB ;
						
						if ($spaceNeededGB -le $datastoreFreeSpaceGB)
						{
							$verdictForSnapshot = "Yes";
						} else 
						{ 
							$verdictForSnapshot = "No"; 
						}
						
						$row | Add-Member -Type NoteProperty -Name "SnapshotCandidate" -Value $verdictForSnapshot;
						
						#$HostConfig | Add-Member -Type NoteProperty -Name "FCHBA$($i)_Device" -Value  $hba.Device
						
						# VM space (VMDK + Mem + (Current swap file)
						
						$row | Add-Member -Type NoteProperty -Name "vCenter" -Value $vcenterName;

						logThis -msg $row;
						$row;
						
						#exit;
					}
				}
			}
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

ExportCSV -table $Report 

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}
#test