﻿# Exports Distributed vSwitches configurations and essential information from vCenter for documentation purposes
#Version : 0.1
#Updated : 3th Feb 2015
#Author  : teiva.rodiere@gmail.com
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$showDate=$false)
logThis -msg "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global
$global:logfile
$global:outputCSV

# Want to initialise the module and blurb using this 1 function
InitialiseModule

$metaInfo = @()
$metaInfo +="tableHeader=Standard Networks"
$metaInfo +="introduction=The table below provides a comprehensive list of standard network switches."
$metaInfo +="chartable=false"
$metaInfo +="titleHeaderType=h$($headerType)"

$Report = $srvConnection | %{
	$vcenter = $_
	Get-VirtualSwitch -Standard * -Server $vcenter | %{
		$vswitch = $_		
		# define an object to capture all the information needed
		$row = "" | select "VMHost"
		$row.VMHost = $vswitch.VMHost
		$clustername = (get-cluster -Server $vcenter -vmhost $report.VMhost).Name
		$row | Add-Member -Type NoteProperty -Name "vSwitch" -Value $vswitch.Name		
		$row | Add-Member -Type NoteProperty -Name "NICs" -Value $([string]$_.nic -replace ' ',',')
		$row | Add-Member -Type NoteProperty -Name "Number of Ports" -Value $vswitch.NumPorts
		$row | Add-Member -Type NoteProperty -Name "Avail of Ports" -Value $vswitch.NumPortsAvailable
		$row | Add-Member -Type NoteProperty -Name "MTU" -Value $vswitch.Mtu
		$row | Add-Member -Type NoteProperty -Name "Cluster" -Value $clustername
		if ($srvConnection.Count -gt 1)
		{
			$row | Add-Member -Type NoteProperty -Name "vCenter" -Value $vcenter.Name
		}		

		$row | Add-Member -Type NoteProperty -Name "Port Groups" -Value $((([string]((Get-VirtualPortGroup -VMHost $vswitch.VMHost | Select @{n='Name';e={"$($_.Name) ($($_.VlanId))" -replace ' ','>>'}}).Name)) -replace ' ',', ') -replace '>>',' ')
		"AllowPromiscuous","MacChanges","ForgedTransmits" | %{
			$row | Add-Member -Type NoteProperty -Name "$_" -Value $vswitch.ExtensionData.Spec.Policy.Security.$_
		}
		# output
		logThis -msg $row -ForegroundColor green
		$row
	}
}

############### THIS IS WHERE THE STUFF HAPPENS
if ($Report)
{
	ExportCSV -table $Report
}
# Post Creation of Report
if ($metaAnalytics)
{
	$metaInfo += "analytics="+$metaAnalytics
}
ExportMetaData -meta $metaInfo

logThis -msg "Logs written to " $of -ForegroundColor  yellow;
if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}