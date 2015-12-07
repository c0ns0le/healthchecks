param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$showDate=$false,[int]$lastMonths=3)
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global
$global:logfile
$global:outputCSV

# Want to initialise the module and blurb using this 1 function
#InitialiseModule

$now = get-date #(get-date).AddMonths(-1) #use now but because we are half way thought the month, i only want up to the last day of the previous month
#$lastMonths = 12 # Overwrite default here 

$i = $lastMonths
$clusters = get-cluster -Server $srvconneciton
$date = $now.AddMonths(-$lastMonths)
$output = "" | Select "Months"
$output.Months = (get-date $date -format y)
$firstDayOfMonth = get-date ("1/" + (Get-Date $date).Month + "/" + (Get-Date $date).Year + " 00:00:00")
$lastDayOfMonth =  ((get-date).AddMonths(+1)) - (New-TimeSpan -seconds 1)
logThis -msg "loading all events pertaining to creations and deletions from $srvconnection"

#Task: Create virtual machine snapshot
#Task: Remove all snapshots
#Task: Remove snapshot
#Task: Revert snapshot
#Task: Revert to current snapshot

$viEvents = Get-VIEvent -Start $firstDayOfMonth -Finish $lastDayOfMonth -Types info -MaxSamples ([int]::MaxValue)  | Where { $_.Info.Name -eq "RemoveSnapshot_Task" -or $_.Info.Name -eq "CreateSnapshot_Task" -or $_.Gettype().Name -eq "RevertToSnapshot_Task"}
$viEvents  | Export-csv ".\output\snapshotsEvents.csv"

#$report = $clusters | %{
    #$cluster = $_    
    #$of = $logDir + "\"+$filename+"-"+$cluster.Name.replace(" ","_")+".csv"
    #logThis -msg "The stats for cluster ""$cluster"" will output to " $of -ForegroundColor Yellow 
    $report = do {
        $date = $now.AddMonths(-$i)
        $output = "" | Select "Months"
        $output.Months = (get-date $date -format y)
        $firstDayOfMonth = get-date ("1/" + (Get-Date $date).Month + "/" + (Get-Date $date).Year + " 00:00:00")
        $lastDayOfMonth =  ($firstDayOfMonth.AddMonths(+1)) - (New-TimeSpan -seconds 1)

        #$vIEvents = Get-VIEvent -Start $firstDayOfMonth -Finish $lastDayOfMonth -MaxSamples ([int]::MaxValue) -Server $srvConnections | ?{$_.Vm -and $_.FullFormattedMessage -match "Deploying"}
        $snapshotDelete = $viEvents  | Where { $_.Info.Name -ne "RemoveSnapshot_Task" -and (get-date $_.Createdtime).Month -eq (Get-Date $date).Month}
        $snapshotCreate = $viEvents  | Where { $_.Info.Name -eq "CreateSnapshot_Task" -and (get-date $_.Createdtime).Month -eq (Get-Date $date).Month}
        $snapshotRevert = $viEvents  | Where { $_.Info.Name -eq "RevertToSnapshot_Task" -and (get-date $_.Createdtime).Month -eq (Get-Date $date).Month}
        
        if ($snapshotDelete) {
            if (!$snapshotDelete.Count) {
                $snapshotDeleteCount = 1
            } else {
                $snapshotDeleteCount = $snapshotDelete.Count
            } 
        } else {
            $snapshotDeleteCount = 0
        }
        
        if ($snapshotCreate) {
            if (!$snapshotCreate.Count) {
                $snapshotCreateCount = 1
            } else {
                $snapshotCreateCount = $snapshotCreate.Count
            }
        } else {
            $snapshotCreateCount = 0
        }
        
        f ($snapshotRevert) {
            if (!$snapshotRevert.Count) {
                $snapshotRevertCount = 1
            } else {
                $snapshotRevertCount = $snapshotRevert.Count
            }
        } else {
            $snapshotRevertCount = 0
        }
        $output | Add-Member -Type NoteProperty -Name "Deleted" -Value ($snapshotDeleteCount)
        $output | Add-Member -Type NoteProperty -Name "Created" -Value ($snapshotCreateCount)
        $output | Add-Member -Type NoteProperty -Name "Reverted" -Value ($snapshotRevertCount)
        
        logThis -msg $output
        $output
        $i-- 
    } while ($i -ge 1) 
#}

ExportCSV -table $report 
logThis -msg "Logs written to " $of -ForegroundColor  yellow;

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}
logThis -msg "Runtime stats"
(get-date) - $now