# This script exports a list of VM with minimal information so it fits in a word document for reporting.
# The results is used as an input into a Capacity Review Report
# Last updated: 23 March 2015
# Author: teiva.rodiere@gmail.com
#
param(
		[object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$showOnlyTemplates=$false,
		[bool]$skipEvents=$true,[bool]$verbose=$false,
		[int]$numsamples=([int]::MaxValue),[int]$numPastDays=7,
		[int]$sampleIntevalsMinutes=5,[int]$headerType=1)
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
$metaInfo +="tableHeader=Comprehensive List of Virtual Machines"
$metaInfo +="introduction=The table below contains a comprehensive list of your Virtual Machines found in your inventory."
$metaInfo +="chartable=false"
$metaInfo +="reportPeriodInDays=$numPastDays"
$metaInfo +="reportPeriodInvtervalsInMins=$sampleIntevalsMinutes"
$metaInfo +="titleHeaderType=h$($headerType)"
$metaInfo +="displayTableOrientation=Table" # options are List or Table
#$metaAnalytics


$index=1;
$report =  $srvConnection | %{
    $vcenterName = $_.Name
    if ($showOnlyTemplates) 
    {
        logThis -msg "Enumerating Virtual Machines Templates only from vCenter $_ inventory..." -ForegroundColor Yellow
        $vms = Get-Template -Server $_ | Sort-Object Name
        
        #logThis -msg "Enumerating Virtual Machines Templates Views from vCenter $_ inventory..." -ForegroundColor Red
        #$vmsViews = $vms | Get-View;
    } else {
        logThis -msg "Enumerating Virtual Machines from vCenter $_ inventory..." -ForegroundColor Yellow
        $vms = Get-VM -Server $_ | Sort-Object Name 
        
        #logThis -msg "Enumerating Virtual Machines Views from vCenter $_ inventory..." -ForegroundColor Red
        #$vmsViews = $vms | Get-View;
    }
    
    if ($vms) 
    {
        logThis -msg "Loading vcFolders from vCenter $_..." -ForegroundColor Yellow
        $vcFolders = get-folder * -Server $_ | select -unique
    
        logThis -msg "Loading Virtual Machine Creation Events from vCenter $_..." -ForegroundColor Yellow
        if (!$skipEvents)
        {
            # only load events for virtual machines which 
            #$viEvents = $vms | Get-VIEvent -Finish (get-date) -Start $(get-date).AddYears(-10) -Types Info  -MaxSamples ([int]::MaxValue) -Server $_ | Where { $_.Gettype().Name -eq "VmReconfiguredEvent" -or $_.Gettype().Name -eq "VmBeingDeployedEvent" -or $_.Gettype().Name -eq "VmCreatedEvent" -or $_.Gettype().Name -eq "VmRegisteredEvent"}
			$viEvents = $vms | Get-VIEvent -Types Info  -MaxSamples ([int]::MaxValue) -Server $_ | Where { $_.Gettype().Name -eq "VmReconfiguredEvent" -or $_.Gettype().Name -eq "VmBeingDeployedEvent" -or $_.Gettype().Name -eq "VmCreatedEvent" -or $_.Gettype().Name -eq "VmRegisteredEvent"}
        }
    
        $vms | %{
			$vm = $_;
            #$vmView = $vmsView | ?{$_.Name -eq $vm.Name}
			logThis -msg "Processing $index of $($vms.Count) :- $vm" -ForegroundColor Yellow;
			$row = "" | Select-Object Name; 
			$row.Name = $vm.Name;
            $row | Add-Member -Type NoteProperty -Name "State" -Value $([string]([string]$vm.PowerState).Replace("Powered",""))
            $Created ="";
            $User = "";
 
			$cpuStats = -1
			$memStats = -1
			$netStats = -1
			#$balloonStats = -1
			
			
			
			
			$row | Add-Member -Type NoteProperty -Name "Tools Status" -Value $([string]([string]$vm.ExtensionData.Guest.ToolsStatus).Replace("tools",""));
            $row | Add-Member -Type NoteProperty -Name "CPU" -Value  "$(formatNumbers ($vm.ExtensionData.Summary.Config.NumCPU))"
            $row | Add-Member -Type NoteProperty -Name "Memory (GB)" -Value "$(formatNumbers ($vm.ExtensionData.Summary.Config.MemorySizeMB / 1024))"
            $row | Add-Member -Type NoteProperty -Name "Size (GB)" -Value  "$(formatNumbers (($vm.ExtensionData.Summary.Storage.Committed + $vm.ExtensionData.Summary.Storage.Uncommitted) / 1gb))";

			if ($vm.PowerState -eq "PoweredOn")
			{
				$cpuStats = "{0:n2}" -f $(Get-Stat -Entity $vm -Stat "cpu.usage.average" -MaxSamples $numsamples -Start (Get-Date).AddDays(-$numPastDays) -IntervalMins $sampleIntevalsMinutes | measure -Property Value -Average).Average
				$memStats = "{0:n2}" -f $(Get-Stat -Entity $vm -Stat "mem.usage.average" -MaxSamples $numsamples -Start (Get-Date).AddDays(-$numPastDays) -IntervalMins $sampleIntevalsMinutes | measure -Property Value -Average).Average	
				$netStats = "{0:n2}" -f $(Get-Stat -Entity $vm -Stat "net.usage.average" -MaxSamples $numsamples -Start (Get-Date).AddDays(-$numPastDays) -IntervalMins $sampleIntevalsMinutes | measure -Property Value -Average).Average
				#$balloonStats = "{0:n2}" -f $(Get-Stat -Entity $vm -Stat "mem.vmmemctl.average" -MaxSamples $numsamples -Start (Get-Date).AddDays(-$numPastDays) -IntervalMins $sampleIntevalsMinutes | measure -Property Value -Average).Average
				#$swapStats = "{0:n2}" -f $(Get-Stat -Entity $vm -Stat "mem.swapped.average" -MaxSamples $numsamples -Start (Get-Date).AddDays(-$numPastDays) -IntervalMins $sampleIntevalsMinutes | measure -Property Value -Average).Average
			}
			
			if ($cpuStats -eq -1)
			{
				$row | Add-Member -Type NoteProperty -Name "Avg CPU Usage (%)" -Value $(printNoData) ;
			} else {
				$row | Add-Member -Type NoteProperty -Name "Avg CPU Usage (%)" -Value "$cpuStats" ;
			}
			
			if ($memStats -eq -1)
			{
				$row | Add-Member -Type NoteProperty -Name "Avg Mem Usage (%)" -Value  $(printNoData);			
			} else {
				$row | Add-Member -Type NoteProperty -Name "Avg Mem Usage (%)" -Value  "$memStats";			
			}
			if ($netStats -eq -1)
			{
				$row | Add-Member -Type NoteProperty -Name "Avg Network Usage (KBps)" -Value $(printNoData) ;
			} else {
				$row | Add-Member -Type NoteProperty -Name "Avg Network Usage (KBps)" -Value "$netStats" ;
			}
			
    		if ($verbose)
            {
                logThis -msg $row;
            }
    		$row;
            $index++;
        }
    } # if ($vms)
}


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