# Scans the VMware Infrastructure and documents hardware and software configurations 
# of Virtual Center Server and esx/esxi systems
#Version : 0.8
#Last Updated : 12th Feb 2010, teiva.rodiere-at-gmail.com
#Author : teiva.rodiere-at-gmail.com 
#Syntax: ".\documentVMHosts.ps1"
#Inputs: vcenter server name, username, and password
#Output file: "documentVMHost.csv"
#Version : 0.4
#Author : 04/06/2010, by teiva.rodiere-at-gmail.com
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$verbose=$false,[bool]$formatList=$true)
Write-Host "Executing script $($MyInvocation.MyCommand.path)" -ForegroundColor  green;
Write-Host "Current path is $($pwd.path)" -ForegroundColor  yellow;

$now = Get-date
$disconnectOnExist = $true;

if (!$srvConnection -or ( ($srvconnection.GetType().Name -ne "VIServerImpl") -and ($srvconnection.GetType().Name -ne "Object[]") ) )
{ 
	$vcenterName = Read-Host "Enter virtual center server name"
	Write-Host "Connecting to virtual center server $vcenterName.."
	$srvConnection = Connect-VIServer -Server $vcenterName
	$disconnectOnExist = $true;	
} else {
	$disconnectOnExist = $false;
	$vcenterName = $srvConnection.Name;
}

Write-Host $srvConnection.Name;

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
Write-Host "This script log to " $of -ForegroundColor $global:colours.Information 

#Variables and Constants
$TechContact="INF-VMWARE"
$choice_VC_CustomAttributes="Veeam_ems_node,Veeam_segment"
$choice_BIOS_CPU_NXFlag="Enabled/Disabled" #Enabled/Disabled
$choice_BIOS_CPU_VTFlag="Enabled/Disabled" #Enabled/Disabled
$choice_BIOS_PXEOff="Yes/No" #Yes/No
$choice_BIOS_CPU_MPSFullTableApic="On/Off" #On/Off
$choice_NPIV="Yes/No"
$choice_PatchGroups="1/2/3/4"
$choice_Memtested="Yes/No"
$defaults_NA="[N/A]"

$run1Report = $srvConnection | %{
        $vCenterServer = $_.Name;
        Write-Host "Processing VMHosts from vCenter server ""$vCenterServer""..." -ForegroundColor $global:colours.Information
        $vmhostsView = Get-VMHost -Server $_ | sort Name | Get-View
        Write-Host "Found $($vmhostsView.Count)" -ForegroundColor $global:colours.Information
        $hostCount = 1;
        $vmhostsView | %{
            Write-Host "Processing $hostCount/$($vmhostsView.Count) - $($vmhostView.Name)..."
    		$vmhostView = $_
            $vmhost	= Get-VMhost -Name $vmhostView.Name
    		$HostConfig = "" | Select-Object "VMhost";
    		
    		$clusterName = Get-Cluster -VMHost $vmhostView.Name
    		$HostConfig.VMHost = $vmhostView.Config.Network.DnsConfig.HostName
    		
    		$HostConfig | Add-Member -Type NoteProperty -Name "FQDN" -Value  $vmhostView.Name
            $HostConfig | Add-Member -Type NoteProperty -Name "BootTime" -Value  $vmhostView.Summary.Runtime.BootTime
            $HostConfig | Add-Member -Type NoteProperty -Name "InMaintenanceMode" -Value  $vmhostView.Summary.Runtime.InMaintenanceMode
            $HostConfig | Add-Member -Type NoteProperty -Name "ConnectionState" -Value  $vmhostView.Summary.Runtime.ConnectionState
            $HostConfig | Add-Member -Type NoteProperty -Name "Health" -Value  $vmhostView.Summary.OverallStatus
            $HostConfig | Add-Member -Type NoteProperty -Name "VMotionEnabled" -Value  $vmhostView.Summary.Config.VmotionEnabled
            
            # Determine the error count for the last 30 days
            $last7DaysErrors = Get-VIEvent -Type error -Start $now.AddDays(-7) -Entity $vmhost -MaxSamples ([int]::MaxValue) -Server $srvConnection
            $hostErrors = 0;
            if ($last7DaysErrors.Count -gt 0)
            {
                $hostErrors = $last7DaysErrors.Count
            }
            $HostConfig | Add-Member -Type NoteProperty -Name "ErrorsCountLast7Days" -Value  $hostErrors
            
            # Determine the error count for the last 30 days
            $last30DaysErrors = Get-VIEvent -Type error -Start $now.AddDays(-30)  -Entity $vmhost -MaxSamples ([int]::MaxValue) -Server $srvConnection
            $hostErrors = 0;
            if ($last30DaysErrors.Count -gt 0)
            {
                $hostErrors = $last30DaysErrors.Count
            }
            
            $HostConfig | Add-Member -Type NoteProperty -Name "ErrorsCountLast30Days" -Value  $hostErrors
            
            $HostConfig | Add-Member -Type NoteProperty -Name "RequiresReboot" -Value  $vmhostView.Summary.RebootRequired
    		$HostConfig | Add-Member -Type NoteProperty -Name "ProductName" -Value  $vmhostView.Config.Product.Name
    		$HostConfig | Add-Member -Type NoteProperty -Name "ProductVersion" -Value  $vmhostView.Config.Product.Version
    		$HostConfig | Add-Member -Type NoteProperty -Name "ProductBuild" -Value  $vmhostView.Config.Product.Build
    		$HostConfig | Add-Member -Type NoteProperty -Name "HardwareVendor" -Value  $vmhostView.Hardware.SystemInfo.Vendor
    		$HostConfig | Add-Member -Type NoteProperty -Name "Model" -Value  $vmhostView.Hardware.SystemInfo.Model
            if ($vmhostView.Summary.Hardware.OtherIdentifyingInfo)
            {
                $vmhostView.Summary.Hardware | Select-Object -ExpandProperty "OtherIdentifyingInfo" | %{
                    $HostConfig | Add-Member -Type NoteProperty -Name "$($_.IdentifierType.Label)" -Value  "$($_.IdentifierValue)"
                }
            }
            $HostConfig | Add-Member -Type NoteProperty -Name "VMAutoStart" -Value $vmhostView.Config.AutoStart.Defaults.Enabled
    		$HostConfig | Add-Member -Type NoteProperty -Name "BiosVersion" -Value  $vmhostView.Hardware.BiosInfo.BiosVersion
    		$HostConfig | Add-Member -Type NoteProperty -Name "BIOSReleaseDate" -Value $vmhostView.Hardware.BiosInfo.ReleaseDate 
    		$HostConfig | Add-Member -Type NoteProperty -Name "vCenter" -Value  $vCenterServer
            $HostConfig | Add-Member -Type NoteProperty -Name "Cluster" -Value $clusterName.Name
            $HostConfig | Add-Member -Type NoteProperty -Name "Datacenter" -Value  $(Get-Datacenter -VMHost $vmhostsView[0].Name).Name
    		$HostConfig | Add-Member -Type NoteProperty -Name "CPUType" -Value  $vmhostView.Hardware.CpuPkg[0].Description
    		$HostConfig | Add-Member -Type NoteProperty -Name "CPUSockets" -Value  $vmhostView.Hardware.CpuInfo.NumCpuPackages
    		$HostConfig | Add-Member -Type NoteProperty -Name "CPUCores" -Value  $vmhostView.Hardware.CpuInfo.NumCpuCores
    		$HostConfig | Add-Member -Type NoteProperty -Name "CoreSpeedMhz" -Value  "$([math]::ROUND($vmhostView.Hardware.CpuInfo.Hz / 1Mb))"
    		$HostConfig | Add-Member -Type NoteProperty -Name "TotalCPUMhz" -Value  "$([math]::ROUND(($vmhostView.Hardware.CpuInfo.NumCpuCores * $vmhostViewHardware.CpuInfo.Hz) / 1Mb))"
    		$HostConfig | Add-Member -Type NoteProperty -Name "HyperThreadingAvailable" -Value  $vmhostView.Config.HyperThread.Available
    		$HostConfig | Add-Member -Type NoteProperty -Name "HyperThreadingActive" -Value  $vmhostView.Config.HyperThread.Active
            $HostConfig | Add-Member -Type NoteProperty -Name "NumaInfo" -Value  $vmhostView.Hardware.NumaInfo.Type
            $HostConfig | Add-Member -Type NoteProperty -Name "NumNodes" -Value  $vmhostView.Hardware.NumaInfo.NumNodes
            $HostConfig | Add-Member -Type NoteProperty -Name "MaxEVCModeKey" -Value  $vmhostView.Summary.MaxEVCModeKey
            $HostConfig | Add-Member -Type NoteProperty -Name "CurrentEVCModeKey" -Value  $vmhostView.Summary.CurrentEVCModeKey
    		$HostConfig | Add-Member -Type NoteProperty -Name "MemoryMB" -Value  "$([math]::ROUND($vmhostView.Hardware.MemorySize/1Mb))"
    		$HostConfig | Add-Member -Type NoteProperty -Name "PXE_Off" -Value  " "
    		$HostConfig | Add-Member -Type NoteProperty -Name "MPSFullTable" -Value  " "
    		$HostConfig | Add-Member -Type NoteProperty -Name "CPU_NX" -Value  " "
    		$HostConfig | Add-Member -Type NoteProperty -Name "VT_Enabled" -Value  " "
            $HostConfig | Add-Member -Type NoteProperty -Name "VMs" -Value  $vmhostView.Vm.Count
            $HostConfig | Add-Member -Type NoteProperty -Name "Datastores" -Value  $vmhostView.Datastore.Count
    		$HostConfig | Add-Member -Type NoteProperty -Name "ScsiLuns" -Value $vmhostView.Config.StorageDevice.ScsiLun.Count
            $HostConfig | Add-Member -Type NoteProperty -Name "TotalScsiPaths" -Value $vmhostView.Config.MultipathState.Path.Count
            $HostConfig | Add-Member -Type NoteProperty -Name "ActiveScsiPaths" -Value $($vmhostView.Config.MultipathState.Path | ?{$_.PathState -eq"active"}).Count
            
    		# LocalHBA - Working except Firmwares
    		$i = 1
    		foreach($hba in ($vmhostView.config.storagedevice.hostbusadapter | ?{$_.GetType().Name -eq "HostBlockHba"})) {
    			$HostConfig | Add-Member -Type NoteProperty -Name "Controller$($i)" -Value  $hba.Model
    			$HostConfig | Add-Member -Type NoteProperty -Name "Controller$($i)_Device" -Value  $hba.Device
    			$HostConfig | Add-Member -Type NoteProperty -Name "Controller$($i)_Firmware" -Value  " "
    			$HostConfig | Add-Member -Type NoteProperty -Name "Controller$($i)_Driver" -Value  $hba.Driver
    			$i++;
    		}
    	
    		#FC HBA - Working except Firmwares
    		$HostConfig | Add-Member -Type NoteProperty -Name "NumFC-Ports" -Value  ($vmhostView.config.storagedevice.hostbusadapter | ?{$_.GetType().Name -eq "HostFibreChannelHba"}).Count
    		
    		# HBAs	
    		$arrayPci = @("0")
    		# Class id for FC HBA is 3076
    		foreach ($pcidevice in ($vmhostView.Hardware.PciDevice | ?{$_.ClassId -eq 3076})){
    			if ($arrayPci -notcontains $pcidevice.SubDeviceId) {
    				$arrayPci += $pcidevice.SubDeviceId
    			}
    		}
    		$HostConfig | Add-Member -Type NoteProperty -Name "NumFC_HBAs" -Value  "$([math]::ROUND($arrayPci.Count - 1))"
    		#$HostConfig | Add-Member -Type NoteProperty -Name "NumNIC_HBAs" -Value  $arrayPci.Count
    		
    		$i = 1
    		foreach($hba in ($vmhostView.config.storagedevice.hostbusadapter | ?{$_.GetType().Name -eq "HostFibreChannelHba"})) {
    			$wwpn = $hba.PortWorldWideName; 
    			$wwpnhex = "{0:x}" -f $wwpn;
    			$HostConfig | Add-Member -Type NoteProperty -Name "FCHBA$($i)" -Value  $hba.Model
    			$HostConfig | Add-Member -Type NoteProperty -Name "FCHBA$($i)_Device" -Value  $hba.Device
    			$HostConfig | Add-Member -Type NoteProperty -Name "FCHBA$($i)_Driver" -Value  $hba.Driver
    			$HostConfig | Add-Member -Type NoteProperty -Name "FCHBA$($i)_Firmware" -Value  " "			
    			$HostConfig | Add-Member -Type NoteProperty -Name "FCHBA$($i)_WWPN" -Value $wwpnhex
    			$HostConfig | Add-Member -Type NoteProperty -Name "FCHBA$($i)_NPIV" -Value  " "
    			$i++;			
    		}
    		
    		# Service Consoles
    		if ($vmhostView.Config.Network.ConsoleVnic){
    			$i=1
    			Write-Host "Host has " ($vmhostView.Config.Network.ConsoleVnic).Count " Services Consoles..."
    			foreach ($cos in $vmhostView.Config.Network.ConsoleVnic) {

    				$HostConfig | Add-Member -Type NoteProperty -Name "COS$($i)_Device" -Value  $cos.Device 
    				$HostConfig | Add-Member -Type NoteProperty -Name "COS$($i)_PortGroup" -Value  $cos.Portgroup
    				$HostConfig | Add-Member -Type NoteProperty -Name "COS$($i)_IP" -Value  $cos.Spec.IP.IpAddress 
    				$HostConfig | Add-Member -Type NoteProperty -Name "COS$($i)_Subnet" -Value  $cos.Spec.IP.SubnetMask
    				$HostConfig | Add-Member -Type NoteProperty -Name "COS$($i)_GW" -Value  $vmhostView.Config.Network.ConsoleIpRouteConfig.DefaultGateway
    				$HostConfig | Add-Member -Type NoteProperty -Name "COS$($i)_MemoryMB" -Value  "$([math]::ROUND($vmhostView.Config.ConsoleReservation.ServiceConsoleReserved / 1Mb))"
    				
    				$portGroup = Get-VirtualPortGroup -VMHost $vmhostView.Name -Name $cos.Portgroup
    				$HostConfig | Add-Member -Type NoteProperty -Name "COS$($i)_VLAN" -Value  $portGroup.VlanId
    				$HostConfig | Add-Member -Type NoteProperty -Name "COS$($i)_vSwitch" -Value  $portGroup.VirtualSwitchName
    				$HostConfig | Add-Member -Type NoteProperty -Name "COS$($i)_MAC" -Value  $cos.Spec.Mac
    				$i++
    			}
    		}
    	
    		#Vmkernel Ports
            if ($vmhostView.Summary.Config.VmotionEnabled)
            {
                $nicType,$vimType,$vmkPort = $($($vmhostView.Config.VirtualNicManagerInfo.NetConfig | ?{$_.NicType -eq "vmotion"}).SelectedVnic).Split("-") # example vmotion.key-vim.host.VirtualNic-vmk1
            }
            
    		if ($vmhostView.Config.Network.Vnic){
    			$i = 1
    			#Write-Host "Host has " ($vmhostView.Config.Network.Vnic).Count " VMKernel ports..."
    			foreach ($vmknic in $vmhostView.Config.Network.Vnic | sort Device ) {
    				$HostConfig | Add-Member -Type NoteProperty -Name "VMKernel$($i)" -Value  $vmknic.Portgroup
    				$HostConfig | Add-Member -Type NoteProperty -Name "VMKernel$($i)_Device" -Value  $vmknic.Device
    				
    				$portGroup = Get-VirtualPortGroup  -VMHost $vmhostView.Name -Name $vmknic.Portgroup
    				$HostConfig | Add-Member -Type NoteProperty -Name "VMKernel$($i)_VLAN" -Value  $portGroup.VLanId
    				#$HostConfig | Add-Member -Type NoteProperty -Name "VMKernel$($1)_MAC" -Value  $vmknic.Spec.Mac
    				$HostConfig | Add-Member -Type NoteProperty -Name "VMKernel$($i)_vSwitch" -Value  $portGroup.VirtualSwitchName
    				$HostConfig | Add-Member -Type NoteProperty -Name "VMKernel$($i)_IP" -Value  $vmknic.Spec.IP.IpAddress
    				$HostConfig | Add-Member -Type NoteProperty -Name "VMKernel$($i)_Subnet" -Value  $vmknic.Spec.IP.SubnetMask
    				$HostConfig | Add-Member -Type NoteProperty -Name "VMKernel$($i)_GW" -Value  $vmhostView.Config.Network.IpRouteConfig.DefaultGateway # $vmknic.Spec.IP.Gateway
    				if ($vmknic.Device -eq $vmkPort)
                    {
                        $HostConfig | Add-Member -Type NoteProperty -Name "VMKernel$($i)_VMotionEnabled" -Value  "TRUE"
                    } else {
                        $HostConfig | Add-Member -Type NoteProperty -Name "VMKernel$($i)_VMotionEnabled" -Value  "FALSE"
                    }
    				$i++
    			}
    		} 
    	
    		# Services
    		if ($vmhostView.Config.DateTimeInfo.NtpConfig){
    			$i = 1
    			foreach ($ntpsrv in $vmhostView.Config.DateTimeInfo.NtpConfig.Server) {
    				$HostConfig | Add-Member -Type NoteProperty -Name "NTP$i" -Value  $ntpsrv 
    				$i++
    			}
    		}
    		
    		if ($vmhostView.Config.DateTimeInfo.TimeZone) {
                $HostConfig | Add-Member -Type NoteProperty -Name "TimeZoneDescr" -Value  $vmhostView.Config.DateTimeInfo.TimeZone.Description
    			$HostConfig | Add-Member -Type NoteProperty -Name "GmtOffset" -Value  $vmhostView.Config.DateTimeInfo.TimeZone.GmtOffset
    		}
    		if ($vmhostView.Config.Network.DnsConfig.Address) {
    			$i = 1
    			foreach  ($dnssrv in $vmhostView.Config.Network.DnsConfig.Address) {
    				$HostConfig | Add-Member -Type NoteProperty -Name "DNS$i" -Value  $dnssrv 
    				$i++
    			}
    		}
    	
    		if ($vmhostView.Config.Network.DnsConfig.SearchDomain) {
    			$i = 1
    			foreach ($domain in $vmhostView.Config.Network.DnsConfig.SearchDomain) {
    				$HostConfig | Add-Member -Type NoteProperty -Name "SearchDomain$i" -Value  $domain
    				$i++
    			}
    		}
    	
            #Misc Options
            $myAdvcOptions = "Uservars.SuppressShell","Migrate.Enabled","LVM.EnableResignature",
                             "LVM.DisallowSnapshotLun","UserVars.CimEnabled","UserVars.CIMibmippProviderEnabled",
                             "Syslog.Remote.Hostname","Syslog.Remote.Port","VMkernel.Boot.oem", "VMkernel.Boot.usbBoot",
                             "VMkernel.Boot.interleaveFakeNUMAnodes","ScratchConfig.CurrentScratchLocation";
            $myAdvcOptions | %{
                $optionDef = $_;
                $option = $vmhostView.Config.Option | ?{$_.Key -eq $optionDef};
                
                if ($option.value -eq 1 -or $option.value -eq 0)
                {
                    $HostConfig | Add-Member -Type NoteProperty -Name $_ -Value ($option.Value -eq 1)
                } else {
                    $HostConfig | Add-Member -Type NoteProperty -Name $_ -Value $option.Value
                }
            }    		
    	
    		# Physical Nics	
    		$HostConfig | Add-Member -Type NoteProperty -Name "NumNIC_Ports" -Value  $vmhostView.Summary.Hardware.NumNics
    		$arrayPci = @("0")
    		# Class id for NICs is 512
    		foreach ($pcidevice in ($vmhostView.Hardware.PciDevice | ?{$_.ClassId -eq 512})){
    			if ($arrayPci -notcontains $pcidevice.SubDeviceId) {
    				$arrayPci += $pcidevice.SubDeviceId
    			}
    		}
    		$HostConfig | Add-Member -Type NoteProperty -Name "NumNIC_HBAs" -Value  "$([math]::ROUND($arrayPci.Count - 1))"
    		
    	
    		$i = 1
    		foreach($nic in ($vmhostView.Config.Network.Pnic | ?{$_.GetType().Name -eq "PhysicalNic"})) {
    			$HostConfig | Add-Member -Type NoteProperty -Name "NIC$i" -Value $nic.Device
    			$HostConfig | Add-Member -Type NoteProperty -Name "NIC$($i)_Driver" -Value $nic.Driver
    			$HostConfig | Add-Member -Type NoteProperty -Name "NIC$($i)_Mac" -Value $nic.Mac
    			$HostConfig | Add-Member -Type NoteProperty -Name "NIC$($i)_Speed" -Value $nic.LinkSpeed.SpeedMb
    			$HostConfig | Add-Member -Type NoteProperty -Name "NIC$($i)_FullDuplex" -Value $nic.LinkSpeed.Duplex
    			$HostConfig | Add-Member -Type NoteProperty -Name "NIC$($i)_Pci" -Value $nic.Pci
    			$i++
    		}
    	
    		# Custom Attributes
    		if ($vmhostView.AvailableField) {
    			foreach ($field in $vmhostView.AvailableField) {
    				$custField = $vmhostView.CustomValue | ?{$_.Key -eq $field.Key}
    				$HostConfig | Add-Member -Type NoteProperty -Name $field.Name -Value $custField.Value
    			}
    		}
    		
    		# may use custom attributes down 
    		#$HostConfig | Add-Member -Type NoteProperty -Name "RSA_URL" -Value  " "
    		#$HostConfig | Add-Member -Type NoteProperty -Name "RSA_Hostname" -Value  " "
    		#$HostConfig | Add-Member -Type NoteProperty -Name "RSA_IP" -Value  " "
    		#$HostConfig | Add-Member -Type NoteProperty -Name "RSA_Subnet" -Value  " "
    		#$HostConfig | Add-Member -Type NoteProperty -Name "RSA_GW" -Value  " "
    		#$HostConfig | Add-Member -Type NoteProperty -Name "RSA_VLAN" -Value  " "
    		#$HostConfig | Add-Member -Type NoteProperty -Name "RSA_MAC" -Value  " "
    	
    		#$HostConfig | Add-Member -Type NoteProperty -Name "LastTestMemoryOn" -Value  " "	
    		#$HostConfig | Add-Member -Type NoteProperty -Name "PatchGroup" -Value  " "
    		#$HostConfig | Add-Member -Type NoteProperty -Name "Critical" -Value  " "
    		$HostConfig | Add-Member -Type NoteProperty -Name "MMS_SupportTeam" -Value  $TechContact

    		if ($verbose)
            {
                Write-Host $HostConfig | fl
            }
    		$HostConfig
            $hostCount++;
    }
}
if ($formatList)
{
    $run1Report | format-list > $of
} else {
    # Fix the object array, ensure all objects within the 
    # array contain the same members (required for Format-Table / Export-CSV)
     
    $Members = $run1Report | Select-Object `
      @{n='MemberCount';e={ ($_ | Get-Member).Count }}, `
      @{n='Members';e={ $_.PsObject.Properties | %{ $_.Name } }}
    $AllMembers = ($Members | Sort-Object MemberCount -Descending)[0].Members

    #ForEach ($Entry in $run1Report) {
      #ForEach ($Member in $AllMembers)
      #{
        #If (!($Entry | Get-Member -Name $Member))
        #{ 
          #$Entry | Add-Member -Type NoteProperty -Name $Member -Value ""
        #}
      #}
    #}

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
     Write-Output $Report | Export-Csv $of -NoTypeInformation
     Write-Output "" >> $of
     Write-Output "" >> $of
     Write-Output "Collected on $(get-date)" >> $of
} 

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}