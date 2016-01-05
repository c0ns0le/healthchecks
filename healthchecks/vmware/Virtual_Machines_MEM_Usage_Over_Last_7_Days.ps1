# Simply gathers Memory Usage Report from all VMs for the past 7 Days @  5 minute intervals
param([object]$srvConnection="",
	[string]$logDir="output",
	[string]$comment="",
	[int]$numsamples=([int]::MaxValue),
	[int]$numPastDays=7,
	[bool]$verbose=$true,
	[int]$sampleIntevalsMinutes=5,
	[string]$statName="mem.usage.average",
	[bool]$poweredOnOnly=$true,
	[int]$headerType=1
)
Write-Host "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global




# Want to initialise the module and blurb using this 1 function


$report = @()

# Grab datastore and find VMs on that datastore
#$myDatastore = Get-Datastore -Name $datastore -server $server
$report = $srvconnection | %{
	if ($poweredOnOnly)
	{
		$myVMs = Get-VM * -server $_ | Where {$_.PowerState -eq "PoweredOn"}
	} else {
		$myVMs = Get-VM * -server $_ #| Where {$_.PowerState -eq "PoweredOn"}
	}
	LogThis -msg "$($myVMs.Count) Powered On found in $_" -ForegroundColor $global:colours.Information
	$vmIndex=1;
	$myVMs | sort -Property Name | %{
		$vm = $_;	
		# Gather current IO snapshot for each VM
		LogThis -msg "$vmIndex/$($myVMs.Count) :- $($vm.Name)"
		$row = "" | Select "VM"
		$row."VM" = $vm.name
		$row | Add-Member -Type NoteProperty -Name "State" -Value $vm.PowerState
		$row | Add-Member -Type NoteProperty -Name "Size (GB)" -Value (formatNumbers $vm.MemoryGB)
		#$row | Add-Member -Type NoteProperty -Name "Interval (minutes)" = ($numsamples*20)/60
		$stats=@();
		#$row | Add-Member -Type NoteProperty -Name "Interval (minutes)" = 
		#$stats = Get-Stat -Entity $vm -Stat disk.numberWrite.summation -MaxSamples $numsamples -Start (Get-Date).AddDays(-$numPastDays)
		$stats = Get-Stat -Entity $vm -Stat $statName -MaxSamples $numsamples -Start (Get-Date).AddDays(-$numPastDays) -IntervalMins $sampleIntevalsMinutes
		$metaInfo = @()
		$metaInfo +="tableHeader=VMs By Memory Usage (%): Last 7 Days"
		if ($poweredOnOnly)
		{
			$metaInfo +="introduction=The table below contains memory usage(%) results for powered on only Virtual Machines in your environment for the reported period. The amount of memory used that is actively used by each virtual machine compared with the memory size configured."
		} else {
			$metaInfo +="introduction=The table below contains memory usage(%) results for both powered on and powered off Virtual Machines in your environment for the reported period. The amount of memory used that is actively used by each virtual machine compared with the memory size configured."
		}
		$metaInfo +="chartable=false"
		$metaInfo +="titleHeaderType=h$($headerType)"
		
		#$stats = Get-Stat -Entity $vm -Stat disk.read.average -Start (Get-Date).AddDays(-$numPastDays)
		if ($stats)
		{
			$statsMeasured=$stats | measure -Property Value -Sum -Average -Maximum -Minimum
			$row | Add-Member -Type NoteProperty -Name "Average" -Value (formatNumbers $statsMeasured.Average)
			$row | Add-Member -Type NoteProperty -Name "Peak" -Value (formatNumbers $statsMeasured.Maximum)
			$row | Add-Member -Type NoteProperty -Name "Minimum" -Value (formatNumbers $statsMeasured.Minimum)
		} else {
			$row | Add-Member -Type NoteProperty -Name "Average" -Value $(printNoData)
			$row | Add-Member -Type NoteProperty -Name "Peak" -Value $(printNoData)
			$row | Add-Member -Type NoteProperty -Name "Minimum" -Value $(printNoData)
		}
		LogThis -msg $row
		$row;
		$vmIndex++;
	}
}

#$report
ExportCSV -table $report -sortBy "VM"
ExportMetaData -metadata $metaInfo

#launchReport

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
	LogThis -msg  "-> Disconnected from $srvConnection <-"
}