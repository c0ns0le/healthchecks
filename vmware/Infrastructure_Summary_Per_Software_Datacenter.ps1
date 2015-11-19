# This scripts provides some capacity information for an environment 
# The results is used as an input into a Capacity Review Report
# Last updated: 8 March 2012
# Author: teiva.rodiere@gmail.com
#
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$showDate=$false,[int]$headerType=1)
logThis -msg "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global
$global:logfile
$global:outputCSV


# Want to initialise the module and blurb using this 1 function
InitialiseModule

# Report Meta Data
$metaInfo = @()
$metaInfo +="tableHeader=Total Capacity By Software Defined DataCenter"
$metaInfo +="titleHeaderType=h$($headerType)"
$metaInfo +="displayTableOrientation=list" # options are List or Table
$metaInfo +="introduction=Find below a breakdown of your capacity by data center(SDD)."
$metaInfo +="chartable=false"
#$metaAnalytics

logThis -msg "Enumerating datacenters..."
$report = Get-Datacenter -Server $srvConnection | %{
	$dc = $_
	#$svConnection
	logThis -msg "-> Processing datacenter $($dc.Name)"
	logThis -msg "`t-> Loading clusters"
	$clusters = Get-Cluster * -Location $dc
	#logThis -msg "`t-> Loading Datacenters"
	#$datacenters = Get-datacenter -Location $dc
	logThis -msg "`t-> Loading VMs"
	$vms = Get-VM * -Location $dc
	logThis -msg "`t-> Loading datastores"
	$datastores = get-datastore * -Location $dc
	logThis -msg "`t-> Loading VMHosts"
	$vmhosts = get-vmhost * -Location $dc

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
	logThis -msg $row
	
	$row
}

# Perform some analytics


# Post Creation of Report
ExportCSV -table $report
if ($metaAnalytics)
{
	$metaInfo += "analytics="+$metaAnalytics
}
ExportMetaData -meta $metaInfo

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}