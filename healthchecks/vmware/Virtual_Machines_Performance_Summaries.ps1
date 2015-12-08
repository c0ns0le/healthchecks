#
#
#
#	NOT PRODUCTION READY
#
#
#
#
# Simply gathers Disk Writes stats in MBps from all VMs for the past 7 Days
# GatherIOPS.ps1 -srvconnection $srvconnection
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[int]$numsamples=([int]::MaxValue),[int]$numPastDays=7,[bool]$verbose=$true,[int]$sampleIntevalsMinutes=5)
Write-Host "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global




# Want to initialise the module and blurb using this 1 function

$IOPSReport = @()

# Grab datastore and find VMs on that datastore
#$myDatastore = Get-Datastore -Name $datastore -server $server
setSectionHeader -type "h2" -title "Virtual Machines Resource Usage" -text "The section provides you with performance results for each of your Virtual Machines."
"disk.write.average","disk.read.average","disk.maxtotallatency.latest","cpu.ready.summation" | %{
	$metric=$_
	$device,$iotypes,$measure=$metric -split '.'	
	$IOPSReport = $srvconnection | %{
		$myVMs = Get-VM -server $_ | Where {$_.PowerState -eq "PoweredOn"} | Sort Name
		LogThis -msg "$($myVMs.Count) Powered On found in $_" -ForegroundColor Yellow
		$vmIndex=1;
		$myVMs | %{
			$vm = $_;
			LogThis -msg "$vmIndex/$($myVMs.Count) :- $($vm.Name)"
			$row = "" | Select "VM"
			$row."VM" = $vm.name
			$stats=@();
			$stats = Get-Stat -Entity $vm -Stat $metric -MaxSamples $numsamples -Start (Get-Date).AddDays(-$numPastDays) -IntervalMins $sampleIntevalsMinutes
			$unit=$stats[0].Unit
			if ($stats)
			{
				$metaInfo = @()
				$metaInfo +="tableHeader=$(formatHeaders $metric)s"
				$metaInfo +="introduction=This table presents a list of virtual machines and their $(formatHeaders $measure) $(formatHeaders $device) $(formatHeaders $iotypes)s over the past $numPastDays days. The list is orderded from the highest consumers of $(formatHeaders $iotypes) to the least. Description: $($stats[0].Description)"
				$metaInfo +="chartable=false"
				$metaInfo +="titleHeaderType=h4"				
				$statsMeasured = $stats | measure -Property Value -Sum -Average -Maximum -Minimum
				if ($unit -eq "%")
				{
				#$row | Add-Member -Type NoteProperty -Name "Avg Write IOPS" = GetAvgStat -vmhost $vm.host.name -vm $vm.name -ds $datastore -samples $numsamples -stat disk.numberWrite.summation
					$row | Add-Member -Type NoteProperty -Name "Average" -Value $("{0:N2} $unit" -F $statsMeasured.Average)
					$row | Add-Member -Type NoteProperty -Name "Peak" -Value $("{0:N2} $unit" -F $statsMeasured.Maximum)
					$row | Add-Member -Type NoteProperty -Name "Minimum" -Value $("{0:N2} $unit" -F $statsMeasured.Minimum)
				} elseif ($unit -like "bps") {
				#$row | Add-Member -Type NoteProperty -Name "Avg Write IOPS" = GetAvgStat -vmhost $vm.host.name -vm $vm.name -ds $datastore -samples $numsamples -stat disk.numberWrite.summation
					$row | Add-Member -Type NoteProperty -Name "Average" -Value getSpeed -totalKbps $statsMeasured.Average
					$row | Add-Member -Type NoteProperty -Name "Peak" -Value "$([math]::Round($statsMeasured.Maximum / 1024,2))"
					$row | Add-Member -Type NoteProperty -Name "Minimum" -Value "$([math]::Round($statsMeasured.Minimum / 1024,2))"
				}
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
	ExportCSV -table ($IOPSReport | sort "Average")
	ExportMetaData -metadata $metaInfo
}
	if ($srvConnection -and $disconnectOnExist) {
		Disconnect-VIServer $srvConnection -Confirm:$false;
		LogThis -msg  "-> Disconnected from $srvConnection <-"
	}