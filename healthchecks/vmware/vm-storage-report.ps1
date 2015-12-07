# Storage Capacity Report for Common Infrastructure
#Version : 0.1
#Updated : 8th Sept 2009
#Author  : teiva.rodiere@gmail.com 
$myarray = "" | Select Cluster,VMName,GuestState,ToolsStatus,ToolsVersion,DiskName,Persistent,VMDKCapacityGB,Datastore,MountPoint,CapacityGB,FreeSpaceGB,PercFree;
get-cluster | foreach-object {
		$cluster = $_.Name; 
		get-vm -Location $_ | foreach-object {
				$myarray.Cluster = $cluster;
				$myarray.VMName = $_.Name;
				$myarray.ToolsStatus = $_.Guest.ToolsStatus;
				$myarray.GuestState = $_.Guest.GuestState;
				$myarray.ToolsVersion = $_.Guest.ToolsVersion;
				$guestdisks = $_.Guest.Disks;
				$vmdkdisks = $_ | Get-HardDisk;
				for ($i = 0; $i -lt $guestdisks.Length; $i++) 
				{	
					if ($vmdkdisks.GetType().Name -eq "Object[]") {
						$disk = $vmdkdisks[$i];
					} else {
						$disk = $vmdkdisks;
					}
					if ($disk)
					{
					$diskpath = $disk.Filename;
					$datastore,$vmdk = $diskpath.Split(" ");
					$datastore = $datastore -replace "\[", " ";
					$datastore = $datastore -replace "\]","";
					$myarray.DiskName = $vmdk;
					$myarray.VMDKCapacityGB = [math]::Round($disk.CapacityKB/1Mb);
					$myarray.Persistent = $disk.Persistence;
					$myarray.Datastore = $datastore;
					
					$guestdisk = "";
					$myarray.MountPoint = "";
					$myarray.FreeSpaceGB = 0;
					$myarray.CapacityGB = 0;
					$myarray.PercFree = 0;
					
					#if ($myarray.GuestState)
					#{
						$guestdisk = $guestdisks[$i];
						$myarray.MountPoint = $guestdisk.Path;
						$myarray.FreeSpaceGB = [math]::Round($guestdisk.FreeSpace/1Gb);
						$myarray.CapacityGB = [math]::Round($guestdisk.Capacity/1Gb);
						if ($guestdisk.Capacity) {
							$myarray.PercFree = [math]::Round( (100*($guestdisk.Freespace/$guestdisk.Capacity)));
						}	
							Write-Output $myarray;
						#}
					}
				}	

		}
	}