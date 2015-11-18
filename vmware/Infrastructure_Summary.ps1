# This scripts provides some capacity information for an environment 
# The results is used as an input into a Capacity Review Report
# Last updated: 23 March 2015
# Author: teiva.rodiere@gmail.com
#
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$showDate=$false,[int]$headerType=1)
logThis -msg "Importing Module vmwareModules.psm1 (force)"
Write-Host "$logfile" -BackgroundColor Red -ForegroundColor Yellow
Write-Host "global: $global:logfile" -BackgroundColor Red -ForegroundColor Yellow
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global

InitialiseModule
#Set-Variable -Name logDir -Value $logDir -Scope Global

Write-Host "$logfile" -BackgroundColor Red -ForegroundColor Yellow
Write-Host "global: $global:logfile" -BackgroundColor Red -ForegroundColor Yellow
#pause

# Report Meta Data
$metaInfo = @()
$metaInfo +="tableHeader=Infrastructure"
$metaInfo +="titleHeaderType=h$($headerType)"
$metaInfo +="displayTableOrientation=List" # options are List or Table
$metaInfo +="introduction=The table below contains some capacity overview for your infrastructure."
$metaInfo +="chartable=false"
#$metaAnalytics

#logThis -msg "Enumerating datacenters..."

#$svConnection
logThis -msg "-> Loading clusters"
$clusters = Get-Cluster -Server $svConnection
logThis -msg "-> Loading Datacenters"
$datacenters = Get-datacenter -Server $svConnection
logThis -msg "-> Loading VMs"
$vms = Get-VM -Server $svConnection
logThis -msg "-> Loading datastores"
$datastores = get-datastore -Server $svConnection
logThis -msg "-> Loading VMHosts"
$vmhosts = Get-VMHost -Server $svConnection


$row  = New-Object System.Object
$row | Add-Member -MemberType NoteProperty -Name "VMware vCenter Servers" -Value $srvConnection.Count
$row | Add-Member -MemberType NoteProperty -Name "Datacenters" -Value $datacenters.Count

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
$vmdkProvisionedBytes = $($VMs.ExtensionData.Summary.Storage.Committed | measure -Sum).Sum + $($VMs.ExtensionData.Summary.Storage.Uncommitted | measure -Sum).Sum
$vmdkConsumedBytes = $($VMs.ExtensionData.Summary.Storage.Committed | measure -Sum).Sum
$vmdkSpaceSavingsThinBytes = $($VMs.ExtensionData.Summary.Storage.Uncommitted | measure -Sum).Sum	
$vmsWithvSphereReplication = $vms | %{
	if ($(($_.ExtensionData.Config.ExtraConfig) | ?{$_.Key -like "*hbr_filter*"}).Count -gt 0)
	{
		$_.Name
	}
}

$ftSupport=$vms.ExtensionData.Config.ExtraConfig | ?{$_.key -like "*replay.supported*"} | select Key,Value
$ftSupportYes=($ftSupport | ?{$_.Value -eq "true"}).Count
$ftSupportNo=($ftSupport | ?{$_.Value -eq "true"}).Count
$ftConfiguredVMs=($vms.ExtensionData.Config.ExtraConfig | ?{$_.key -like "*replay.allowFT*"} | select Key,Value).Count


$row | Add-Member -MemberType NoteProperty -Name "VMware ESX/ESXi Servers" -Value "Total $($vmhosts.Count) Servers $([string] $vmhostsStates) | $vmhostsInMaintenanceMode In Maintenance | $($($vmhosts.ExtensionData.OverallStatus -ne ""green"").Count) Need Attention"
$row | Add-Member -MemberType NoteProperty -Name "Clusters" -Value "Total $($clusters.Count) Clusters | $($($clusters | ?{$_.HAEnabled}).Count) HA Enabled | $($($clusters | ?{!$_.HAEnabled}).Count) HA Disabled | $($($clusters | ?{$_.DrsEnabled}).Count) DRS Enabled | $($($clusters | ?{!$_.DrsEnabled}).Count) DRS Disabled | $($($clusters.ExtensionData.OverallStatus -ne ""green"").Count) Need Attention"
$row | Add-Member -MemberType NoteProperty -Name "Datastores" -Value "Total $($datastores.Count) | $(formatNumbers $dtCapacity)TB Capacity | $(formatNumbers $dtFreespace)TB Free ($(formatNumbers $dtFreespacePerc)%) $([string]$dtTypes) $([string]$dtVmfs) | $($($datastores.ExtensionData.OverallStatus -ne ""green"").Count) Need Attention"
$row | Add-Member -MemberType NoteProperty -Name "Virtual Machines" -Value "Total $($vms.Count) VMs | $vmsOn Powered On ($vmsOnPerc) | $vmsNeedingAttention Needing Attention | $(formatNumbers ($vms | measure -Property MemoryGB -Sum).Sum)GB Memory | $(($vms | measure -Property NumCPU -Sum).Sum) vCPU "
$row | Add-Member -MemberType NoteProperty -Name "VMs Disk Usage" -Value "$(getsize -unit 'B' -val $vmdkProvisionedBytes) Provisioned, $(getsize -unit 'B' -val $vmdkConsumedBytes) Consumed, $(getsize -unit 'B' -val $vmdkSpaceSavingsThinBytes) Savings through Thin Disk deployment"
$row | Add-Member -MemberType NoteProperty -Name "vSphere Replication" -Value "$($vmsWithvSphereReplication.Count) configured"
$row | Add-Member -MemberType NoteProperty -Name "Fault Tolerance" -Value "$ftConfiguredVMs Virtual Machines configured for FT, $ftSupportYes Virtuals Machines support it"

logThis -msg $row
$row

# Post Creation of Report
ExportCSV -table $row
if ($metaAnalytics)
{
	$metaInfo += "analytics="+$metaAnalytics
}
ExportMetaData -meta $metaInfo

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}