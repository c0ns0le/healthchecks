# This script assumes that the servers are wihtin the same vcenter, can easily be changed
# teiva
$srvconnection = get-vc vtx-qld-dcb1-vvc01
$sourceHost = "mmsbneesx01.gms.mincom.com"
$targetHost = "vtx-qld-dcb1-svr01.gms.mincom.com"

if ($srvconnection) 
{
	#Collecting source information
	$sourceHostObj = Get-VMHost -Name $sourceHost -Server $srvconnection 
	write-host "Exporting vSwithes configurations from $sourceHost"
	$sourcevSwitches = $sourceHostObj | Get-VirtualSwitch 
	write-host "Exporting Port Group configurations from $targetHost"
	$sourcevPGs = $sourceHostObj | Get-VirtualPortGroup

	#Collecting target host information
	$targethostObj = Get-VMHost -Name $targetHost -Server $srvconnection 
	write-host "Exporting vSwithes configurations of target $targetHost"
	$targetvSwitches = $targethostObj | Get-VirtualSwitch 
	write-host "Exporting Port Group configurations of target $targetHost"
	$targetvPGs = $targetHostObj | Get-VirtualPortGroup

	# determine the difference
	$differencevSwitches = Compare-Object $sourcevSwitches $targetvSwitches
	$differencevPGs = Compare-Object $sourcevPGs $targetvPGs

	# Only process the difference
	$differencevSwitches | %{ 
		$newvSwitch = $_.InputObject
		Write-Host "Creating Virtual Switch $($newvSwitch.Name) on $targetHost"
	    if($newvSwitch.Nic) {
			$outputvSwitch = $targethostObj | New-VirtualSwitch -Name $newvSwitch.Name -NumPorts $newvSwitch.NumPorts -Mtu $newvSwitch.Mtu -Nic $newvSwitch.Nic
		} else {
			$outputvSwitch = $targethostObj | New-VirtualSwitch -Name $newvSwitch.Name -NumPorts $newvSwitch.NumPorts -Mtu $newvSwitch.Mtu
		}
	}

	# Only Process Port Groups
	$differencevPGs | %{ 
		$newvPG = $_.InputObject
		Write-Host "Creating Port group ""$($newvPG.Name)"" on vSwitch ""$($newvPG.VirtualSwitchName)"" on target host $targetHost"
		$outputvPG = $targethostObj | Get-VirtualSwitch -Name $newvPG.VirtualSwitchName | New-VirtualPortGroup -Name $newvPG.Name-VLanId $newvPG.VLanID
	}
}