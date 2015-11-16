# queries cluster

$myarray = "" | Select "VMhost","FC-WWPN";
$clustername = args[0];

Get-VMhost -Location $clustername | Get-View | foreach-object { 
	$myarray.VMhost = $_.Name
	foreach($hba in $_.config.storagedevice.hostbusadapter) {
		if ($hba.GetType().Name -eq "HostFibreChannelHba") { 
			$wwpn = $hba.PortWorldWideName; 
			$wwpnhex = "{0:x}" -f $wwpn; 
			if ($myarray.FC-WWPN.Lenght > 0)
				$myarray.FC-WWPN = $myarray.FC-WWPN + "," $wwpnhex;
			else
				$myarray.FC-WWPN = $wwpnhex;
 		}
	} 
	Write-Output $myarray;
}
