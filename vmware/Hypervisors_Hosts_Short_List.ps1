# Enumerates a list of Hypervisors with a few information about each 
# Version : 1.2
# Last updated: 23 March 2015
#Author : teiva.rodiere@gmail.com
param(
	[object]$srvConnection="",
	[string]$logDir="output",
	[string]$comment="",
	[bool]$verbose=$false,
	[int]$headerType=1,
	[bool]$returnResults=$true
)
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru -Verbose $false
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global

# Want to initialise the module and blurb using this 1 function
InitialiseModule

$metaInfo = @()
$metaInfo +="tableHeader=Hypervisor List"
$metaInfo +="introduction=The table below provides a concise list of your current Hypervisor servers."
$metaInfo +="titleHeaderType=h$($headerType)"
$metaInfo +="displayTableOrientation=Table" # options are List or Table
$metaInfo +="chartable=false"

#Variables and Constants
$TechContact="INF-VMWARE"
#$choice_VC_CustomAttributes="Veeam_ems_node,Veeam_segment"
$choice_BIOS_CPU_NXFlag="Enabled/Disabled" #Enabled/Disabled
$choice_BIOS_CPU_VTFlag="Enabled/Disabled" #Enabled/Disabled
$choice_BIOS_PXEOff="Yes/No" #Yes/No
$choice_BIOS_CPU_MPSFullTableApic="On/Off" #On/Off
$choice_NPIV="Yes/No"
$choice_PatchGroups="1/2/3/4"
$choice_Memtested="Yes/No"
$defaults_NA="[N/A]"

$dataTable = $srvConnection | %{
    $vCenterServer = $_;	
    logThis -msg "Processing VMHosts from vCenter server ""$($vCenterServer.Name)""..." -ForegroundColor Cyan
    $vmhosts = Get-VMHost -Server $vCenterServer | sort Name #| Get-View
    logThis -msg "Found $($vmhosts.Count)" -ForegroundColor Yellow
	logThis -msg "-> Getting the licence manager to check the host Licence types" -ForegroundColor Yellow
	$lm = Get-view $vCenterServer.ExtensionData.Content.LicenseManager | Select -First 1
    $hostCount = 1;
    $vmhosts | sort -Property Name | %{
    	$vmhost = $_
        logThis -msg "Processing $hostCount/$($vmhosts.Count) - $($vmhost.Name)..."
		$datacenter= Get-Datacenter -VMHost $vmhost
		$cluster=get-cluster -VMhost $vmhost

		$row = "" | Select-Object "VMhost";

		$row.VMHost =$vmhost.Name
		
		#$row | Add-Member -Type NoteProperty -Name "FQDN" -Value  $vmhost.Name
        $row | Add-Member -Type NoteProperty -Name "Hypervisor" -Value  $($vmhost.ExtensionData.Config.Product.Name +" "+$vmhost.ExtensionData.Config.Product.Version+"-"+$vmhost.ExtensionData.Config.Product.Build)
		$licenceName = "Unknown"
		$licenceName = $($lm.Licenses | ?{$_.LicenseKey -eq $vmhost.LicenseKey}).Name
		$row | Add-Member -Type NoteProperty -Name "Licence" -Value  $licenceName
        $row | Add-Member -Type NoteProperty -Name "Hardware" -Value  $($vmhost.ExtensionData.Hardware.SystemInfo.Vendor + " " +$vmhost.ExtensionData.Hardware.SystemInfo.Model);
	    $row | Add-Member -Type NoteProperty -Name "CPUs" -Value  "$($([string]($vmhost.ExtensionData.Hardware.CpuPkg | select Description -Unique).Description).Replace('          ',''))"
		$row | Add-Member -Type NoteProperty -Name "CPUSockets" -Value  $vmhost.ExtensionData.Hardware.CpuInfo.NumCpuPackages
		$row | Add-Member -Type NoteProperty -Name "CPUCores" -Value  $vmhost.ExtensionData.Hardware.CpuInfo.NumCpuCores
		$row | Add-Member -Type NoteProperty -Name "MemoryMB" -Value  "$([math]::ROUND($vmhost.ExtensionData.Hardware.MemorySize/1Mb))"
        $row | Add-Member -Type NoteProperty -Name "Datastores" -Value  $vmhost.ExtensionData.Datastore.Count            
        $row | Add-Member -Type NoteProperty -Name "Cluster" -Value $cluster.name
		$row | Add-Member -Type NoteProperty -Name "Datacenter" -Value $datacenter.Name

   		if ($verbose)
            {
                logThis -msg $row
            }
	    logThis -msg $row
    	$row
        $hostCount++;
    }
}

if ($dataTable)
{
	#$dataTable $dataTable
	if ($metaAnalytics)
	{
		$metaInfo += "analytics="+$metaAnalytics
	}	
	if ($returnResults)
	{
		return $dataTable,$metaInfo,(getRuntimeLogFileContent)
	} else {
		ExportCSV -table $dataTable
		ExportMetaData -meta $metaInfo
	}
}

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}