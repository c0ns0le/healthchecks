# This scripts provides some quick stats on Virtual Machine capacity
# The results is used as an input into a Capacity Review Report
# Last updated: 23 March 2015
# Author: teiva.rodiere@gmail.com
#
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$showDate=$false,[int]$headerType=1)
Write-Host "Importing Module vmwareModules.psm1 (force)"
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
$metaInfo +="tableHeader=Virtual Machine Capacity Quickstats"
$metaInfo +="introduction=The table below provides usage information for all virtual Machines across all data centers."
$metaInfo +="titleHeaderType=h$($headerType)"
$metaInfo +="displayTableOrientation=List" # options are List or Table
$metaInfo +="chartable=false"
#$metaAnalytics


#Definitions for max vCPU/core and Mem reservations
$vCPUPerpCorePolicyLimit = 4; #max of 4vCPU per core
$mem = 100; # 100%

$vms = Get-VM * -Server $srvConnection

logThis -msg "Processing VMs in vCenter $($_.Name)" -Foregroundcolor Green
logThis -msg "Getting Virtual Machines" -ForegroundColor Yellow

$vmsCount = $vms.Count    
logThis -msg "vCPU Count" -ForegroundColor Yellow
$vCPUCount = $($vms | measure -property NumCPU -sum).Sum
logThis -msg "vRAM Count" -ForegroundColor Yellow
$vRAMCount = $($vms | measure -property MemoryMB -sum).Sum
logThis -msg "Powered ON " -ForegroundColor Yellow
$poweredOn = $($vms | ?{$_.PowerState -eq "PoweredOn"}).Count
logThis -msg "Powered OFF " -ForegroundColor Yellow
$poweredOff = $($vms | ?{$_.PowerState -eq "PoweredOff"}).Count
logThis -msg "Powered OTHER " -ForegroundColor Yellow
$poweredOther = $($vms | ?{$_.PowerState -ne "PoweredOn" -and $_.PowerState -ne "PoweredOff"}).Count
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

$dataTable = New-Object System.Object
$dataTable | Add-Member -MemberType NoteProperty -Name "Total" -Value "$vmsCount, $poweredOn are Powered On, $poweredOff are Off, $poweredOther in other state"
$dataTable | Add-Member -MemberType NoteProperty -Name "Deployed CPU" -Value $vCPUCount
$dataTable | Add-Member -MemberType NoteProperty -Name "Deployed Memory" -Value (getsize -unit "MB" -val $vRAMCount)
$dataTable | Add-Member -MemberType NoteProperty -Name "Total Disk Provisioned" -Value (getsize -unit "B" -val $vmdkProvisionedBytes)
$dataTable | Add-Member -MemberType NoteProperty -Name "Total Disk Consumed" -Value (getsize -unit "B" -val $vmdkConsumedBytes)
$dataTable | Add-Member -MemberType NoteProperty -Name "Total Disk Saved by Thin Provisioning" -Value (getsize -unit "B" -val $vmdkSpaceSavingsThinBytes)
$dataTable | Add-Member -MemberType NoteProperty -Name "vSphere Replication" -Value "$($vmsWithvSphereReplication.Count) configured"
$dataTable | Add-Member -MemberType NoteProperty -Name "Fault Tolerance" -Value "$ftConfiguredVMs configured for FT, $ftSupportYes support it"


ExportCSV -table $dataTable
if ($metaAnalytics)
{
	$metaInfo += "analytics="+$metaAnalytics
}
ExportMetaData -meta $metaInfo

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}