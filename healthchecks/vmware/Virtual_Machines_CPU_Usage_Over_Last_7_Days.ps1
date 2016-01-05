# Simply gathers CPU Usage Report from all VMs for the past 7 Days @  5 minute intervals
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",
	[int]$numsamples=([int]::MaxValue),
	[int]$numPastDays=7,
	[bool]$verbose=$true,
	[int]$sampleIntevalsMinutes=5,
	[string]$statName="cpu.usage.average",
	[bool]$poweredOnOnly=$true,
	[int]$headerType=1
)
Write-Host "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global

if ($alternateFilename)
{
	$global:logfile = $alternateFilename	
}



# Want to initialise the module and blurb using this 1 function


$IOPSReport = @()

# Grab datastore and find VMs on that datastore
#$myDatastore = Get-Datastore -Name $datastore -server $server
$IOPSReport = $srvconnection | %{
	$myVMs = Get-VM * -server $_ | Where {$_.PowerState -eq "PoweredOn"}
	LogThis -msg "$($myVMs.Count) Powered On found in $_" -ForegroundColor $global:colours.Information
	$vmIndex=1;
	$myVMs | %{
		$vm = $_;	
		# Gather current IO snapshot for each VM
		#$dataArray = @()
		#foreach ($vm in $myVMs) {
		LogThis -msg "$vmIndex/$($myVMs.Count) :- $($vm.Name)"
		$row = "" | Select "VM"
		$row."VM" = $vm.name
		$row | Add-Member -Type NoteProperty -Name "State" -Value $vm.PowerState
		$row | Add-Member -Type NoteProperty -Name "CPU" -Value $vm.NumCPU
		#$row | Add-Member -Type NoteProperty -Name "Interval (minutes)" = ($numsamples*20)/60
		$stats=@();
		#$row | Add-Member -Type NoteProperty -Name "Interval (minutes)" = 
		#$stats = Get-Stat -Entity $vm -Stat disk.numberWrite.summation -MaxSamples $numsamples -Start (Get-Date).AddDays(-$numPastDays)
		$stats = Get-Stat -Entity $vm -Stat $statName -MaxSamples $numsamples -Start (Get-Date).AddDays(-$numPastDays) -IntervalMins $sampleIntevalsMinutes
		$metaInfo = @()
		$metaInfo +="tableHeader=VMs By CPU Usage (%): Last 7 Days"
		$metaInfo +="introduction=The table below CPU usage as a percentage during the interval."
		$metaInfo +="chartable=false"
		$metaInfo +="titleHeaderType=h$($headerType)"
		
		#$stats = Get-Stat -Entity $vm -Stat disk.read.average -Start (Get-Date).AddDays(-$numPastDays)
		if ($stats)
		{
			$statsMeasured=$stats | measure -Property Value -Sum -Average -Maximum -Minimum
			$row | Add-Member -Type NoteProperty -Name "Average" -Value $(formatNumbers $statsMeasured.Average)
			$row | Add-Member -Type NoteProperty -Name "Peak" -Value $(formatNumbers $statsMeasured.Maximum)
			$row | Add-Member -Type NoteProperty -Name "Minimum" -Value $(formatNumbers $statsMeasured.Minimum)
		} else {
			$row | Add-Member -Type NoteProperty -Name "Average" -Value "-"
			$row | Add-Member -Type NoteProperty -Name "Peak" -Value "-"
			$row | Add-Member -Type NoteProperty -Name "Minimum" -Value "-"
		}
		LogThis -msg $row
		$row;
		$vmIndex++;
	}
}

#$IOPSReport
ExportCSV -table $IOPSReport
if ($metaInfo)
{
	ExportMetaData -metadata $metaInfo
}

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
	LogThis -msg  "-> Disconnected from $srvConnection <-"
}