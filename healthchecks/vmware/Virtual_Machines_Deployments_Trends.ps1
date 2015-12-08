# Creates a summary of virtual machine creations
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$showDate=$false,[int]$lastMonths=3,[bool]$includeThisMonth=$false)

Write-Host "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global




# Want to initialise the module and blurb using this 1 function


#LogThis -msg "This script log to " $of -ForegroundColor Yellow 

$now = get-date #(get-date).AddMonths(-1) #use now but because we are half way thought the month, i only want up to the last day of the previous month
#$lastMonths = 12 # Overwrite default here 


$clusters = get-cluster -Server $srvconnection
$date = $now.AddMonths(-$lastMonths)
$output = "" | Select "Months"
$output.Months = (get-date $date -format y)
$firstDayOfMonth = get-date ("1/" + (Get-Date $date).Month + "/" + (Get-Date $date).Year + " 00:00:00")
$lastDayOfMonth =  ((get-date).AddMonths(+1)) - (New-TimeSpan -seconds 1)
LogThis -msg "loading all events pertaining to creations and deletions from $srvconnection"
$viEvents = Get-VIEvent -Server $srvconnection -Start $firstDayOfMonth -Finish $lastDayOfMonth -Types info -MaxSamples ([int]::MaxValue)  | Where { $_.Gettype().Name -eq "VmBeingDeployedEvent" -or $_.Gettype().Name -eq "VmCreatedEvent" -or $_.Gettype().Name -eq "VmRegisteredEvent" -or $_.Gettype().Name -eq "VmClonedEvent" -or $_.Gettype().Name -eq "VmRemovedEvent"}
#$viEvents  | Export-csv -NoTypeInformation "$logDir\alleventshostmaintenance.csv"
if ($includeThisMonth -eq $true)
{
	$upToMonth = 0
} else {
	$upToMonth = 1
}
#$report = $clusters | %{
    #$cluster = $_    
    #$of = $logDir + "\"+$filename+"-"+$cluster.Name.replace(" ","_")+".csv"
    #LogThis -msg "The stats for cluster ""$cluster"" will output to " $of -ForegroundColor Yellow 
	$i = $lastMonths
    $report = do {
	#do {
        $date = $now.AddMonths(-$i)
        $output = "" | Select "Months"
        $output.Months = (get-date $date -format y)
        $firstDayOfMonth = get-date ("1/" + (Get-Date $date).Month + "/" + (Get-Date $date).Year + " 00:00:00")
        $lastDayOfMonth =  ($firstDayOfMonth.AddMonths(+1)) - (New-TimeSpan -seconds 1)

        #$vIEvents = Get-VIEvent -Start $firstDayOfMonth -Finish $lastDayOfMonth -MaxSamples ([int]::MaxValue) -Server $srvConnections | ?{$_.Vm -and $_.FullFormattedMessage -match "Deploying"}
        $vmsRegisteredEvents = $viEvents  | Where {$_.Gettype().Name -eq "VmRegisteredEvent" -and (get-date $_.Createdtime).Month -eq (Get-Date $date).Month}
        $vmCreationsEvents = $viEvents  | Where {  $_.Gettype().Name -eq "VmBeingDeployedEvent" -and $_.Gettype().Name -eq "VmCreatedEvent" -and (get-date $_.Createdtime).Month -eq (Get-Date $date).Month}
        $vmDeletionEvents = $viEvents  | Where { $_.Gettype().Name -eq "VmRemovedEvent" -and (get-date $_.Createdtime).Month -eq (Get-Date $date).Month}
		
		LogThis -msg "Month $(Get-Date $date -format y) :- Registered = $($vmsRegisteredEvents.Count), Deployed = $($vmCreationsEvents.count), Deleted = $($vmDeletionEvents.Count)" -ForegroundColor Red -BackgroundColor Yellow		
		
        if ($vmCreationsEvents) {
            if (!$vmCreationsEvents.Count) {
                $vmCreationsCount = 1
            } else {
                $vmCreationsCount = $vmCreationsEvents.Count
            } 
        } else {
            $vmCreationsCount = 0
        }
        
        if ($vmDeletionEvents) {
            if (!$vmDeletionEvents.Count) {
                $vmDeletionCount = 1
            } else {
                $vmDeletionCount = $vmDeletionEvents.Count
            }
        } else {
            $vmDeletionCount = 0
        }
        if ($vmsRegisteredEvents) {
            if (!$vmsRegistered.Count) {
                $vmsRegisteredCount = 1
            } else {
                $vmsRegisteredCount = $vmsRegisteredEvents.Count
            }
        } else {
            $vmsRegisteredCount = 0
        }
        $output | Add-Member -Type NoteProperty -Name "Registered" -Value ($vmsRegisteredCount)
        $output | Add-Member -Type NoteProperty -Name "Created" -Value ($vmCreationsCount)
        $output | Add-Member -Type NoteProperty -Name "Removed" -Value ($vmDeletionCount)
        
        #LogThis -msg $output
        $output
        $i-- 
    } while ($i -ge $upToMonth) 
#}

#$report | Export-Csv $of -NoTypeInformation
ExportCSV -obj $report
if ($global:showDate) {
	AppendToCSVFile -msg ""
	AppendToCSVFile -msg ""
	AppendToCSVFile -msg "Collected on $global:runtime"
}
LogThis -msg "Logs written to " -ForegroundColor  yellow;

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}
LogThis -msg "Runtime stats"
LogThis -msg "(get-date) - $now"