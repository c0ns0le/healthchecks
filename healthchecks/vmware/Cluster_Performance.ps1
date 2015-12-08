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
#			\./get-Performance-Clusters.ps1 \-srvconnection $srvconnection
#

param(
	[object]$srvConnection="",
	[string]$logDir="output",
	[string]$comment="",
	[bool]$verbose=$false,
	[int]$headerType=1,
	[bool]$returnResults=$true,
	[bool]$showDate=$false,
	[string]$clusterName="*",		
	[int]$showPastMonths=6,
	[bool]$showIndividualDevicesStats=$false,
	[int]$maxSampling=1800,
	[bool]$unleashAllStats=$false
)
LogThis -msg"Importing Module vmwareModules.psm1 (force)"
$silencer = Import-Module -Name .\vmwareModules.psm1 -Force -PassThru -Verbose:$false
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global



$now = get-date #(get-date).AddMonths(-1) #use now but because we are half way thought the month, i only want up to the last day of the previous month


$clusters = ($srvConnection | %{ 
	$vcenter=$_; get-cluster -Name $clusterName -server $_ | %{ 
		$obj=$_; 
		$datacenter=Get-Datacenter -Cluster $obj -Server $vCenter
		$obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenter.Name; 
		$obj | Add-Member -MemberType NoteProperty -Name "Datacenter" -Value $datacenter.Name;
		$obj
	} 
})

if (!$clusters)
{
	showError "Invalid clusters"
} else {
	logThis -msg "Collecting stats on a monthly basis for the past $showPastMonths Months..." -foregroundcolor Green	
	setSectionHeader -type "h$($headerType)" -title "Cluster Resource Usage" -text "The section provides you with performance results for each of your clusters."
	
	$clusters | sort -Property Name |  %{
		$obj = $_

        #check for duplicate Clusters across multiple vCenters
		$duplicates = ($clusters | ?{$_.Name -eq $obj.Name}).Count -gt 1
        ($clusters | ?{$_.Name -eq $obj.Name}).Name
        #Write-Host $duplicates
        #pause
		#$stats = $obj | Get-StatType
		#$metricsDefintions = "cpu.usagemhz.average","cpu.usage.average","mem.usage.average","mem.totalmb.average","mem.consumed.average","mem.swapused.average","mem.vmmemctl.average","clusterServices.effectivemem.average"
		if ($unleashAllStats)
		{
			$metricsDefintions = $obj | Get-StatType | ?{!$_.Contains(".latest")}
		} else {
			$metricsDefintions = "cpu.usagemhz.average","cpu.usage.average","mem.usage.average","mem.totalmb.average","mem.consumed.average","mem.swapused.average","mem.vmmemctl.average","clusterServices.effectivemem.average"
		}
		if ($duplicates)
        {
            $title="$($obj.Name) ($($obj.Datacenter))"
            #pause
        } else {
            $title="$($obj.Name)"
        }
		$outputString = New-Object System.Object
	    logThis -msg "Processing Cluster $($obj.Name)..." -foregroundcolor Green
		$filters = ""
		$objectCSVFilename = $(getRuntimeCSVOutput).Replace(".csv","-$title.csv")
		$objectNFOFilename = $(getRuntimeCSVOutput).Replace(".csv","-$title.nfo")
		
		# I dod this so I can have a title for this report bu specifically for this host
        
		$objMetaInfo = @()
		$objMetaInfo +="tableHeader=$title"
		$objMetaInfo +="introduction=The table below has been provided the performance review of VMware cluster ""$($obj.Name)"" located in Datacenter ""$($obj.Datacenter)"". The results show the usage over several periods including month by month for the last $showPastMonths months. "
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
		    $metricCSVFilename = $objectCSVFilename.Replace(".csv","-$metric.csv")
		    $metricNFOFilename = $objectCSVFilename.Replace(".csv","-$metric.nfo")
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