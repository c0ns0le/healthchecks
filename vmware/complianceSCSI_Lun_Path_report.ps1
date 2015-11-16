# LunParity
#odd_luns
#even_luns
#$myarray = "" | Select Datacenter,Cluster,ESXHost,CanonicalName,HBADevice,SCSITarget,LunID,LunParity,Policy,Paths,Capacity,Preferred,State,LunParity;
$myarray = "" | Select Datacenter,Cluster,ESXHost,Datastore,HBADevice,SCSITarget,LunID,LunParity,Policy,Paths,Capacity,Preferred,State,LunParity;
foreach ($dc in (Get-Datacenter -Name *))
{
	# Enumerate Clusters
	foreach ($cluster in (Get-Cluster -Location $dc.Name))
	{
		foreach ($esxhost in (Get-VMHost -Location $cluster.Name))
		{
			$esx = Get-VMHost -Name $esxhost.Name | Get-View
			foreach($disk in $esx.Config.StorageDevice.ScsiLun)
			{
				foreach($lun in $esx.Config.StorageDevice.MultipathInfo.Lun)
				{
					if($disk.CanonicalName -eq $lun.Id){
					foreach ($path in $lun.Path)
					{
						$myarray.Datacenter = $dc.Name;
						$myarray.Cluster = $cluster.Name;
						$myarray.ESXHost = $esx.Name;
						$myarray.Datastore = $disk.Name;
						#$myarray.CanonicalName = $disk.CanonicalName;
						$myarray.Paths = $lun.Path.Count;
						$myarray.Policy = $lun.Policy.Policy;
						$myarray.Capacity = ($disk.Capacity.Block * $disk.Capacity.BlockSize) / 1Mb
							# Disk line
						#$line = "Disk " + $disk.CanonicalName + " (" + $capacityMb + "MB) has " + $pathNumber + " paths and policy of " + $policyName
							#Write-Host $line
							# Path line(s)
						$preferredPath = $lun.Policy.Prefer;
						#foreach($path in $lun.Path)
						#{ 
					
						$device,$scsi,$lunid = $disk.CanonicalName.Split(':'); #$disk.CanonicalName.IndexOf(":"))
						#$scsi = $disk.CanonicalName.Split(1,$disk.CanonicalName.IndexOf(":"))
						#$lunid = $disk.CanonicalName.Split(2,$disk.CanonicalName.IndexOf(":"))
						switch ($lunid)
						{
							{$_ %2} {$myarray.LunParity="Odd"}
							default {$myarray.LunParity="Even"}
						}
						foreach($hba in $esx.Config.StorageDevice.HostBusAdapter)
						{
						if($hba.Device -eq $device){break}
						}
						if($path.Name -eq $preferredPath)
						{
							$preferred = "preferred"
						}
						else{$preferred = ""} 
						switch($path.PathState)
						{
							"active" {$pathStatus = "On active"};
							"disabled" {$pathStatus = "Off"};
							"standby" {$pathStatus = "On"};
							default {$pathStatus = "unknown"};
						}
						switch($path.Transport.gettype().Name)
						{
							"HostParallelScsiTargetTransport" 
							{
								$line = " Local " + $hba.Pci + " " + $path.Name + " " + $pathStatus + " " + $preferred;
							}
							"HostInternetScsiTargetTransport" 
							{
								$line = " iScsi sw " + $hba.IScsiName + " <-> " + $path.Transport.IScsiName + " " + $pathStatus + " " + $preferred;
							}
						}
						$myarray.Preferred = $preferred;
						$myarray.State = $pathStatus;
						$myarray.HBADevice = $device;
						$myarray.SCSITarget = $scsi;
						$myarray.LunID = $lunid;
						Write-Output $myarray;
						}
						break;
					}
				}
			}
		}
	}
}