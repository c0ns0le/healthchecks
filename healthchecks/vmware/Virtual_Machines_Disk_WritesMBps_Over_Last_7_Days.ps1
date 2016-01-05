# Simply gathers Disk Writes stats in MBps from all VMs for the past 7 Days
# GatherIOPS.ps1 -srvconnection $srvconnection
param(
	[object]$srvConnection="",
	[string]$logDir="output",
	[string]$comment="",
	[int]$numsamples=([int]::MaxValue),
	[int]$numPastDays=7,
	[bool]$verbose=$true,
	[int]$sampleIntevalsMinutes=5,
	[int]$headerType=1
)
$silencer = Import-Module -Name .\vmwareModules.psm1 -Force -PassThru -Verbose:$false
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global

# Want to initialise the module and blurb using this 1 function

$metaInfo = @()
$metaInfo +="tableHeader=VMs By Disk Writes (MBps): Last 7 Days"
$metaInfo +="introduction=Average number of Megabytes written to disk each second during the collection interval."
$metaInfo +="chartable=false"
$metaInfo +="titleHeaderType=h$($headerType)"

$allPoweredOnVMs = getVMs -server $srvconnection | Where {$_.PowerState -eq "PoweredOn"} | Sort Name

# Grab datastore and find VMs on that datastore
#$myDatastore = Get-Datastore -Name $datastore -server $server
$vmIndex=1;
$dataTable = $allPoweredOnVMs | %{
	$vm = $_;	
	LogThis -msg "$vmIndex/$($allPoweredOnVMs.Count) :- $($vm.Name)"
	Write-Progress -Id 1 -Activity "Processing stats $($vm.Name) " -CurrentOperation "$vmIndex/$($allPoweredOnVMs.Count)" -PercentComplete $($vmIndex/$($allPoweredOnVMs.Count)*100)
	$row = "" | Select "VM"
	$row."VM" = $vm.name
	#$row | Add-Member -Type NoteProperty -Name "Interval (minutes)" = ($numsamples*20)/60
	$stats=@();
	#$row | Add-Member -Type NoteProperty -Name "Interval (minutes)" = 
	#$stats = Get-Stat -Entity $vm -Stat disk.numberWrite.summation -MaxSamples $numsamples -Start (Get-Date).AddDays(-$numPastDays)
	$stats = Get-Stat -Entity $vm -Stat disk.write.average -MaxSamples $numsamples -Start (Get-Date).AddDays(-$numPastDays) -IntervalMins $sampleIntevalsMinutes	
	#$stats = Get-Stat -Entity $vm -Stat disk.write.average -Start (Get-Date).AddDays(-$numPastDays)
	$average=0
	$peak=0
	$min=0
	if ($stats)
	{
		$statsMeasured = $stats | measure -Property Value -Sum -Average -Maximum -Minimum
		$average="$([math]::Round($statsMeasured.Average / 1024,2))"	
		$peak= "$([math]::Round($statsMeasured.Maximum / 1024,2))"
		$min="$([math]::Round($statsMeasured.Minimum / 1024,2))"
		#$row | Add-Member -Type NoteProperty -Name "Avg Write IOPS" = GetAvgStat -vmhost $vm.host.name -vm $vm.name -ds $datastore -samples $numsamples -stat disk.numberWrite.summation
		
		#$row | Add-Member -Type NoteProperty -Name "Write Samples " -Value "$($statsMeasured.Count) samples over $numPastDays Days at $interval minutes intervals"
		#$row | Add-Member -Type NoteProperty -Name "Write Stats Description"  -Value $($stats[0].Description.replace("kilobytes","Megabytes"));
		#$row | Add-Member -Type NoteProperty -Name "Avg Read IOPS" = GetAvgStat -vmhost $vm.host.name -vm $vm.name -ds $datastore -samples $numsamples -stat disk.numberRead.summation		
	}
	$row | Add-Member -Type NoteProperty -Name "Average" -Value $average
	$row | Add-Member -Type NoteProperty -Name "Peak" -Value $peak
	$row | Add-Member -Type NoteProperty -Name "Minimum" -Value $min
	#$interval = -$($stats[1].Timestamp - $stats[0].Timestamp).TotalSeconds/60
	$row;
	$vmIndex++;
}


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
	LogThis -msg  "-> Disconnected from $srvConnection <-"
}