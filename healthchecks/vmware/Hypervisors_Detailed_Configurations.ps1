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
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$verbose=$false,[bool]$showErrors=$true,[bool]$launchReport=$false)
logThis -msg "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global




# Want to initialise the module and blurb using this 1 function



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
$now = Get-date

$run1Report = $srvConnection | %{
        $vCenterServer = $_.Name;
        logThis -msg "Processing vCenter ""$vCenterServer""..." -ForegroundColor Cyan
		logThis -msg "-> Getting View on the licencing server in this vCenter" -foregroundcolor yellow
		#Get-View $_.ExtensionData.Content.LicenseManager
		$lm = Get-view $_.ExtensionData.Content.LicenseManager
		logThis -msg "-> Enumerating VMHosts" -foregroundcolor yellow
        $vmhosts = Get-VMHost -Server $_ | sort Name #| Get-View
		
        logThis -msg "Found $($vmhosts.Count)" -ForegroundColor Yellow
        $hostCount = 1;
		
        $vmhosts | %{
            logThis -msg "`t-> $hostCount/$($vmhosts.Count) - $($vmhost.Name)..."
    		$vmhost = $_		
    		$HostConfig = "" | Select-Object "VMhost";

			$clusterName =""
			
			if ($vmhost.ExtensionData.Parent.Type -eq "ClusterComputeResource")
			{
				logThis -msg "`t`t-> Host Belongs to a cluster. Getting CLuster information"
    			$cluster = Get-Cluster -VMHost $vmhost				
				$clusterEVCMode = "unset"
				if ($cluster)
				{
					$clusterName = $cluster.Name
					if ($cluster.ExtensionData.Summary.CurrentEVCModeKey)
					{
						$clusterEVCMode = $cluster.ExtensionData.Summary.CurrentEVCModeKey
					}
				}
			}
			logThis -msg "`t`t-> Getting Datacenter"
			$datacenter = Get-Datacenter -VMHost $vmhost
			
			logThis -msg "`t`t-> Getting ESXCLI handle to the host for further queries"
			$esxcli = Get-ESXCli -VMhost $vmhost
			
			$HostConfig.VMHost = $vmhost.ExtensionData.Config.Network.DnsConfig.HostName
			$HostConfig | Add-Member -Type NoteProperty -Name "Cluster" -Value $clusterName
			
    		
    		$HostConfig | Add-Member -Type NoteProperty -Name "FQDN" -Value  $vmhost.Name
            $HostConfig | Add-Member -Type NoteProperty -Name "BootTime" -Value  $vmhost.ExtensionData.Summary.Runtime.BootTime
            $HostConfig | Add-Member -Type NoteProperty -Name "InMaintenanceMode" -Value  $vmhost.ExtensionData.Summary.Runtime.InMaintenanceMode
            $HostConfig | Add-Member -Type NoteProperty -Name "ConnectionState" -Value  $vmhost.ExtensionData.Summary.Runtime.ConnectionState
            $HostConfig | Add-Member -Type NoteProperty -Name "Health" -Value  $vmhost.ExtensionData.Summary.OverallStatus
            $HostConfig | Add-Member -Type NoteProperty -Name "VMotionEnabled" -Value  $vmhost.ExtensionData.Summary.Config.VmotionEnabled
            
			if ($showErrors)
			{
	            # Determine the error count for the last 7 days
				logThis -msg "`t`t-> Collecting Errors for the last 7 days"
	            $last7DaysErrors = $vmhost | Get-VIEvent -Type error -Start $now.AddDays(-7) -Finish $now -MaxSamples 999999
	            $hostErrors = 0;
	            if ($last7DaysErrors.Count -gt 0)
	            {
	                $hostErrors = $last7DaysErrors.Count
	            }
	            $HostConfig | Add-Member -Type NoteProperty -Name "ErrorsCountLast7Days" -Value  $hostErrors
	            
				logThis -msg "`t`t-> Collecting Errors for the last 30 days"
	            # Determine the error count for the last 30 days
	            $last30DaysErrors = $vmhost | Get-VIEvent -Type error -Start $now.AddDays(-30) -Finish $now -MaxSamples 999999
	            $hostErrors = 0;
	            if ($last30DaysErrors.Count -gt 0)
	            {
	                $hostErrors = $last30DaysErrors.Count
	            }
	            
	            $HostConfig | Add-Member -Type NoteProperty -Name "ErrorsCountLast30Days" -Value  $hostErrors
            }
            $HostConfig | Add-Member -Type NoteProperty -Name "RequiresReboot" -Value  $vmhost.ExtensionData.Summary.RebootRequired
    		$HostConfig | Add-Member -Type NoteProperty -Name "ProductName" -Value  $vmhost.ExtensionData.Config.Product.Name
    		$HostConfig | Add-Member -Type NoteProperty -Name "ProductVersion" -Value  $vmhost.ExtensionData.Config.Product.Version
    		$HostConfig | Add-Member -Type NoteProperty -Name "ProductBuild" -Value  $vmhost.ExtensionData.Config.Product.Build
    		$HostConfig | Add-Member -Type NoteProperty -Name "HardwareVendor" -Value  $vmhost.ExtensionData.Hardware.SystemInfo.Vendor
    		$HostConfig | Add-Member -Type NoteProperty -Name "Model" -Value  $vmhost.ExtensionData.Hardware.SystemInfo.Model
			$HostConfig | Add-Member -Type NoteProperty -Name "Licence key" -Value  $vmhost.LicenseKey
			
			logThis -msg "`t`t-> Collecting Licencing Informatoin"
			$licenceName = "Unknown"
			$licenceName = $($lm.Licenses | ?{$_.LicenseKey -eq $vmhost.LicenseKey}).Name
			
			$HostConfig | Add-Member -Type NoteProperty -Name "Licence" -Value  $licenceName
			
			logThis -msg "`t`t-> Exporting Other Hardware Indentifier Types"
            if ($vmhost.ExtensionData.Summary.Hardware.OtherIdentifyingInfo)
            {
				# | Select-Object -ExpandProperty "OtherIdentifyingInfo" 
				$index=0
                $vmhost.ExtensionData.Summary.Hardware.OtherIdentifyingInfo | %{
                    $HostConfig | Add-Member -Type NoteProperty -Name "$($_.IdentifierType.Label)_$($index)" -Value  "$($_.IdentifierValue)"
					$index++;
                }
            }
            $HostConfig | Add-Member -Type NoteProperty -Name "VMAutoStart" -Value $vmhost.ExtensionData.Config.AutoStart.Defaults.Enabled
			$HostConfig | Add-Member -Type NoteProperty -Name "SNMP Enabled" -Value $($esxcli.system.snmp.get()).enable
    		$HostConfig | Add-Member -Type NoteProperty -Name "BiosVersion" -Value  $vmhost.ExtensionData.Hardware.BiosInfo.BiosVersion
    		$HostConfig | Add-Member -Type NoteProperty -Name "BIOSReleaseDate" -Value $vmhost.ExtensionData.Hardware.BiosInfo.ReleaseDate 
    		$HostConfig | Add-Member -Type NoteProperty -Name "vCenter" -Value  $vCenterServer
            $HostConfig | Add-Member -Type NoteProperty -Name "Datacenter" -Value  $datacenter.Name
    		$HostConfig | Add-Member -Type NoteProperty -Name "CPUType" -Value  $vmhost.ExtensionData.Hardware.CpuPkg[0].Description
    		$HostConfig | Add-Member -Type NoteProperty -Name "CPUSockets" -Value  $vmhost.ExtensionData.Hardware.CpuInfo.NumCpuPackages
    		$HostConfig | Add-Member -Type NoteProperty -Name "CPUCores" -Value  $vmhost.ExtensionData.Hardware.CpuInfo.NumCpuCores
    		$HostConfig | Add-Member -Type NoteProperty -Name "CoreSpeedMhz" -Value  "$([math]::ROUND($vmhost.ExtensionData.Hardware.CpuInfo.Hz / 1Mb))"
    		$HostConfig | Add-Member -Type NoteProperty -Name "TotalCPUMhz" -Value  "$([math]::ROUND(($vmhost.ExtensionData.Hardware.CpuInfo.NumCpuCores * $vmhostHardware.CpuInfo.Hz) / 1Mb))"
    		$HostConfig | Add-Member -Type NoteProperty -Name "HyperThreadingAvailable" -Value  $vmhost.ExtensionData.Config.HyperThread.Available
    		$HostConfig | Add-Member -Type NoteProperty -Name "HyperThreadingActive" -Value  $vmhost.ExtensionData.Config.HyperThread.Active
            $HostConfig | Add-Member -Type NoteProperty -Name "NUMA architectures" -Value  $vmhost.ExtensionData.Hardware.NumaInfo.Type
            $HostConfig | Add-Member -Type NoteProperty -Name "NUMA Packages" -Value  $vmhost.ExtensionData.Hardware.NumaInfo.NumNodes
            $HostConfig | Add-Member -Type NoteProperty -Name "EVCModeSupported" -Value  $vmhost.ExtensionData.Summary.MaxEVCModeKey
			$HostConfig | Add-Member -Type NoteProperty -Name "ClusterEVCMode" -Value  $clusterEVCMode
    		$HostConfig | Add-Member -Type NoteProperty -Name "MemoryMB" -Value  "$([math]::ROUND($vmhost.ExtensionData.Hardware.MemorySize/1Mb))"
    		$HostConfig | Add-Member -Type NoteProperty -Name "PXE_Off" -Value  " "
    		$HostConfig | Add-Member -Type NoteProperty -Name "MPSFullTable" -Value  " "
    		$HostConfig | Add-Member -Type NoteProperty -Name "CPU_NX" -Value  " "
    		$HostConfig | Add-Member -Type NoteProperty -Name "VT_Enabled" -Value  " "
            $HostConfig | Add-Member -Type NoteProperty -Name "VMs" -Value  $vmhost.ExtensionData.Vm.Count
            $HostConfig | Add-Member -Type NoteProperty -Name "Datastores" -Value  $vmhost.ExtensionData.Datastore.Count
    		$HostConfig | Add-Member -Type NoteProperty -Name "ScsiLuns" -Value $vmhost.ExtensionData.Config.StorageDevice.ScsiLun.Count
			$HostConfig | Add-Member -Type NoteProperty -Name "Distributed vSwitches" -Value ($esxcli.network.vswitch.dvs.vmware.list()).Count
			$HostConfig | Add-Member -Type NoteProperty -Name "Standard vSwitches" -Value ($esxcli.network.vswitch.standard.list()).Count
            $HostConfig | Add-Member -Type NoteProperty -Name "TotalScsiPaths" -Value $vmhost.ExtensionData.Config.MultipathState.Path.Count
            $HostConfig | Add-Member -Type NoteProperty -Name "ActiveScsiPaths" -Value $($vmhost.ExtensionData.Config.MultipathState.Path | ?{$_.PathState -eq"active"}).Count
			$HostConfig | Add-Member -Type NoteProperty -Name "NFS Volumes" -Value $($esxcli.storage.nfs.list()).Count
			$HostConfig | Add-Member -Type NoteProperty -Name "ISCSI Devices" -Value $($esxcli.storage.san.iscsi.list()).Count
            
    		# LocalHBA - Working except Firmwares
			logThis -msg "`t`t-> Exporting Local HBA Details"
    		$i = 1
    		foreach($hba in ($vmhost.ExtensionData.config.storagedevice.hostbusadapter | ?{$_.GetType().Name -eq "HostBlockHba"})) {
    			$HostConfig | Add-Member -Type NoteProperty -Name "Controller$($i)" -Value  $hba.Model
				$HostConfig | Add-Member -Type NoteProperty -Name "Controller$($i)_Speed" -Value  $hba.Speed
    			$HostConfig | Add-Member -Type NoteProperty -Name "Controller$($i)_Device" -Value  $hba.Device
    			#$HostConfig | Add-Member -Type NoteProperty -Name "Controller$($i)_Firmware" -Value  " "
    			$HostConfig | Add-Member -Type NoteProperty -Name "Controller$($i)_Driver" -Value  $hba.Driver
    			$i++;
    		}
    	
    		#FC HBA - Working except Firmwares
    		
    		
    		# HBAs	
    		$arrayPci = @("0")
    		# Class id for FC HBA is 3076
    		foreach ($pcidevice in ($vmhost.ExtensionData.Hardware.PciDevice | ?{$_.ClassId -eq 3076})){
    			if ($arrayPci -notcontains $pcidevice.SubDeviceId) {
    				$arrayPci += $pcidevice.SubDeviceId
    			}
    		}
    		
			#$HostConfig | Add-Member -Type NoteProperty -Name "NumFC_HBAs" -Value  "$([math]::ROUND($arrayPci.Count - 1))"
    		#$HostConfig | Add-Member -Type NoteProperty -Name "NumNIC_HBAs" -Value  $arrayPci.Count
    		
			# Get Fibre channel devices
			logThis -msg "`t`t-> Collecting Fibre Channel Devices"
    		$i = 1
			$hbas = $esxcli.storage.san.fc.list()
			$HostConfig | Add-Member -Type NoteProperty -Name "Fibre Ports" -Value $hbas.Count
			#$HostConfig | Add-Member -Type NoteProperty -Name "NumFC-Ports" -Value  ($vmhost.ExtensionData.config.storagedevice.hostbusadapter | ?{$_.GetType().Name -eq "HostFibreChannelHba"}).Count
			$hbas | %{
				$hbaDevice = $_
				$hbaDevice | Get-Member -Type CodeProperty | select Name | %{
					$headerName = $_.Name
					$HostConfig | Add-Member -Type NoteProperty -Name "FCHBA$($i)_$headerName" -Value  $hbaDevice.$headerName
					#Write-Host "FCHBA$($i)_$($headerName)" #$hbaDevice.$headerName
					#Write-Host $hbaDevice.$headerName
				}
				$i++;
			}
			logThis -msg "`t`t-> Collecting NIC Devices"
			# Get Network card
    		$i = 1
			$hbas = $esxcli.network.nic.list()
			$hbas | %{
				$hbaDevice = $_
				$hbaDevice | Get-Member -Type CodeProperty | select Name | %{
					$headerName = $_.Name
					$HostConfig | Add-Member -Type NoteProperty -Name "NIC$($i)_$headerName" -Value  $hbaDevice.$headerName
					#Write-Host "NIC$($i)_$($headerName)" #$hbaDevice.$headerName
				}
				$i++;
			}
			
			
			
    		# Service Consoles
			
    		if ($vmhost.ExtensionData.Config.Network.ConsoleVnic)
			{
				logThis -msg "`t`t-> Exporting Service Console if necessary (Old ESX Versions)"
    			$i=1
    			logThis -msg "`t`tHost has $($vmhost.ExtensionData.Config.Network.ConsoleVnic).Count) Services Consoles..."
    			foreach ($cos in $vmhost.ExtensionData.Config.Network.ConsoleVnic) {

    				$HostConfig | Add-Member -Type NoteProperty -Name "COS$($i)_Device" -Value  $cos.Device 
    				$HostConfig | Add-Member -Type NoteProperty -Name "COS$($i)_PortGroup" -Value  $cos.Portgroup
    				$HostConfig | Add-Member -Type NoteProperty -Name "COS$($i)_IP" -Value  $cos.Spec.IP.IpAddress 
    				$HostConfig | Add-Member -Type NoteProperty -Name "COS$($i)_Subnet" -Value  $cos.Spec.IP.SubnetMask
    				$HostConfig | Add-Member -Type NoteProperty -Name "COS$($i)_GW" -Value  $vmhost.ExtensionData.Config.Network.ConsoleIpRouteConfig.DefaultGateway
    				$HostConfig | Add-Member -Type NoteProperty -Name "COS$($i)_MemoryMB" -Value  "$([math]::ROUND($vmhost.ExtensionData.Config.ConsoleReservation.ServiceConsoleReserved / 1Mb))"
    				
    				$portGroup = Get-VirtualPortGroup -VMHost $vmhost.Name -Name $cos.Portgroup
    				$HostConfig | Add-Member -Type NoteProperty -Name "COS$($i)_VLAN" -Value  $portGroup.VlanId
    				$HostConfig | Add-Member -Type NoteProperty -Name "COS$($i)_vSwitch" -Value  $portGroup.VirtualSwitchName
    				$HostConfig | Add-Member -Type NoteProperty -Name "COS$($i)_MAC" -Value  $cos.Spec.Mac
    				$i++
    			}
    		}
    	
    		#Vmkernel Ports
			
            if ($vmhost.ExtensionData.Summary.Config.VmotionEnabled)
            {
				logThis -msg "`t`t-> Checking if VMotion is enabled"
                $nicType,$vimType,$vmkPort = $($($vmhost.ExtensionData.Config.VirtualNicManagerInfo.NetConfig | ?{$_.NicType -eq "vmotion"}).SelectedVnic).Split("-") # example vmotion.key-vim.host.VirtualNic-vmk1
            }
            
    		if ($vmhost.ExtensionData.Config.Network.Vnic)
			{
				logThis -msg "`t`t-> Exporting VMkernel NIC Details"
    			$i = 1
    			#logThis -msg "`t`tHost has " ($vmhost.ExtensionData.Config.Network.Vnic).Count " VMKernel ports..."
    			foreach ($vmknic in $vmhost.ExtensionData.Config.Network.Vnic | sort Device ) {
    				$HostConfig | Add-Member -Type NoteProperty -Name "VMKernel$($i)" -Value  $vmknic.Portgroup
    				$HostConfig | Add-Member -Type NoteProperty -Name "VMKernel$($i)_Device" -Value  $vmknic.Device
    				
    				$portGroup = Get-VirtualPortGroup  -VMHost $vmhost.Name -Name $vmknic.Portgroup
    				$HostConfig | Add-Member -Type NoteProperty -Name "VMKernel$($i)_VLAN" -Value  $portGroup.VLanId
    				#$HostConfig | Add-Member -Type NoteProperty -Name "VMKernel$($1)_MAC" -Value  $vmknic.Spec.Mac
    				$HostConfig | Add-Member -Type NoteProperty -Name "VMKernel$($i)_vSwitch" -Value  $portGroup.VirtualSwitchName
    				$HostConfig | Add-Member -Type NoteProperty -Name "VMKernel$($i)_IP" -Value  $vmknic.Spec.IP.IpAddress
    				$HostConfig | Add-Member -Type NoteProperty -Name "VMKernel$($i)_Subnet" -Value  $vmknic.Spec.IP.SubnetMask
    				$HostConfig | Add-Member -Type NoteProperty -Name "VMKernel$($i)_GW" -Value  $vmhost.ExtensionData.Config.Network.IpRouteConfig.DefaultGateway # $vmknic.Spec.IP.Gateway
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
			logThis -msg "`t`t-> Exporting NTP Services config"
    		if ($vmhost.ExtensionData.Config.DateTimeInfo.NtpConfig){
    			$i = 1
    			foreach ($ntpsrv in $vmhost.ExtensionData.Config.DateTimeInfo.NtpConfig.Server) {
    				$HostConfig | Add-Member -Type NoteProperty -Name "NTP$i" -Value  $ntpsrv 
    				$i++
    			}
    		}
    		logThis -msg "`t`t-> Date + TimeZone info"
    		if ($vmhost.ExtensionData.Config.DateTimeInfo.TimeZone) {
                $HostConfig | Add-Member -Type NoteProperty -Name "TimeZoneDescr" -Value  $vmhost.ExtensionData.Config.DateTimeInfo.TimeZone.Description
    			$HostConfig | Add-Member -Type NoteProperty -Name "GmtOffset" -Value  $vmhost.ExtensionData.Config.DateTimeInfo.TimeZone.GmtOffset
    		}
			logThis -msg "`t`t-> Exporting DNS Config Addresses"
    		if ($vmhost.ExtensionData.Config.Network.DnsConfig.Address) {
    			$i = 1
    			foreach  ($dnssrv in $vmhost.ExtensionData.Config.Network.DnsConfig.Address) {
    				$HostConfig | Add-Member -Type NoteProperty -Name "DNS$i" -Value  $dnssrv 
    				$i++
    			}
    		}
    		logThis -msg "`t`t-> Exporting DNS Config Search Domains"
    		if ($vmhost.ExtensionData.Config.Network.DnsConfig.SearchDomain) {
    			$i = 1
    			foreach ($domain in $vmhost.ExtensionData.Config.Network.DnsConfig.SearchDomain) {
    				$HostConfig | Add-Member -Type NoteProperty -Name "SearchDomain$i" -Value  $domain
    				$i++
    			}
    		}
    	
            #Misc Options
			logThis -msg "`t`t-> Exporting Advanced Options"
            $myAdvcOptions = "Uservars.SuppressShell","Migrate.Enabled","LVM.EnableResignature",
                             "LVM.DisallowSnapshotLun","UserVars.CimEnabled","UserVars.CIMibmippProviderEnabled",
                             "Syslog.Remote.Hostname","Syslog.Remote.Port","VMkernel.Boot.oem", "VMkernel.Boot.usbBoot",
                             "VMkernel.Boot.interleaveFakeNUMAnodes","ScratchConfig.CurrentScratchLocation";
            $myAdvcOptions | %{
                $optionDef = $_;
                $option = $vmhost.ExtensionData.Config.Option | ?{$_.Key -eq $optionDef};
                
                if ($option.value -eq 1 -or $option.value -eq 0)
                {
                    $HostConfig | Add-Member -Type NoteProperty -Name $_ -Value ($option.Value -eq 1)
                } else {
                    $HostConfig | Add-Member -Type NoteProperty -Name $_ -Value $option.Value
                }
            }    		
    	
    		# Physical Nics	
    		#$HostConfig | Add-Member -Type NoteProperty -Name "NumNIC_Ports" -Value  $vmhost.ExtensionData.Summary.Hardware.NumNics
    		#$arrayPci = @("0")
    		# Class id for NICs is 512
    		#foreach ($pcidevice in ($vmhost.ExtensionData.Hardware.PciDevice | ?{$_.ClassId -eq 512})){
    		#	if ($arrayPci -notcontains $pcidevice.SubDeviceId) {
    		#		$arrayPci += $pcidevice.SubDeviceId
    		#	}
    		#}
    		#$HostConfig | Add-Member -Type NoteProperty -Name "NumNIC_HBAs" -Value  "$([math]::ROUND($arrayPci.Count - 1))"
    		#$i = 1
    		#foreach($nic in ($vmhost.ExtensionData.Config.Network.Pnic | ?{$_.GetType().Name -eq "PhysicalNic"})) {
    		#	$HostConfig | Add-Member -Type NoteProperty -Name "NIC$i" -Value $nic.Device
    		#	$HostConfig | Add-Member -Type NoteProperty -Name "NIC$($i)_Driver" -Value $nic.Driver
    		#	$HostConfig | Add-Member -Type NoteProperty -Name "NIC$($i)_Mac" -Value $nic.Mac
    		#	$HostConfig | Add-Member -Type NoteProperty -Name "NIC$($i)_Speed" -Value $nic.LinkSpeed.SpeedMb
    		#	$HostConfig | Add-Member -Type NoteProperty -Name "NIC$($i)_FullDuplex" -Value $nic.LinkSpeed.Duplex
    		#	$HostConfig | Add-Member -Type NoteProperty -Name "NIC$($i)_Pci" -Value $nic.Pci
    		#	$i++
    		#}
    	
    		logThis -msg "`t`t-> Exporting Custom Attributes"
    		if ($vmhost.ExtensionData.AvailableField) {
    			foreach ($field in $vmhost.ExtensionData.AvailableField) {
    				$custField = $vmhost.ExtensionData.CustomValue | ?{$_.Key -eq $field.Key}
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
                logThis -msg $HostConfig
            }
    		$HostConfig
            $hostCount++;
			Remove-Variable HostConfig
			Remove-Variable datacenter
			Remove-Variable cluster
    }
}

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

ExportCSV -table $Report
if ($launchReport)
{
	launchReport
}

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}