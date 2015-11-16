# Type in a PowerShell script here
# and finish it by either get- cmdlet or write-output

#Check vSwitches/Port Groups config in VCS for the 1st host in every cluster
#Version : 0.1
#Updated : 18th Sept 2009
#Author  : noorfaizal.noor@mincom.com

$row = "" | Select-Object "Datacenter","Cluster","VMHost","vSwitch","vmNIC",
"Ports","AllowPromiscuous","MacChanges",
"ForgedTransmits","ActiveNics","StandbyNics",
"PGName","PGVLanId","PGActiveNics",
"PGStandbyNics","PGAllowPromiscuous","PGMacChanges","PGForgedTransmits";

Get-Datacenter * | %{
  $row.Datacenter = $_.Name
  $_ | Get-Cluster | %{
 
    $row.Cluster = $_
	$ClusterName = $_
    # Select only the first returned host
    $_ | Get-VMHost | Select-Object | %{
	$row.VMHost = $_.Name
      $HostID = $_ | Get-View 
      $_ | Get-VirtualSwitch | foreach-object {
 	  	$row.vSwitch = $_.Name;
		$row.vmNIC = "$($_.NIC)";
		$row.Ports = $_.NumPorts;
		
		
         # Virtual Switch information from the Host
        $NetworkSystem = Get-View $HostID.ConfigManager.NetworkSystem;
		
		#$NetworkSystem = $HostID.ConfigManager.NetworkSystem;
        $currVSwitch = $NetworkSystem.NetworkConfig.vSwitch | ?{ $_.Name -eq $row.vSwitch }
        $row.AllowPromiscuous = $currVSwitch.Spec.Policy.Security.AllowPromiscuous;
        $row.MacChanges = $currVSwitch.Spec.Policy.Security.MacChanges
        $row.ForgedTransmits = $currVSwitch.Spec.Policy.Security.ForgedTransmits
        $row.ActiveNics = "$($currVSwitch.Spec.Policy.NicTeaming.NicOrder.ActiveNic)";
        $row.StandbyNics = "$($currVSwitch.Spec.Policy.NicTeaming.NicOrder.StandbyNic)";

        # Port Group Information from each Virtual Switch  
        $_ | Get-VirtualPortGroup | %{
          $PortGroup = $_
          $PortGroupConfig = $NetworkSystem.NetworkConfig.PortGroup | ?{ $_.Spec.Name -eq $PortGroup.Name }
          $row.PGName = $PortGroup.Name
		  if ($PortGroupConfig.Spec.Policy.NicTeaming.NicOrder.ActiveNic) {
		  	$row.PGActiveNics = "$($PortGroupConfig.Spec.Policy.NicTeaming.NicOrder.ActiveNic)";
		} else {
			$row.PGActiveNics = "inherited";
		}
		if($PortGroupConfig.Spec.Policy.NicTeaming.NicOrder.StandbyNic) {
			$row.PGStandbyNics = "$($PortGroupConfig.Spec.Policy.NicTeaming.NicOrder.StandbyNic)"; 
		} else {
			$row.PGStandbyNics = "inherited";
		 }
          if ($PortGroup.VLanId) {
		  	$row.PGVLanId = $PortGroup.VLanId
		  }else {
			$row.PGVLanId = "0";
		  }
          if($PortGroupConfig.Spec.Policy.Security.AllowPromiscuous) {
		  	$row.PGAllowPromiscuous = $PortGroupConfig.Spec.Policy.Security.AllowPromiscuous
	      } else {
		 	$row.PGAllowPromiscuous = "inherited";
		  }
          if ($PortGroupConfig.Spec.Policy.Security.MacChanges) {
		  	$row.PGMacChanges = $PortGroupConfig.Spec.Policy.Security.MacChanges
		  } else {
				$row.PGMacChanges = "inherited"
		  }
		  if ($PortGroupConfig.Spec.Policy.Security.ForgedTransmits) {
				$row.PGForgedTransmits = $PortGroupConfig.Spec.Policy.Security.ForgedTransmits
		  } else {
		 		$row.PGForgedTransmits = "inherited"
		  }
	 	  Write-Output $row;
        }
      }
    }
  }
}