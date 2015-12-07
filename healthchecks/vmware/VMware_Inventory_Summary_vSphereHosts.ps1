# Scans the VMware Infrastructure and documents hardware and software configurations 
# of Virtual Center Server and esx/esxi systems
#Version : 0.8
#Last Updated : 12th Feb 2010, teiva.rodiere-at-gmail.com
#Author : teiva.rodiere-at-gmail.com 
#Inputs: vcenter server name, username, and password
#Version : 0.6
#Author :12/11/2011, by teiva.rodiere-at-gmail.com
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$verbose=$false,[bool]$formatList=$false)
logThis -msg "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global
$global:logfile
$global:outputCSV

# Want to initialise the module and blurb using this 1 function
#InitialiseModule


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
        logThis -msg "Processing VMHosts from vCenter server ""$vCenterServer""..." -ForegroundColor Cyan
        $vmhosts = Get-VMHost -Server $_ | sort Name | Get-View
        logThis -msg "Found $($vmhosts.Count)" -ForegroundColor Yellow
        $cluster = Get-Datacenter -VMHost $vmhosts[0].Name
        $hostCount = 1;
        $vmhosts | %{
            logThis -msg "Processing $hostCount/$($vmhosts.Count) - $($vmhost.Name)..."
    		$vmhost = $_		
    		$HostConfig = "" | Select-Object "VMhost";
    		
    		$clusterName = Get-Cluster -VMHost $vmhost.Name
    		$HostConfig.VMHost =$vmhost.Name
    		
    		#$HostConfig | Add-Member -Type NoteProperty -Name "FQDN" -Value  $vmhost.Name
            #$HostConfig | Add-Member -Type NoteProperty -Name "Hypervisor" -Value  $($vmhost.Config.Product.Name +" "+$vmhost.Config.Product.Version+"-"+$vmhost.Config.Product.Build)
            #$HostConfig | Add-Member -Type NoteProperty -Name "Hardware" -Value  $($vmhost.Hardware.SystemInfo.Vendor + " " +$vmhost.Hardware.SystemInfo.Model);
    		$HostConfig | Add-Member -Type NoteProperty -Name "CPUSockets" -Value  $vmhost.Hardware.CpuInfo.NumCpuPackages
    		$HostConfig | Add-Member -Type NoteProperty -Name "CPUCores" -Value  $vmhost.Hardware.CpuInfo.NumCpuCores
    		$HostConfig | Add-Member -Type NoteProperty -Name "MemoryMB" -Value  "$([math]::ROUND($vmhost.Hardware.MemorySize/1Mb))"
            $HostConfig | Add-Member -Type NoteProperty -Name "Datastores" -Value  $vmhost.Datastore.Count
            $HostConfig | Add-Member -Type NoteProperty -Name "VMs" -Value  $vmhost.VM.Count
            $HostConfig | Add-Member -Type NoteProperty -Name "Datacenter" -Value $cluster
            
    		if ($verbose)
            {
                logThis -msg $HostConfig
            }
    		$HostConfig
            $hostCount++;
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
if ($formatList)
{
    $Report | format-list
    Write-Output $Report | format-list | Export-Csv $of -NoTypeInformation
    
} else {
   ExportCSV -table  $Report 
}

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}