# Exports performance results for VMHosts
#Version : 0.1
#Updated : 3th Feb 2015
#Author  : teiva.rodiere@gmail.com
param([object]$srvConnection="",
	[string]$logDir="output",
	[string]$comment="",
	[bool]$showDate=$false,
	[int]$showPastMonths=6,
	[bool]$showIndividualDevicesStats=$false,
	[int]$maxsamples=([int]::MaxValue),
	[bool]$unleashAllStats=$false,
	[int]$headerType=1,
	[bool]$consolidateResults=$true
)

Write-Host -msg "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $global:srvConnection -Scope Global
$global:logfile
$global:outputCSV

# Want to initialise the module and blurb using this 1 function
InitialiseModule

$metaInfo = @()
$metaInfo +="tableHeader=Hypervisor Resource Usage"
$metaInfo +="introduction=The section provides you with performance results for each of your hypervisors. Review each host as part of your capacity planning session."
$metaInfo +="titleHeaderType=h$($headerType)"
$metaInfo +="titleHeaderType=h2"
#updateReportIndexer -string "$(split-path -path $objectCSVFilename -leaf)"
#logThis -msg "This script log to " $of -ForegroundColor Yellow

$now = get-date #(get-date).AddMonths(-1) #use now but because we are half way thought the month, i only want up to the last day of the previous month
 # Overwrite default here 
#$lastDayOfMonth =  ((get-date).AddMonths(+1)) - (New-TimeSpan -seconds 1)
#$i = $showPastMonths
#
#
#
#cpu.usagemhz.average
#disk.usage.average
#mem.usage.average
#net.usage.average
#sys.uptime.latest
#

if ($consolidateResults) 
{
	$combineResults=@{}
}

$vmhosts = get-vmhost -Server $srvConnection
logThis -msg "Collecting stats on a monthly basis for the past $showPastMonths Months..." -foregroundcolor Green

$vmhosts | sort -Property Name | %{
    #$output = "" | Select "Server"
	$outputString = New-Object System.Object
    logThis -msg "Processing host $($_.Name)..." -foregroundcolor Green
	$filters = ""
	
    #$output.Server = $_.Name
    $obj = $_
	
	if ($unleashAllStats)
	{
		$metricsDefintions = $obj | Get-StatType | ?{!$_.Contains(".latest")}
	} else {
		$metricsDefintions = "cpu.usage.average","mem.usage.average","net.usage.average"
	}
	
	
	$objectCSVFilename = $(getRuntimeCSVOutput).Replace(".csv","-$($obj.Name).csv")
	$objectNFOFilename = $(getRuntimeCSVOutput).Replace(".csv","-$($obj.Name).nfo")
	
	# I dod this so I can have a title for this report bu specifically for this host
	$objMetaInfo = @()
	$objMetaInfo +="tableHeader=$($obj.Name)"
	$objMetaInfo +="introduction=The table below has been provided the performance review of hypervisor server: ""$($obj.Name)"". The results show the usage over several periods including month by month for the last $showPastMonths months. "
	$objMetaInfo +="chartable=false"
	$objMetaInfo +="titleHeaderType=h$($headerType+1)"
	$objMetaInfo +="showTableCaption=false"
	$objMetaInfo +="displayTableOrientation=Table" # options are List or Table

	#ExportCSV -table "" -thisFileInstead $objectCSVFilename 
	ExportMetaData -metadata $objMetaInfo -thisFileInstead $objectNFOFilename
	updateReportIndexer -string "$(split-path -path $objectCSVFilename -leaf)"

	#$of = getRuntimeCSVOutput
	#Write-Host "NEW File : $of" -BackgroundColor Red -ForegroundColor White
	#$report = 
	$metricsDefintions | %{
		$metric = $_
		$parameters= @{
			'sourceVIObject'=$obj;
			'metric'=$metric;
			'maxsamples'=$maxsamples;
			'filters'=$filters;
			'showIndividualDevicesStats'=$showIndividualDevicesStats;
			'previousMonths'=$showPastMonths;
			'returnObjectOnly'=$true;
		}
		#$report = getStats -sourceVIObject $obj -metric $metric -filters $filters -maxsamples $maxsamples -showIndividualDevicesStats $showIndividualDevicesStats -previousMonths $showPastMonths -returnObjectOnly $true
		$report = getStats @parameters		
		$subheader = convertMetricToTitle $metric
		$metricCSVFilename = $(getRuntimeCSVOutput).Replace(".csv","-$($obj.Name)-$metric.csv")
		$metricNFOFilename = $(getRuntimeCSVOutput).Replace(".csv","-$($obj.Name)-$metric.nfo")
		#Write-Host $report
		$objMetaInfoPerMetric = @()
		$objMetaInfoPerMetric +="tableHeader=$($report.FriendlyName)" # $($report.Name)"
		$objMetaInfoPerMetric +="introduction=$($report.Description)"
		$objMetaInfoPerMetric +="chartable=false"
		$objMetaInfoPerMetric +="titleHeaderType=h$($headerType+2)"
		$objMetaInfoPerMetric +="displayTableOrientation=Table" # options are List or Table
		
		#$results
		#logThis -msg $report.Table
		if ($consolidateResults) 
		{
			
			$combineResults[$report.Name] = @{}
			$combineResults[$report.Name].Add($metric,$table)
		} else {
			ExportCSV -table $report.Table -thisFileInstead $metricCSVFilename 
			ExportMetaData -metadata $objMetaInfoPerMetric -thisFileInstead $metricNFOFilename
			updateReportIndexer -string "$(split-path -path $metricCSVFilename -leaf)"
		}
		
	}
}
#$combineResults
#pause
if ($consolidateResults) 
{
	$finalreport = @()
	$servernames = @($combineResults.keys)
	$metricName=$combineResults[$servernames[0]].Metric
	$listOfMonths = $combineResults[$servernames[0]].Months
	$row = New-Object System.Object
	$row | Add-Member -Type NoteProperty -Name  $metricName -Value ""
	$filerIndex=1
	$listOfMonths | %{
		$monthName = $_
		$row | Add-Member -Type NoteProperty -Name "$monthName" -Value "Minimum"			
		$row | Add-Member -Type NoteProperty -Name "H$filerIndex" -Value "Maximum"
		$filerIndex++
		$row | Add-Member -Type NoteProperty -Name "H$filerIndex" -Value "Average"
		$filerIndex++
	}
	
	$finalreport += $row
	
	$finalreport += $combineResults.keys | %{
		$keyname=$_
		$table = $combineResults[$keyname].Table
		#$row | Add-Member -Type NoteProperty -Name "Servers" -Value $keyname
		$row = New-Object System.Object
		$row | Add-Member -Type NoteProperty -Name  $metricName -Value $keyname
		$filerIndex=1
		$listOfMonths | %{
			$monthName = $_
			$row | Add-Member -Type NoteProperty -Name "$monthName" -Value ($table | ?{$_.Measure -eq "Minimum"}).$monthName
			$row | Add-Member -Type NoteProperty -Name "H$filerIndex" -Value ($table | ?{$_.Measure -eq "Maximum"}).$monthName 
			$filerIndex++
			$row | Add-Member -Type NoteProperty -Name "H$filerIndex" -Value ($table | ?{$_.Measure -eq "Average"}).$monthName
			$filerIndex++
		}
		$row
	}
	ExportCSV -table $finalreport
	#Write-Host "you need to output the table into a proper CSV file."
	#pause
}
		
# This is the global one -- pu 
ExportMetaData -metadata $metaInfo

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}

logThis -msg "Total Runtime stats"
(get-date) - $now