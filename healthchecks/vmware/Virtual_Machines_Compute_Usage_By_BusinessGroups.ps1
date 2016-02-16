# Group Virtual Machines by vFolder and provides a table summary
#Version : 1.0
#Updated : 23 March 2015
#Author  : teiva.rodiere-at-gmail.com
param(
	[object]$srvConnection="",
	[string]$logDir="output",
	[string]$comment="",
	[bool]$verbose=$true,
	[int]$headerType=1,
	[bool]$returnResults=$true,
	[bool]$showDate=$false,
	[bool]$showExtra=$true,
	[string]$startinFolder="rootFolder"
)
$silencer = Import-Module -Name .\vmwareModules.psm1 -Force -PassThru -Verbose:$false
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global



#[string]$configFile=".\customerEnvironmentSettings-ALL.ini",

# Report Meta Data
$metaInfo = @()
$metaInfo +="tableHeader=Virtual Machines by Business Folders"
$metaInfo +="introduction=The table below groups Virtual Machines according to their location within the vCenter VM Folder structure."
$metaInfo +="chartable=false"
$metaInfo +="titleHeaderType=h$($headerType)"

$allVMs = GetVMs -server $srvConnection
$powerStates = $allVMs.PowerState | sort -Unique
$allfolders = GetvcFolders -Server $srvConnection 

# Get the list of root folders
logThis -msg "Getting List of folders from [$srvConnection -> $startinFolder] (see ""Virtual Machine and Templates"" panel view)"
$defaultFolder="rootFolder"
if ($startinFolder -eq $defaultFolder)
{
	$folders = $allfolders | ?{$_.Type -eq "VM" -and $_.Parent -like "vm"} | sort Name -unique
	logThis -msg  "`t--> Getting list of VMs from [$startinFolder]"
} else {
	$folders = $allfolders | ?{$_.Type -eq "VM" -and $_.Parent -eq $startinFolder} | sort Name -unique
	logThis -msg  "`t--> Getting list of VMs from [$startinFolder]"
}

if($showExtra)
{
	logThis -msg  "`t-> Building a list of OS Types from the results"
	$OSTypes=$allVms | %{$_.ExtensionData.Summary.Config.GuestFullName} | sort -unique 
	logThis -msg  "`t-> Building a list of available VM Versions"
	$vmVersions = $allVms | %{$_.Version} | select -unique
}


$dataTable = $folders | %{ 
	$folder = $_
	Write-Host "Processing VMs in folder ""$($folder.Name)""";
	#$vms = $allVms | ?{$_.Folder.Name -like $folder}
	Write-Host "([string]$($folder.VM))"
	$vms = $folder.VMs |  %{
		$vmInFolder = $_.Name
		$vm = $allVMs | ?{$_.Name -eq $vmInFolder}
		$vm
	}
	$row = new-Object System.Object;
	$row | Add-Member -Type NoteProperty -Name "Location" -Value $folder.Name;
	$vmCount=0 
	$vCpuCount=0
	$ramCountGB=0
	$poweredOnCount = 0
	$poweredOffCount=0
	$otherStatesCount=0
	$vmCount = ($vms | measure).Count
	
	# Skip if there are no virtuals
	if ($vmCount -gt 0)
	{
		
		$ramCountGB = [Math]::Round($(($vms | measure-object -property MemoryMB -sum).Sum / 1024),2)		
		$vCpuCount = $(($vms | measure-object -property NumCpu -sum).Sum)
		#Powered On State
		#$poweredOnCount = (($vms | where{$_.PowerState -eq "PoweredOn"}) | measure).Count
		#$poweredOffCount = (($vms | where{$_.PowerState -eq "PoweredOff"}) | measure).Count
		#$otherStatesCount = (($vms | where{$_.PowerState -ne "PoweredOff" -and $_.PowerState -ne "PoweredOn"}) | measure).Count
	}
	
	$diskUsageGB = ($vms | measure UsedSpaceGB -Sum).Sum
	$row | Add-Member -Type NoteProperty -Name "VMs" -Value $vmCount;
	#if ($srvConnection.Count -gt 1)
	#{
	#	$name = $_.Name
	#	$row | Add-Member -Type NoteProperty -Name "Total VMs in $name" -Value ;
	#}
	$row | Add-Member -Type NoteProperty -Name "CPU" -Value $vCpuCount;
	$row | Add-Member -Type NoteProperty -Name "Mem" -Value $(getSize -Unit "GB" -Val $ramCountGB);
	$row | Add-Member -Type NoteProperty -Name "Disk" -Value $(getSize -Unit "GB" -Val $diskUsageGB);

	$powerStates | %{
		$state = $_
		Write-Host $state
		$stateCount = ($vms.PowerState | ?{$_ -eq $state} | measure -Sum).Sum
		$row | Add-Member -Type NoteProperty -Name $($state -replace "Powered",'') -Value $stateCount
		#Write-Host "$($state -replace 'Powered','') $stateCount"
	}
	
	if($showExtra)
	{
		$vmVersions | %{
			$currVersion = $_
			#Write-Host $currVersion
			#pause
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
			if ($currVersion -eq "Unknown")
			{
				$row | Add-Member -Type NoteProperty -Name "v?" -Value "$vmVersionsCount"
			} else {
				$row | Add-Member -Type NoteProperty -Name "$currVersion" -Value "$vmVersionsCount"
			}
			
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
			$row | Add-Member -Type NoteProperty -Name "$currOsType" -Value "$thisOSTypeCount"
		}
	}
	
	#logThis -msg  $row -ForegroundColor $global:colours.Information
	$row
} | sort -Property "Total VMs"


#logThis -msg  $Report
############### THIS IS WHERE THE STUFF HAPPENS

if ($dataTable)
{	
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