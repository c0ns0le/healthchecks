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
    		$HostConfig = "" | Select-Object "Name";

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
			logThis -msg "`t`t-> Getting ESXCLI handle to the host for further queries"
			$esxcli = Get-ESXCli -VMhost $vmhost
			
			$HostConfig.Name = $vmhost.ExtensionData.Config.Network.DnsConfig.HostName
			#$HostConfig | Add-Member -Type NoteProperty -Name "Cluster" -Value $clusterName
			
    		
          
    		#$HostConfig | Add-Member -Type NoteProperty -Name "Build" -Value  
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
		$hbas = ($esxcli.storage.san.fc.list()).Adapter
		$HostConfig | Add-Member -Type NoteProperty -Name "HBA Port Count" -Value $hbas.Count
		
		  $HostConfig | Add-Member -Type NoteProperty -Name "State" -Value  $vmhost.ExtensionData.Summary.Runtime.ConnectionState
            
    		$HostConfig | Add-Member -Type NoteProperty -Name "OS" -Value  $vmhost.ExtensionData.Config.Product.Name
    		$HostConfig | Add-Member -Type NoteProperty -Name "Version" -Value  "$($vmhost.ExtensionData.Config.Product.Version) - $($vmhost.ExtensionData.Config.Product.Build)"
		
		
		#$HostConfig | Add-Member -Type NoteProperty -Name "NumFC-Ports" -Value  ($vmhost.ExtensionData.config.storagedevice.hostbusadapter | ?{$_.GetType().Name -eq "HostFibreChannelHba"}).Count
		$fcHbaAdapters = $hbas | %{
			$hba=$_
			$vmhost.ExtensionData.config.storagedevice.hostbusadapter | ?{$_.Device -eq $hba}
		}
		
		$HostConfig | Add-Member -Type NoteProperty -Name "Adapter Types" -Value ($fcHbaAdapters.Model | select -Unique)
		$HostConfig | Add-Member -Type NoteProperty -Name "Driver" -Value ($fcHbaAdapters.Driver | select -Unique)
		
		$kernelModules=$esxcli.software.vib.get()
		$drivers=($fcHbaAdapters.Driver | select -Unique) | %{
			$modulename=$_
			"$(($kernelModules | ?{$_.Name -eq $modulename}).Version | select -Unique)"
		}
		$HostConfig | Add-Member -Type NoteProperty -Name "Driver Versions" -Value ($drivers | select -Unique)
		
    		$HostConfig
           $hostCount++;
		Remove-Variable HostConfig
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