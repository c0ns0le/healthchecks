# Scans ESX servers in vCenter server, collect configuration information related to the NIC and the CISCO ports using CDP.
# Note it does not check if CDP is enabled per NIC
#Version : 0.1
#Last Updated : 11th Aug 2010
#Maintained by: teiva.rodiere@gmail.com 
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$verbose=$false)
Write-Host "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global
$global:logfile
$global:outputCSV

# Want to initialise the module and blurb using this 1 function
InitialiseModule

$report1 = @()
$report1 = $srvConnection | %{
    $vCenter = $_.Name
    logThis -msg "Processing hosts in vCenter $vCenter" -ForegroundColor Cyan
    $vmhosts = Get-VMHost -Server $_.Name | Sort Name | Get-View
    $hostCount = 0;
    $index=1;
    if ($vmhosts) 
    {
        if ($vmhosts.Count)
        {
            $hostCOunt = $vmhosts.count
        } else { $hostCOunt = 1 }
    }
    logThis -msg "$hostCOunt host(s) found.."
    $vmhosts | %{
        $vmhost = $_
        $cluster = $(Get-VMhost -Name $vmhost.Name | Get-Cluster).Name
        $datacenter = $(Get-datacenter -VMhost $vmhost.Name).Name
        logThis -msg "Processing host $index/$hostCount - $($vmhost.name)" -Foregroundcolor Yellow
        $networkSystem = Get-view $vmhost.ConfigManager.NetworkSystem
        $networkSystem.NetworkInfo.Pnic | sort Device | %{
            $pnic = $_
            $row = "" | select-Object "Hostname";
            $row.Hostname = $vmhost.Name
			$row | Add-Member -Type NoteProperty -Name "Interface" -Value $pnic.Device 
            $vSwitch = $networkSystem.NetworkInfo.vSwitch | ?{$_.Pnic -contains $pnic.Key}
            if (!$vSwitch)
            {
                $row | Add-Member -Type NoteProperty -Name "vSwitch" -Value "Unused"
            } else {
                $row | Add-Member -Type NoteProperty -Name "vSwitch" -Value "$($vSwitch.Name)"
            }
                            
            $row | Add-Member -Type NoteProperty -Name "NICSpeed" -Value $pnic.LinkSpeed.SpeedMb
            $row | Add-Member -Type NoteProperty -Name "NICDuplex" -Value $pnic.LinkSpeed.Duplex
            $row | Add-Member -Type NoteProperty -Name "MAC" -Value $($pnic.Mac).ToUpper()
            $row | Add-Member -Type NoteProperty -Name "Driver" -Value $pnic.Driver
            
            
            $pnicInfo = $networkSystem.QueryNetworkHint($pnic.Device)
            $switchInfo = $pnicInfo | %{$_.ConnectedSwitchPort}
#            if ($pnicInfo.ConnectedSwitchPort)
            #{
             #   Remove-Variable "switchInfo"
                #$switchInfo = $pnicInfo | select -expand ConnectedSwitchPort
            #}
            
            if ($switchInfo) 
            {
                $row | Add-Member -Type NoteProperty -Name "AutoNegoDuplex" -Value $switchInfo.FullDuplex
                $row | Add-Member -Type NoteProperty -Name "PortID" -Value $switchInfo.PortId
                $row | Add-Member -Type NoteProperty -Name "PortVLAN" -Value $switchInfo.Vlan
                $row | Add-Member -Type NoteProperty -Name "SwitchName" -Value $switchInfo.DevId 
                $row | Add-Member -Type NoteProperty -Name "SwitchAddress" -Value $switchInfo.Address
                $row | Add-Member -Type NoteProperty -Name "HardwarePlatform" -Value $switchInfo.HardwarePlatform
                $row | Add-Member -Type NoteProperty -Name "SoftwareVersion" -Value $switchInfo.SoftwareVersion
            } else {
                $row | Add-Member -Type NoteProperty -Name "AutoNegoDuplex" -Value ""
                $row | Add-Member -Type NoteProperty -Name "PortID" -Value ""
                $row | Add-Member -Type NoteProperty -Name "PortVLAN" -Value ""
                $row | Add-Member -Type NoteProperty -Name "SwitchName" -Value ""
                $row | Add-Member -Type NoteProperty -Name "SwitchAddress" -Value ""
                $row | Add-Member -Type NoteProperty -Name "HardwarePlatform" -Value ""
                $row | Add-Member -Type NoteProperty -Name "SoftwareVersion" -Value ""
            }
            
            $networks = ""; $vlans = "";             
            $subnetInfo = $pnicInfo | %{$_.Subnet};
            if ($subnetInfo)
            {
                $subnetInfo | %{
                    if (!$networks)
                    {
                        $networks = $_.IpSubnet + "[$($_.VlanId)]"
                    } else {
                        $networks += ","+ $_.IpSubnet + "[$($_.VlanId)]"
                    }
                    
                    if (!$vlans)
                    {
                        $vlans += "$($_.VlanId)"
                    } else {
                        $vlans += ",$($_.VlanId)"
                    }
                }
                
            }
            $row | Add-Member -Type NoteProperty -Name "ObservedNetworks" -Value $networks
            $row | Add-Member -Type NoteProperty -Name "ObservedVLANs" -Value $vlans
            
            $row | Add-Member -Type NoteProperty -Name "Cluster" -Value $cluster
            $row | Add-Member -Type NoteProperty -Name "vCenter" -Value $vCenter
            $row | Add-Member -Type NoteProperty -Name "Datacenter" -Value $datacenter
            
            if ($verbose)
            {
               logThis -msg $row
            }
            $row
            
            Remove-Variable "row"
            #$ObservedNetworks = $ObservedVLANs = $networkSystem = $false;            
        }
        $index++;
        Remove-variable "cluster", "datacenter"
	}
}

ExportCSV -table $report1

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}