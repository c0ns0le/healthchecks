# This scripts provides an analysis of VM Creation Trends on a monthly basis
# Last updated: 31 March 2011
# Author: teiva.rodiere-at-gmail.com
#
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="")
logThis -msg "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global
$global:logfile
$global:outputCSV

# Want to initialise the module and blurb using this 1 function
#InitialiseModule


logThis -msg "Collecting all VMs..."
$vms = Get-VM * -Server $srvConnection;
logThis -msg "$($vms.Count) found" -ForegroundColor Yellow 
logThis -msg "Collecting information required...." -ForegroundColor Cyan
$vmCount = 1
$vmevts = $vms | %{
	$vm = $_
	$vmevt = new-object PSObject
	$searchString = "Processing: $($vm.name)"
    $percentComplete = $vmCount / $vms.count * 100
	$foundString = "$vm"
    write-progress -activity $foundString -status $searchString -percentcomplete $percentComplete
    #$evt = Get-VIEvent $vm -MaxSamples 999999999 -Start $(Get-Date).AddYears(-2) -Finish (Get-Date) | sort Date | select -first 1
	$evt = Get-VIEvent $vm -Types Info -MaxSamples 999999999 -Finish (Get-Date) | ?{ $_.Gettype().Name -eq "VmBeingDeployedEvent" -or $_.Gettype().Name -eq "VmCreatedEvent" -or $_.Gettype().Name -eq "VmRegisteredEvent" -or $_.Gettype().Name -eq "VmClonedEvent"}
    $vmevt | add-member -type NoteProperty -Name Date -Value $evt.Date
    $vmevt | add-member -type NoteProperty -Name name -Value $vm.name
    $vmevt | add-member -type NoteProperty -Name IPAddress -Value $vm.Guest.IPAddress
    $vmevt | add-member -type NoteProperty -Name createdBy -Value $evt.UserName
	
    #uncomment the following lines to retrieve the datastore(s) that each VM is stored on
    #$datastore = get-datastore -VM $vm
    #$datastore = $vm.HardDisks[0].Filename | sed 's/\[\(.*\)\].*/\1/' #faster than get-datastore
    #$vmevt | add-member -type NoteProperty -Name Datastore -Value $datastore
    logThis -msg $vmevt
	$vmevt
	$vmCount++
}

#$vmevts | sort Date

ExportCSV -table ($vmevts | sort Date)
logThis -msg "Logs written to $of" -ForegroundColor  yellow;

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}