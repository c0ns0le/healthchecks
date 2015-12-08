# This scripts provides some capacity information for an environment 
# The results is used as an input into a Capacity Review Report
# Last updated: 8 March 2012
# Author: teiva.rodiere-at-gmail.com
#
param(
	[object]$srvConnection="",
	[string]$logDir="output",
	[string]$comment="",
	[bool]$showDate=$false,
	[int]$headerType=1,
	[bool]$returnResults=$true
)
$silencer = Import-Module -Name .\vmwareModules.psm1 -Force -PassThru -Verbose:$false -ErrorAction SilentlyContinue
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global


#$global:outputCSV

# Want to initialise the module and blurb using this 1 function


# Report Meta Data
$metaInfo = @()
$metaInfo +="tableHeader=Total Capacity By Software Defined DataCenter"
$metaInfo +="titleHeaderType=h$($headerType)"
$metaInfo +="displayTableOrientation=list" # options are List or Table
$metaInfo +="introduction=Find below a breakdown of your capacity by data center(SDD)."
$metaInfo +="chartable=false"


logThis -msg "-> Loading clusters"
$allclusters = getClusters -server $srvConnection
logThis -msg "-> Loading Datacenters"
$alldatacenters = getDatacenters -server $srvConnection
logThis -msg "-> Loading VMs"
$allvms = getVMs -Server $srvConnection
logThis -msg "-> Loading datastores"
$alldatastores = getDatastores -Server $srvConnection
logThis -msg "-> Loading VMHosts"
$allvmhosts = GetVMHosts -Server $srvConnection

$dataTable = $alldatacenters | %{
	$dc = $_
	#$svConnection
	logThis -msg "-> Processing datacenter $($dc.Name)"
	$vms = $allvms | ?{$_.vCenter -eq $dc.vCenter -and $_.Datacenter.Name -eq $dc.Name}
	$clusters = $allclusters | ?{$_.vCenter -eq $dc.vCenter -and $_.Datacenter.Name -eq $dc.Name}
	$datastores = $alldatastores | ?{$_.vCenter -eq $dc.vCenter -and $_.Datacenter.Name -eq $dc.Name}
	$vmhosts = $allvmhosts | ?{$_.vCenter -eq $dc.vCenter -and $_.Datacenter.Name -eq $dc.Name}

	$row  = New-Object System.Object
	$row | Add-Member -MemberType NoteProperty -Name "Datacenter Name" -Value "$($dc.Name)"
	#$row | Add-Member -MemberType NoteProperty -Name "VMware vCenter Servers" -Value $srvConnection.Count
	#$row | Add-Member -MemberType NoteProperty -Name "Datacenters" -Value	$datacenters.Count

	$vmsOn = ($vms | ?{$_.PowerState -eq "PoweredOn"}).Count
	$vmsOnPerc = "$(formatNumbers $(($vms | ?{$_.PowerState -eq ""PoweredOn""}).Count / $vms.Count * 100))%"
	$vmsNeedingAttention = $($vms.ExtensionData.OverallStatus -ne "green").Count
	$vmhostsOn = "$(formatNumbers $(($vmhosts | ?{$_.PowerState -eq ""PoweredOn""}).Count / $vmhosts.Count * 100))%"
	$vmhostsInMaintenanceMode = $($vmhosts | ?{$_.ExtensionData.Summary.Runtime.InMaintenanceMode}).Count
	$vmhostsStates = $vmhosts | select ConnectionState -Unique | %{
		$state = $_
		Write-Output " | $($($vmhosts | ?{$_.State -eq $state.ConnectionState}).Count) $($state.ConnectionState)"
	}

	$dtCapacity = $(formatNumbers $($($Datastores | measure -Sum CapacityGB).Sum / 1024))
	$dtFreespace = ($Datastores | measure -Sum FreeSpaceGB).Sum / 1024
	$dtFreespacePerc = $dtFreespace / $dtCapacity * 100
	$dtTypes = $Datastores | select Type -Unique | %{
		$Type = $_
		Write-Output " | $($($Datastores | ?{$_.Type -eq $Type.Type}).Count) $($Type.Type)"
	}
	$dtVmfs = $Datastores | select FileSystemVersion -Unique | %{
		$FileSystemVersion = $_
		Write-Output " | $($($Datastores | ?{$_.FileSystemVersion -eq $FileSystemVersion.FileSystemVersion}).Count) VMFS-$($FileSystemVersion.FileSystemVersion)"
	}
	$row | Add-Member -MemberType NoteProperty -Name "Servers" -Value "$($vmhosts.Count)"
	$row | Add-Member -MemberType NoteProperty -Name "CPUs (Ghz)" -Value  "$(formatNumbers (($vmhosts.CpuTotalMhz | measure -Sum).Sum / 1024))"
	$row | Add-Member -MemberType NoteProperty -Name "Total RAM (GB)" -Value  "$(formatNumbers (($vmhosts.MemoryTotalGB | measure -Sum).Sum))"
	$row | Add-Member -MemberType NoteProperty -Name "Virtual Machines" -Value "$($vms.Count)"
	$row | Add-Member -MemberType NoteProperty -Name "Virtual Machines vRAM" -Value "$(formatNumbers ($vms | measure -Property MemoryGB -Sum).Sum)"
	$row | Add-Member -MemberType NoteProperty -Name "Virtual Machines vCPU" -Value "$(($vms | measure -Property NumCPU -Sum).Sum)"
	$row | Add-Member -MemberType NoteProperty -Name "Clusters" -Value "$($clusters.Count)"
	$row | Add-Member -MemberType NoteProperty -Name "Clusters With HA" -Value "$($($clusters | ?{$_.HAEnabled}).Count)"
	$row | Add-Member -MemberType NoteProperty -Name "Clusters With DRS" -Value "$($($clusters | ?{$_.DrsEnabled}).Count)"
	#$row | Add-Member -MemberType NoteProperty -Name "Storage" -Value "$($datastores.Count)"
	$row | Add-Member -MemberType NoteProperty -Name "Storage Capacity (TB)" -Value " $(formatNumbers $dtCapacity)"
	$row | Add-Member -MemberType NoteProperty -Name "Free Capacity (TB)" -Value "$(formatNumbers $dtFreespace)"
	#logThis -msg $row
	$row
}
# Perform some analytics


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