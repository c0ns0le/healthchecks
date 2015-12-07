# Simply gathers Disk Writes stats in MBps from all VMs for the past 7 Days
# GatherIOPS.ps1 -srvconnection $srvconnection
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[int]$numsamples=([int]::MaxValue),[int]$numPastDays=7,[bool]$verbose=$true,[int]$sampleIntevalsMinutes=5,[int]$headerType=1)
Write-Host "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global
$global:logfile
$global:outputCSV

# Want to initialise the module and blurb using this 1 function
#InitialiseModule

$IOPSReport = @()

# Grab datastore and find VMs on that datastore
#$myDatastore = Get-Datastore -Name $datastore -server $server
$IOPSReport = $srvconnection | %{
	$myVMs = Get-VM -server $_ | Where {$_.PowerState -eq "PoweredOn"} | Sort Name
	LogThis -msg "$($myVMs.Count) Powered On found in $_" -ForegroundColor Yellow
	$vmIndex=1;
	$myVMs | %{
		$vm = $_;	
		# Gather current IO snapshot for each VM
		#$dataArray = @()
		#foreach ($vm in $myVMs) {
		LogThis -msg "$vmIndex/$($myVMs.Count) :- $($vm.Name)"
		$row = "" | Select "VM"
		$row."VM" = $vm.name
		#$row | Add-Member -Type NoteProperty -Name "Interval (minutes)" = ($numsamples*20)/60
		$stats=@();
		#$row | Add-Member -Type NoteProperty -Name "Interval (minutes)" = 
		#$stats = Get-Stat -Entity $vm -Stat disk.numberWrite.summation -MaxSamples $numsamples -Start (Get-Date).AddDays(-$numPastDays)
		$stats = Get-Stat -Entity $vm -Stat disk.write.average -MaxSamples $numsamples -Start (Get-Date).AddDays(-$numPastDays) -IntervalMins $sampleIntevalsMinutes
		$metaInfo = @()
		$metaInfo +="tableHeader=VMs By Disk Writes (MBps): Last 7 Days"
		$metaInfo +="introduction=Average number of Megabytes written to disk each second during the collection interval."
		$metaInfo +="chartable=false"
		$metaInfo +="titleHeaderType=h$($headerType)"
		#$stats = Get-Stat -Entity $vm -Stat disk.write.average -Start (Get-Date).AddDays(-$numPastDays)
		if ($stats)
		{
			$statsMeasured = $stats | measure -Property Value -Sum -Average -Maximum -Minimum
			#$row | Add-Member -Type NoteProperty -Name "Avg Write IOPS" = GetAvgStat -vmhost $vm.host.name -vm $vm.name -ds $datastore -samples $numsamples -stat disk.numberWrite.summation
			$row | Add-Member -Type NoteProperty -Name "Average" -Value "$([math]::Round($statsMeasured.Average / 1024,2))"	
			$row | Add-Member -Type NoteProperty -Name "Peak" -Value "$([math]::Round($statsMeasured.Maximum / 1024,2))"
			$row | Add-Member -Type NoteProperty -Name "Minimum" -Value "$([math]::Round($statsMeasured.Minimum / 1024,2))"
			#$interval = -$($stats[1].Timestamp - $stats[0].Timestamp).TotalSeconds/60
			#$row | Add-Member -Type NoteProperty -Name "Write Samples " -Value "$($statsMeasured.Count) samples over $numPastDays Days at $interval minutes intervals"
			#$row | Add-Member -Type NoteProperty -Name "Write Stats Description"  -Value $($stats[0].Description.replace("kilobytes","Megabytes"));
			#$row | Add-Member -Type NoteProperty -Name "Avg Read IOPS" = GetAvgStat -vmhost $vm.host.name -vm $vm.name -ds $datastore -samples $numsamples -stat disk.numberRead.summation		
		}

		#$dataArray += $row
		if ($verbose) {LogThis -msg $row}
		#$dataArray;
		$row;
		$vmIndex++;
	}
}

#$IOPSReport
ExportCSV -table $IOPSReport
ExportMetaData -metadata $metaInfo
if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
	LogThis -msg  "-> Disconnected from $srvConnection <-"
}