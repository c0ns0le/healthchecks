# This script exports common performance stats and outputs to 2 output document
# Output 1: It looks at averages, min and peak information for an entire period defined in variable "lastMonths"
# Output 2: It looks at averages, min and peak information for each month over the period defined in variable "lastMonths"
# for the entire period and averages out 
# Full compresensive list of metrics are available here: http://communities.vmware.com/docs/DOC-560
# maintained by: teiva.rodiere@gmail.com
# version: 3
#
#   Step 1) $srvconnection = get-vc <vcenterServer>
#	Step 2) Run this script using examples below
#			\./Virtual_Machines_Perofrmance.ps1 \-srvconnection $srvconnection
#
param([object]$srvConnection,
		[string]$logDir="output",
		[string]$comment="",
		[bool]$showDate=$false,
		[int]$showPastMonths=2,
		[bool]$showSummary=$false,
		[bool]$includeThisMonthEvenIfNotFinished=$true,
		[bool]$includeLast20Minutes=$true,
		[bool]$showIndividualDevicesStats=$false,
		[int]$maxSampling=1800,
		[bool]$unleashAllStats=$false,
		[object]$vms,
		[int]$headerType=1
)
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global
$global:logfile
$global:outputCSV

# Want to initialise the module and blurb using this 1 function
InitialiseModule

$now = get-date #(get-date).AddMonths(-1) #use now but because we are half way thought the month, i only want up to the last day of the previous month

if ($vms)
{
	$objects = Get-VM $vms -Server $srvConnection 
} else {
	$objects = Get-VM * -Server $srvConnection
}

if (!$objects)
{
	showError "Invalid Objects"
} else {
	logThis -msg "Collecting stats on a monthly basis for the past $showPastMonths Months..." -foregroundcolor Green	
	$metaInfo = @()
	$metaInfo +="tableHeader=Virtual Machine Resource Usage"
	$metaInfo +="introduction=The section provides you with performance results for each of your hypervisors. Review each host as part of your capacity planning session."
	$metaInfo +="chartable=false"
	$metaInfo +="titleHeaderType=h$($headerType)"
	
	# Review Detailed performance reports for VMs
	$objects | sort -Property Name |  %{
		$obj = $_		
		if ($unleashAllStats)
		{
			$metricsDefintions = $obj | Get-StatType | ?{!$_.Contains(".latest")}
		} else {
			#$metricsDefintions = @("cpu.usage.average","mem.usage.average","cpu.ready.summation","mem.granted.average","mem.vmmemctl.average","mem.swapped.average","mem.shared.average","mem.overhead.average","disk.usage.average","disk.read.average","disk.write.average","disk.maxTotalLatency.latest","net.usage.average");
			$metricsDefintions = @("cpu.usage.average","mem.usage.average")
		}
		
		$outputString = New-Object System.Object
	    logThis -msg "Processing $($obj.Name)..." -foregroundcolor Green
		$filters = ""
		$objectCSVFilename = $(getRuntimeCSVOutput).Replace(".csv","-$($obj.Name).csv")
		$objectNFOFilename = $(getRuntimeCSVOutput).Replace(".csv","-$($obj.Name).nfo")
		
		# I dod this so I can have a title for this report bu specifically for this host
		$objMetaInfo = @()
		$objMetaInfo +="tableHeader=Performance for $($obj.Name)"
		$objMetaInfo +="introduction=This section contains performance and usage information for ""$($obj.Name)"" for a period of $showPastMonths months. "
		$objMetaInfo +="chartable=false"
		$objMetaInfo +="titleHeaderType=h$($headerType+1)"
		$objMetaInfo +="showTableCaption=false"
		$objMetaInfo +="displayTableOrientation=Table" # options are List or Table

		#ExportCSV -table "" -thisFileInstead $objectCSVFilename 
		ExportMetaData -metadata $objMetaInfo -thisFileInstead $objectNFOFilename
		updateReportIndexer -string "$(split-path -path $objectCSVFilename -leaf)"
	    
		$metricsDefintions | %{
			$metric = $_
			$report = getStats -sourceVIObject $obj -metric $metric -filters $filters -maxsamples $maxSampling -showIndividualDevicesStats $showIndividualDevicesStats -previousMonths $showPastMonths -returnObjectOnly $true
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
			ExportCSV -table $report.Table -thisFileInstead $metricCSVFilename 
			ExportMetaData -metadata $objMetaInfoPerMetric -thisFileInstead $metricNFOFilename
			updateReportIndexer -string "$(split-path -path $metricCSVFilename -leaf)"
			
		}
	}
}

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}

logThis -msg "Total Runtime stats"
(get-date) - $now