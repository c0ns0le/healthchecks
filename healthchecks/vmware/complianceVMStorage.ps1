# Storage Capacity Report for Common Infrastructure
#Version : 0.1
#Updated : 8th Sept 2009
#Author  : teiva.rodiere-at-gmail.com 

$row = "" | Select VMName,GuestFullName,GuestState,ToolsStatus,ToolsVersion,MountPoint,CapacityMB,FreeSpaceMB,PercFree,Cluster;
get-cluster | foreach-object {
	$cluster = $_.Name; 
	get-vm -Location $_ | Get-View | foreach-object {
		$row.Cluster = $cluster;
		$row.VMName = $_.Name;
		$row.ToolsStatus = $_.Guest.ToolsStatus;
		$row.GuestState = $_.Guest.GuestState;
		$row.ToolsVersion = $_.Guest.ToolsVersion;
		$row.GuestFullName = $_.Guest.GuestFullName;
		foreach ($volume in $_.Guest.Disk)
		{
			$row.MountPoint = "";
			$row.FreeSpaceMB = 0;
			$row.CapacityMB = 0;
			$row.PercFree = 0;
			
			$row.MountPoint = $volume.DiskPath;
			$row.FreeSpaceMB = [math]::Round($volume.FreeSpace/1Mb);
			$row.CapacityMB = [math]::Round($volume.Capacity/1Mb);
			if ($volume.Capacity) {
				$row.PercFree = [math]::Round( (100*($volume.Freespace/$volume.Capacity)));
			}	
			Write-Output $row;
		}
	}	

}