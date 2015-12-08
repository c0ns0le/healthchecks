# This script exports common performance stats and outputs to 2 output document
# Output 1: It looks at averages, min and peak information for an entire period defined in variable "lastMonths"
# Output 2: It looks at averages, min and peak information for each month over the period defined in variable "lastMonths"
# for the entire period and averages out 
# Full compresensive list of metrics are available here: http://communities.vmware.com/docs/DOC-560
# maintained by: teiva.rodiere-at-gmail.com
# version: 3
#
#   Step 1) $srvconnection = get-vc <vcenterServer>
#	Step 2) Run this script using examples below
#			./get-Performance-Clusters.ps1 -srvconnection $srvconnection
#
param([object]$srvConnection="",
	[string]$logDir="output",
	[string]$comment="",
	[bool]$showDate=$false,
	[int]$lastMonths=6,
	[bool]$showSummary=$true,
	[bool]$showByMonth=$true,
	[string]$clusterName="",
	[bool]$includeThisMonthEvenIfNotFinished=$true,
	[Object[]]$mymetrics = ("cpu.reservedCapacity.average","cpu.usagemhz.average","cpu.usage.average","clusterServices.effectivecpu.average","mem.usage.average","mem.overhead.average","mem.consumed.average","clusterServices.effectivemem.average","cpu.totalmhz.average","mem.reservedCapacity.average","mem.granted.average","mem.active.average","mem.shared.average","mem.zero.average","mem.swapused.average","mem.vmmemctl.average","mem.compressed.average","mem.compressionRate.average","mem.decompressionRate.average","mem.totalmb.average","clusterServices.failover.latest")
	)
#[Object[]]$metrics = ($mymetrics = "cpu.usagemhz.average","cpu.usage.average","mem.usage.average","mem.totalmb.average","mem.consumed.average","mem.swapused.average","mem.vmmemctl.average","clusterServices.effectivemem.average")
Write-Host -msg "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global




# Want to initialise the module and blurb using this 1 function



$now = get-date #(get-date).AddMonths(-1) #use now but because we are half way thought the month, i only want up to the last day of the previous month
#$lastMonths = 6 # Overwrite default here 
#$lastDayOfMonth =  ((get-date).AddMonths(+1)) - (New-TimeSpan -seconds 1)
$i = $lastMonths
#
#

#$metrics = "cpu.usage.average","cpu.usage.average","mem.usage.average","mem.consumed.average","mem.swapused.average","mem.vmmemctl.average"
#$mymetrics = "cpu.usagemhz.average","cpu.usage.average","mem.usage.average","mem.consumed.average","mem.swapused.average","mem.vmmemctl.average"
#$mymetrics = "cpu.reservedCapacity.average","cpu.usagemhz.average","cpu.usage.average","clusterServices.effectivecpu.average","mem.usage.average","mem.overhead.average","mem.consumed.average","clusterServices.effectivemem.average","cpu.totalmhz.average","mem.reservedCapacity.average","mem.granted.average","mem.active.average","mem.shared.average","mem.zero.average","mem.swapused.average","mem.vmmemctl.average","mem.compressed.average","mem.compressionRate.average","mem.decompressionRate.average","mem.totalmb.average","clusterServices.failover.latest"
#$mycpumetrics = "cpu.reservedCapacity.average","cpu.usagemhz.average","cpu.usage.average","cpu.totalmhz.average"
#$mymemmetrics = "mem.usage.average","mem.consumed.average","mem.totalmb.average","mem.active.average","mem.shared.average"
#$mymemmotheretrics = "mem.zero.average","mem.swapused.average","mem.vmmemctl.average","mem.compressed.average","mem.compressionRate.average","mem.decompressionRate.average","mem.overhead.average"
#$myclusterservicesmetrics = "clusterServices.effectivecpu.average","clusterServices.effectivemem.average","clusterServices.failover.latest"
# This section gets cluster performance stats for the entire period and averages out 
if ($clusterName)
{
	$clusters = get-cluster -Name $clusterName -Server $srvConnection
} else {
	$clusters = get-cluster * -Server $srvConnection
}

if (!$clusters)
{
	logThis -msg "Invalid clusters"
	exit
}
if ($showSummary) {
    $run1Report = $clusters | %{
        $output = "" | Select "Cluster"
        logThis -msg "Processing Cluster $($_.Name)..." -foregroundcolor Green
        logThis -msg "Collecting stats for the past $lastMonths Months..." -foregroundcolor Green
        $output.Cluster = $_.Name
        $cluster = $_
    	$LastDayOfLastMonth = get-date ([System.DateTime]::DaysInMonth($(get-date).Year, $($(get-date).Month - 1)) + "/"+ (get-date).AddMonths(-1).Month + "/" + (get-date).AddMonths(-1).Year)
		$firstDayOfMonth = get-date ("1/" + (Get-Date $date).Month + "/" + (Get-Date $date).Year + " 24:59:59")
		if ($includeThisMonthEvenIfNotFinished)
		{
			$stats= $_ | get-stat -Stat $mymetrics -Start (get-date).AddMonths(-$lastMonths) -Finish (get-date) -MaxSamples ([int]::MaxValue)
		} else {
			$stats= $_ | get-stat -Stat $mymetrics -Start (get-date).AddMonths(-$lastMonths) -Finish (get-date) -MaxSamples ([int]::MaxValue)
		}
        #logThis -msg $stats
        $metrics = $stats | Select MetricId -unique
        $metrics | %{
            $metric = $_.MetricId
            $category,$type,$measure = $metric.Split(".")
            logThis -msg "`tProcessing metric id $metric..." -Foregroundcolor Yellow
            #$hostStats = $stats | ?{$_.MetricId -match $metric}  | Measure-Object value -average -maximum -minimum
            $statsForthisMatrix = $stats | ?{$_.MetricId -match $metric}
            $unit = $statsForthisMatrix[0].Unit
            $hostStats = $statsForthisMatrix  | Measure-Object value -average -maximum -minimum
            if($unit -eq "%")
            {
                $output | Add-Member -Type NoteProperty -Name $("Avg " + $category.toupper() +" " + $type.ToUpper() + "($unit)") -Value "$([math]::ROUND($hostStats.Average,2))%"
                $output | Add-Member -Type NoteProperty -Name $("Peak " + $category.toupper() +" " + $type.ToUpper() + "($unit)") -Value "$([math]::ROUND($hostStats.Maximum,2))%"
                $output | Add-Member -Type NoteProperty -Name $("Min " + $category.toupper() +" " + $type.ToUpper() + "($unit)") -Value "$([math]::ROUND($hostStats.Minimum,2))%"
            } elseif ($unit -eq "KB")
            {
                $output | Add-Member -Type NoteProperty -Name $("Avg " + $category.toupper() +" " + $type.ToUpper() + "(GB)") -Value "$([math]::ROUND($hostStats.Average / 1024 / 1024,2))"
                $output | Add-Member -Type NoteProperty -Name $("Peak " + $category.toupper() +" " + $type.ToUpper() + "(GB)") -Value "$([math]::ROUND($hostStats.Maximum / 1024 / 1024,2))"
                $output | Add-Member -Type NoteProperty -Name $("Min " + $category.toupper() +" " + $type.ToUpper() + "(GB)") -Value "$([math]::ROUND($hostStats.Minimum / 1024 / 1024,2))"
            } elseif ($unit -eq "MB")
            {
                $output | Add-Member -Type NoteProperty -Name $("Avg " + $category.toupper() +" " + $type.ToUpper() + "(GB)") -Value "$([math]::ROUND($hostStats.Average / 1024,2))"
                $output | Add-Member -Type NoteProperty -Name $("Peak " + $category.toupper() +" " + $type.ToUpper() + "(GB)") -Value "$([math]::ROUND($hostStats.Maximum / 1024,2))"
                $output | Add-Member -Type NoteProperty -Name $("Min " + $category.toupper() +" " + $type.ToUpper() + "(GB)") -Value "$([math]::ROUND($hostStats.Minimum / 1024,2))"
            } elseif ($unit -eq "KBps")
            {
                $output | Add-Member -Type NoteProperty -Name $("Avg " + $category.toupper() +" " + $type.ToUpper() + "(MBps)") -Value "$([math]::ROUND($hostStats.Average / 1024,2))"
                $output | Add-Member -Type NoteProperty -Name $("Peak " + $category.toupper() +" " + $type.ToUpper() + "(MBps)") -Value "$([math]::ROUND($hostStats.Maximum / 1024,2))"
                $output | Add-Member -Type NoteProperty -Name $("Min " + $category.toupper() +" " + $type.ToUpper() + "(MBps)") -Value "$([math]::ROUND($hostStats.Minimum / 1024,2))"
            } elseif ($unit -eq "seconds")
            {
                $output | Add-Member -Type NoteProperty -Name $("Avg " + $category.toupper() +" " + $type.ToUpper() + "(Days)") -Value "$([math]::ROUND($hostStats.Average / 60  / 60 / 60,2))"
                $output | Add-Member -Type NoteProperty -Name $("Peak " + $category.toupper() +" " + $type.ToUpper() + "(Days)") -Value "$([math]::ROUND($hostStats.Maximum / 60  / 60 / 60,2))"
                $output | Add-Member -Type NoteProperty -Name $("Min " + $category.toupper() +" " + $type.ToUpper() + "(Days)") -Value "$([math]::ROUND($hostStats.Minimum / 60  / 60 / 60,2))"
            } elseif ($unit -eq "number")
            {
                $output | Add-Member -Type NoteProperty -Name $("Avg " + $category.toupper() +" " + $type.ToUpper() + "(hosts)") -Value "$([math]::ROUND($hostStats.Average,2))"
                $output | Add-Member -Type NoteProperty -Name $("Peak " + $category.toupper() +" " + $type.ToUpper() + "(hosts)") -Value "$([math]::ROUND($hostStats.Maximum,2))"
                $output | Add-Member -Type NoteProperty -Name $("Min " + $category.toupper() +" " + $type.ToUpper() + "(hosts)") -Value "$([math]::ROUND($hostStats.Minimum,2))"
            } else {
                $output | Add-Member -Type NoteProperty -Name $("Avg " + $category.toupper() +" " + $type.ToUpper() + "($unit)") -Value "$([math]::ROUND($hostStats.Average,2))"
                $output | Add-Member -Type NoteProperty -Name $("Peak " + $category.toupper() +" " + $type.ToUpper() + "($unit)") -Value "$([math]::ROUND($hostStats.Maximum,2))"
                $output | Add-Member -Type NoteProperty -Name $("Min " + $category.toupper() +" " + $type.ToUpper() + "($unit)") -Value "$([math]::ROUND($hostStats.Minimum,2))"
            }
            #$output | Add-Member -Type NoteProperty -Name $($category.toupper() +" " + $type.ToUpper() + " Avg") -Value $hostStats.Average
            #$output | Add-Member -Type NoteProperty -Name $($category.toupper() +" " + $type.ToUpper() + " Peak") -Value $hostStats.Maximum
            #$output | Add-Member -Type NoteProperty -Name $($category.toupper() +" " + $type.ToUpper() + " Min") -Value $hostStats.Minimum
        }
        
        logThis -msg $output
        $output 
        #$reportPeriod +=$output   
    }
	       #$report | export-csv $of -NoTypeInformation
		#
		# Fix the object array, ensure all objects within the 
		# array contain the same members (required for Format-Table / Export-CSV)
		 
		$Members = $run1Report | Select-Object `
		  @{n='MemberCount';e={ ($_ | Get-Member).Count }}, `
		  @{n='Members';e={ $_.PsObject.Properties | %{ $_.Name } }}
		$AllMembers = ($Members | Sort-Object MemberCount -Descending)[0].Members

		#ForEach ($Entry in $run1Report) {
		  #ForEach ($Member in $AllMembers)
		  #{
		    #If (!($Entry | Get-Member -Name $Member))
		    #{ 
		      #$Entry | Add-Member -Type NoteProperty -Name $Member -Value ""
		    #}
		  #}
		#}

		$Report = $run1Report | %{
		  ForEach ($Member in $AllMembers)
		  {
		    If (!($_ | Get-Member -Name $Member))
		    { 
		      $_ | Add-Member -Type NoteProperty -Name $Member -Value ""
		    }
		  }
		  Write-Output $_
		}
        $Report | Export-Csv $of -NoTypeInformation
        logThis -msg "Runtime stats for by Month Breakdown"
        (get-date) - $now
    $report | export-csv $of -NoTypeInformation
    logThis -msg "Cluster Performance Runtime stats"
    (get-date) - $now
}

# Monthly breakdown
$i = $lastMonths
$thelastMonth = 1
if ($includeThisMonthEvenIfNotFinished)
{
	$thelastMonth = 0
}

if ($showByMonth)
{
    #$clusters = get-cluster -Server $srvconnection
    logThis -msg "Collecting stats on a monthly basis for the past $lastMonths Months..." -foregroundcolor Green
    $clusters | %{
        $i = $lastMonths
        $cluster = $_    
        $of = $logDir + "\"+$filename+"-Last"+$lastMonths+"Months-"+$cluster.Name.replace(" ","_")+".csv"
        logThis -msg "stats for cluster ""$cluster"" will output to " $of -ForegroundColor Yellow 
        $run1Report = do {
            $date = $now.AddMonths(-$i)
            $output = "" | Select "Months"
            $output.Months = (get-date $date -format y)
            $firstDayOfMonth = get-date ("1/" + (Get-Date $date).Month + "/" + (Get-Date $date).Year + " 00:00:00")
            $lastDayOfMonth =  ($firstDayOfMonth.AddMonths(+1)) - (New-TimeSpan -seconds 1)
            logThis -msg "Processing stats for $(Get-date $lastDayOfMonth -format y)" -Foregroundcolor Green
    #/*
    #cpu.reservedCapacity.average
    #mem.reservedCapacity.average
    #mem.granted.average
    #mem.active.average
    #mem.shared.average
    #mem.zero.average
    #mem.swapused.average
    #mem.vmmemctl.average
    #mem.compressed.average
    #mem.compressionRate.average
    #mem.decompressionRate.average
    #power.power.average
    #cpu.usagemhz.average
    #cpu.usage.average
    #mem.usage.average
    #mem.overhead.average
    #vmem.consumed.average
    #clusterServices.effectivecpu.average
    #clusterServices.effectivemem.average
    #cpu.totalmhz.average
    #mem.totalmb.average
    #clusterServices.failover.latest
    #vmop.numPoweron.latest
    #vmop.numPoweroff.latest
    #vmop.numSuspend.latest
    #vmop.numReset.latest
    #vmop.numRebootGuest.latest
    #vmop.numStandbyGuest.latest
    #vmop.numShutdownGuest.latest
    #vmop.numCreate.latest
    #vmop.numDestroy.latest
    #vmop.numRegister.latest
    #vmop.numUnregister.latest
    #vmop.numReconfigure.latest
    #vmop.numClone.latest
    #vmop.numDeploy.latest
    #vmop.numChangeHost.latest
    #vmop.numChangeDS.latest
    #vmop.numChangeHostDS.latest
    #vmop.numVMotion.latest
    #vmop.numSVMotion.latest
    #*/
            #$mymetrics = "cpu.usagemhz.average","cpu.usage.average","mem.usage.average","mem.totalmb.average","mem.consumed.average","mem.swapused.average","mem.vmmemctl.average","clusterServices.effectivemem.average"
            $stats = $cluster | Get-Stat  -Stat $mymetrics -Start (get-date $firstDayOfMonth -format d) -Finish (get-date $lastDayOfMonth -format d) -MaxSamples ([int]::MaxValue)
            $metrics = $stats | Select MetricId -unique
            $metrics | %{
                $metric = $_.MetricId            
                $category,$type,$measure = $metric.Split(".")
                logThis -msg "`tProcessing metric id $metric..." -Foregroundcolor Yellow
                $statsForthisMatrix = $stats | ?{$_.MetricId -match $metric}  #| Measure-Object value -average -maximum -minimum
                $unit = $statsForthisMatrix[0].Unit
                $hostStats = $statsForthisMatrix  | Measure-Object value -average -maximum -minimum
                if($unit -eq "%")
                {
                    $output | Add-Member -Type NoteProperty -Name $("Avg " + $category.toupper() +" " + $type.ToUpper() + "($unit)") -Value "$([math]::ROUND($hostStats.Average,2))%"
                    $output | Add-Member -Type NoteProperty -Name $("Peak " + $category.toupper() +" " + $type.ToUpper() + "($unit)") -Value "$([math]::ROUND($hostStats.Maximum,2))%"
                    $output | Add-Member -Type NoteProperty -Name $("Min " + $category.toupper() +" " + $type.ToUpper() + "($unit)") -Value "$([math]::ROUND($hostStats.Minimum,2))%"
                } elseif ($unit -eq "KB")
                {
                    $output | Add-Member -Type NoteProperty -Name $("Avg " + $category.toupper() +" " + $type.ToUpper() + "(GB)") -Value "$([math]::ROUND($hostStats.Average / 1024 / 1024,2))"
                    $output | Add-Member -Type NoteProperty -Name $("Peak " + $category.toupper() +" " + $type.ToUpper() + "(GB)") -Value "$([math]::ROUND($hostStats.Maximum / 1024 / 1024,2))"
                    $output | Add-Member -Type NoteProperty -Name $("Min " + $category.toupper() +" " + $type.ToUpper() + "(GB)") -Value "$([math]::ROUND($hostStats.Minimum / 1024 / 1024,2))"
                } elseif ($unit -eq "MB")
                {
                    $output | Add-Member -Type NoteProperty -Name $("Avg " + $category.toupper() +" " + $type.ToUpper() + "(GB)") -Value "$([math]::ROUND($hostStats.Average / 1024,2))"
                    $output | Add-Member -Type NoteProperty -Name $("Peak " + $category.toupper() +" " + $type.ToUpper() + "(GB)") -Value "$([math]::ROUND($hostStats.Maximum / 1024,2))"
                    $output | Add-Member -Type NoteProperty -Name $("Min " + $category.toupper() +" " + $type.ToUpper() + "(GB)") -Value "$([math]::ROUND($hostStats.Minimum / 1024,2))"
                } elseif ($unit -eq "KBps")
                {
                    $output | Add-Member -Type NoteProperty -Name $("Avg " + $category.toupper() +" " + $type.ToUpper() + "(MBps)") -Value "$([math]::ROUND($hostStats.Average / 1024,2))"
                    $output | Add-Member -Type NoteProperty -Name $("Peak " + $category.toupper() +" " + $type.ToUpper() + "(MBps)") -Value "$([math]::ROUND($hostStats.Maximum / 1024,2))"
                    $output | Add-Member -Type NoteProperty -Name $("Min " + $category.toupper() +" " + $type.ToUpper() + "(MBps)") -Value "$([math]::ROUND($hostStats.Minimum / 1024,2))"
                } elseif ($unit -eq "seconds")
                {
                    $output | Add-Member -Type NoteProperty -Name $("Avg " + $category.toupper() +" " + $type.ToUpper() + "(Days)") -Value "$([math]::ROUND($hostStats.Average / 60  / 60 / 60,2))"
                    $output | Add-Member -Type NoteProperty -Name $("Peak " + $category.toupper() +" " + $type.ToUpper() + "(Days)") -Value "$([math]::ROUND($hostStats.Maximum / 60  / 60 / 60,2))"
                    $output | Add-Member -Type NoteProperty -Name $("Min " + $category.toupper() +" " + $type.ToUpper() + "(Days)") -Value "$([math]::ROUND($hostStats.Minimum / 60  / 60 / 60,2))"
                }  elseif ($unit -eq "number")
                {
                    $output | Add-Member -Type NoteProperty -Name $("Avg " + $category.toupper() +" " + $type.ToUpper() + "(hosts)") -Value "$([math]::ROUND($hostStats.Average,2))"
                    $output | Add-Member -Type NoteProperty -Name $("Peak " + $category.toupper() +" " + $type.ToUpper() + "(hosts)") -Value "$([math]::ROUND($hostStats.Maximum,2))"
                    $output | Add-Member -Type NoteProperty -Name $("Min " + $category.toupper() +" " + $type.ToUpper() + "(hosts)") -Value "$([math]::ROUND($hostStats.Minimum,2))"
                } else {
                    $output | Add-Member -Type NoteProperty -Name $("Avg " + $category.toupper() +" " + $type.ToUpper() + "($unit)") -Value "$([math]::ROUND($hostStats.Average,2))"
                    $output | Add-Member -Type NoteProperty -Name $("Peak " + $category.toupper() +" " + $type.ToUpper() + "($unit)") -Value "$([math]::ROUND($hostStats.Maximum,2))"
                    $output | Add-Member -Type NoteProperty -Name $("Min " + $category.toupper() +" " + $type.ToUpper() + "($unit)") -Value "$([math]::ROUND($hostStats.Minimum,2))"
                }
            }
                  
            
            #$cpuMhzStat = $cluster | Get-Stat -Start (get-date $firstDayOfMonth -format d) -Finish (get-date $lastDayOfMonth -format d) -Stat cpu.usagemhz.average  -MaxSamples ([int]::MaxValue) | Measure-Object value -average -maximum -minimum
            #$cpuUsageStat = $cluster | Get-Stat -Start (get-date $firstDayOfMonth -format d) -Finish (get-date $lastDayOfMonth -format d) -Stat cpu.usage.average  -MaxSamples ([int]::MaxValue) | Measure-Object value -average -maximum -minimum
            #$memoryStat = $cluster | Get-Stat -Start (get-date $firstDayOfMonth -format d) -Finish (get-date $lastDayOfMonth -format d)  -Stat mem.usage.average  -MaxSamples ([int]::MaxValue) | Measure-Object value -average -maximum -minimum
            #$memoryStat = $cluster | Get-Stat -Start (get-date $firstDayOfMonth -format d) -Finish (get-date $lastDayOfMonth -format d)  -Stat mem.consumed.average -MaxSamples ([int]::MaxValue) | Measure-Object value -average -maximum -minimum

            #$stats = $cluster | Get-Stat -Cpu -Start (get-date $firstDayOfMonth -format d) -Finish (get-date $lastDayOfMonth -format d) -MaxSamples ([int]::MaxValue)
            #$stats > ".\output\clusterperfs-stats_$($cluster.name.replace(" ","-")) _ $((get-date $firstDayOfMonth -format y).replace(" ","-")).csv"
            
            #$output | Add-Member -Type NoteProperty -Name "Avg CPU" -Value "$([math]::ROUND($cpuUsageStat.Average,2))%"
            #$output | Add-Member -Type NoteProperty -Name "Avg Peak CPU" -Value "$([math]::ROUND($cpuUsageStat.Maximum,2))%"
            #$output | Add-Member -Type NoteProperty -Name "Avg Min CPU " -Value "$([math]::ROUND($cpuUsageStat.Minimum,2))%"
            
            #$output | Add-Member -Type NoteProperty -Name "Avg CPU Mhz" -Value "$([math]::ROUND($cpuMhzStat.Average,2))Mhz"
            #$output | Add-Member -Type NoteProperty -Name "Avg Peak CPU Mhz" -Value "$([math]::ROUND($cpuMhzStat.Maximum,2))Mhz"
            #$output | Add-Member -Type NoteProperty -Name "Avg Min PU Mhz" -Value "$([math]::ROUND($cpuMhzStat.Minimum,2))Mhz"
            
            #$output | Add-Member -Type NoteProperty -Name "Avg Mem Usage" -Value "$([math]::ROUND($memoryStat.Average,2))%"
            #$output | Add-Member -Type NoteProperty -Name "Avg Mem Usage" -Value "$([math]::ROUND($memoryStat.Maximum,2))%"
            #$output | Add-Member -Type NoteProperty -Name "Avg Mem Usage" -Value "$([math]::ROUND($memoryStat.Minimum,2))%"        
            logThis -msg $output
            $output
            
            $i-- 
        } while ($i -ge $thelastMonth) 
        #$report | export-csv $of -NoTypeInformation
		#
		# Fix the object array, ensure all objects within the 
		# array contain the same members (required for Format-Table / Export-CSV)
		 
		$Members = $run1Report | Select-Object `
		  @{n='MemberCount';e={ ($_ | Get-Member).Count }}, `
		  @{n='Members';e={ $_.PsObject.Properties | %{ $_.Name } }}
		$AllMembers = ($Members | Sort-Object MemberCount -Descending)[0].Members

		#ForEach ($Entry in $run1Report) {
		  #ForEach ($Member in $AllMembers)
		  #{
		    #If (!($Entry | Get-Member -Name $Member))
		    #{ 
		      #$Entry | Add-Member -Type NoteProperty -Name $Member -Value ""
		    #}
		  #}
		#}

		$Report = $run1Report | %{
		  ForEach ($Member in $AllMembers)
		  {
		    If (!($_ | Get-Member -Name $Member))
		    { 
		      $_ | Add-Member -Type NoteProperty -Name $Member -Value ""
		    }
		  }
		  Write-Output $_
		}
        ExportCSV -table $Report 
        logThis -msg "Runtime stats for by Month Breakdown"
        (get-date) - $now
    }
}


logThis -msg "Logs written to " $of -ForegroundColor  yellow;

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}
logThis -msg "Total Runtime stats"
(get-date) - $now