# Group Virtual Machines by vFolder and provides a table summary
#Version : 1.0
#Updated : 23 March 2015
#Author  : teiva.rodiere@gmail.com
param(
	[object]$srvConnection="",
	[string]$logDir="output",
	[string]$comment="",
	[bool]$verbose=$false,
	[int]$headerType=1,
	[bool]$returnResults=$true,
	[bool]$showDate=$false,
	[bool]$showExtra=$true,
	[string]$startinFolder="rootFolder"
)
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru -Verbose $false
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global
InitialiseModule

#[string]$configFile=".\customerEnvironmentSettings-ALL.ini",

# Report Meta Data
$metaInfo = @()
$metaInfo +="tableHeader=By Virtual Machine & Template Folders"
$metaInfo +="introduction=The table below groups Virtual Machines based on the Folder structure in the vCenter Inventory. Those folders are useful for grouping Virtual Machines based on many criterias, particularly on their production status and application tiering."
$metaInfo +="chartable=false"
$metaInfo +="titleHeaderType=h$($headerType)"

# Folders needed to be listed in v0.1
#$folders = @("Production","Disaster Recovery","Test And Development")

# Get the list of root folders
logThis -msg "-> Getting List of folders from [$srvConnection\$startinFolder] (see ""Virtual Machine and Templates"" panel view)"
$defaultFolder="rootFolder"
LogThis -msg $srvConnection
if ($startinFolder -eq $defaultFolder)
{
	$folders = Get-Folder -Server $srvConnection -Type "VM" | ?{$_.Parent -like "vm"} | select -Property Name -unique
	logThis -msg  "   --> Getting list of VMs from [$startinFolder]"
	#$allVms = Get-VM -Server $vCenter
	#$allVms | Add-Member -Type NoteProperty -Name "Environment" -Value $vcenterName;
} else {
	#Get-folder -Server $srvConnection -Type "VM"
	$folders = Get-folder -Server $srvConnection -Type "VM" | ?{(Get-view $_.ExtensionData.Parent).Name -eq $startinFolder} | select -Property Name -unique
	logThis -msg  "   --> Getting list of VMs from [$startinFolder]"
	#$allVms = Get-VM -Server $vCenter -Location $startinFolder
	#$allVms | Add-Member -Type NoteProperty -Name "Environment" -Value $vcenterName;
}

if($showExtra)
{
	logThis -msg  "   -> Building a list of OS Types from the results"
	$OSTypes=$allVms | %{$_.ExtensionData.Summary.Config.GuestFullName} | select -unique
	logThis -msg  "   -> Building a list of available VM Versions"
	$vmVersions = $allVms | %{$_.Version} | select -unique
}


$Report = $folders | %{ 
	$folder = $_
	logThis -msg  "Processing VMs in folder ""$folder""";
	#$vms = $allVms | ?{$_.Folder.Name -like $folder}
	$vms = Get-VM -Server $srvConnection -Location $folder.Name
	$obj = "" | Select-Object "Location";
	$obj.Location = $folder.Name;
	$vmCount=0 
	$ramCountGB=0
	$vCpuCount=0
	$poweredOnCount = 0
	$otherStatesCount=0
	$poweredOffCount=0
	
	if ($vms)
	{
		if ($vms.GetType().IsArray)
		{
			$vmCount = $vms.Count
		} else {
			$vmCount = 1
		}
	}
	
	# Skip if there are no virtuals
	if ($vmCount -ge 1)
	{
		$ramCountGB = [Math]::Round($(($vms | measure-object -property MemoryMB -sum).Sum / 1024),2)
		$vCpuCount = $(($vms | measure-object -property NumCpu -sum).Sum)
		#Powered On State
		$poweredOn = $vms | where{$_.PowerState -eq "PoweredOn"}
		if ($poweredOn)
		{
			if ($poweredOn.GetType().IsArray)
			{
				$poweredOnCount = $poweredOn.Count
			} else {
				$poweredOnCount = 1
			}
		}

		#PoweredOff
		$poweredOff = $vms | where{$_.PowerState -eq "PoweredOff"}
		if ($poweredOff)
		{
			if ($poweredOff.GetType().IsArray)
			{
				$poweredOffCount = $poweredOff.Count
			} else {
				$poweredOffCount = 1
			}
		}
		
		# Other Power States
		$otherStates = $vms | where{$_.PowerState -ne "PoweredOff" -and $_.PowerState -ne "PoweredOn"}
		if ($otherStates)
		{
			if ($otherStates.GetType().IsArray)
			{
				$otherStatesCount = $otherStates.Count
			} else {
				$otherStatesCount = 1
			}
		}
	}
	
	$diskUsageGB = [math]::round(($vms | measure UsedSpaceGB -Sum).Sum/1024,2)
	$obj | Add-Member -Type NoteProperty -Name "Total VMs" -Value $vmCount;
	$numberInflexpod=$srvConnection |%{
		$vCenter = $_
		if ($configFile)
		{
			$ifConfig=Import-Csv $configFile
			$currentConfig = $ifConfig | ?{$_.vCenterSrvName -eq $vCenter.Name}
			$vCenterName = $currentConfig.MoreInfo
		} else {
			$vcenterName = $vCenter.Name
		}
		logThis -msg  "   --> VMs located only on [$vcenterName\$($folder.Name)" -ForegroundColor Yellow
		$tmpVMs= Get-vm -Server $vCenter -Location $folder.Name
		$vmTmpCount = 0;
		if ($tmpVMs)
		{
			if ($tmpVMs.GetType().IsArray)
			{
				$vmTmpCount = $tmpVMs.Count
			} else {
				$vmTmpCount = 1
			}
		}
		if ($vcenterName -eq "Optus-Flexpod")
		{
			$vmTmpCount
		}
		$obj | Add-Member -Type NoteProperty -Name "VMs in $vcenterName" -Value $vmTmpCount;
	}
	
	#$percStatus =  [Math]::Round($numberInflexpod / $vmCount * 100,2)
	#$obj | Add-Member -Type NoteProperty -Name "Migration Status" -Value "$percStatus%"
	
	$obj | Add-Member -Type NoteProperty -Name "vCPUs" -Value $vCpuCount;
	$obj | Add-Member -Type NoteProperty -Name "RAM (GB)" -Value $ramCountGB;
	$obj | Add-Member -Type NoteProperty -Name "Size (TB)" -Value $diskUsageGB;
	$obj | Add-Member -Type NoteProperty -Name "Powered On" -Value $poweredOnCount
	$obj | Add-Member -Type NoteProperty -Name "Powered Off" -Value $poweredOffCount
	$obj | Add-Member -Type NoteProperty -Name "Other State" -Value $otherStatesCount;
	
	if($showExtra)
	{
		$vmVersions | %{
			$currVersion = $_
			#logThis -msg  $_;
			$vmVersionsCount=0;
			$vmsOfcurrVersion=0;
			$vmsOfcurrVersion = $vms | ?{$_.Version -like $currVersion };
			#logThis -msg  $vmsOfcurrVersion
			if ($vmsOfcurrVersion)
			{
				if ($vmsOfcurrVersion.GetType().IsArray)
				{
					$vmVersionsCount = $vmsOfcurrVersion.Count
				} else {
					$vmVersionsCount = 1
				}
			}
			$obj | Add-Member -Type NoteProperty -Name "$currVersion" -Value "$vmVersionsCount"
			#logThis -msg  $vmVersionsCount
		}
		
		
		$OSTypes | %{
			$currOsType = $_;
			#logThis -msg  $currOsType;
			$thisOSTypeCount = 0;
			$thisOSType = 0;
			$thisOSType = $vms | ?{$_.ExtensionData.Summary.Config.GuestFullName -eq "$currOsType"};
			if ($thisOSType)
			{
				if ($thisOSType.GetType().IsArray)
				{
					$thisOSTypeCount = $thisOSType.Count
				} else {
					$thisOSTypeCount = 1
				}
			}
			$obj | Add-Member -Type NoteProperty -Name "$currOsType" -Value "$thisOSTypeCount"
		}
	}
	
	logThis -msg  $obj -ForegroundColor Yellow
	$obj
} | sort -Property "Total VMs"

#logThis -msg  $Report
############### THIS IS WHERE THE STUFF HAPPENS

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