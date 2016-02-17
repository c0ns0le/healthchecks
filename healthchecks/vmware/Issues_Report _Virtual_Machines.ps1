# This scripts is intended to be a quick Issues & health check report for vmware environments.
# Author: teiva.rodiere-at-gmail.com
#
# Goal for this script is to report on
# - Cluster Health
# - VM Errors, Warning
# - Host Errors, Warnings
# - Active Snapshots, Snapshots older than 24hrs
# - Filesystem Alarms, Errors
# - FS Volumes less than 10% of Free space
# - VMs without VMware tools, Errors
#
# ..and create Active Remediation tasks
#
param(
	[object]$srvConnection,
	[string]$logDir="output",
	[string]$comment="",
	[bool]$showDate=$false,
	[bool]$openReportOnCompletion=$true,
	[string]$saveReportToDirectory,
	[Parameter(Mandatory=$true)][int]$headerType=1,
	[int]$maxsamples = [int]::MaxValue,
	[int]$performanceLastDays=7,
	$ensureTheseFieldsAreFieldIn,
	[int]$showPastMonths=1,
	[string]$lastDayOfReportOveride,
	[bool]$excludeThinDisks=$false,
	[string]$vmsToCheck,
	[string]$vmsToExclude,
	[bool]$returnResults=$true
)
Write-Host "Importing Module vmwareModules.psm1 (force)"
$silencer = Import-Module -Name .\vmwareModules.psm1 -Force -PassThru -Verbose:$false
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global

Set-Variable -Name reportIndex -Value "$logDir\index.txt" -Scope Global

# define all the Devices to query
$parameters = @{
	'objectsArray' = [Object](@(getVMs -server $srvconnection),
				$null
				) ;
	'srvconnection' = [Object]$srvconnection ;
	'returnDataOnly' = [bool]$true ;
	'performanceLastDays' = [int]$performanceLastDays  ;
	'headerType' = [int]$($headerType+2) ;
	'showPastMonths' = [int]$lastMonths ;
	'ensureTheseFieldsAreFieldIn' = [Object]$ensureTheseFieldsAreFieldIn;
	'reportThinDisksAsAnIssue' = [bool]$reportThinDisksAsAnIssue
}

$results = getIssues @parameters

if ($results)
{
	if ($returnResults)
	{ 
			#$totalIssues = $(($results.Values.IssuesCount | measure -Sum).Sum)
			#if ($totalIssues) { $analysis =  "A total of $totalIssues issues were found affecting this system.`n" }
			return $results.DataTable,$results.MetaData,(getRuntimeLogFileContent)
	} else {
		if ($saveReportToDirectory)
			{
				$outputFile = $saveReportToDirectory + "\" + ($($MyInvocation.MyCommand.Name)).Replace('.ps1','.html')
			} else {
				$outputFile = $logDir+"\"+$runtime+"-"+($($MyInvocation.MyCommand.Name)).Replace('.ps1','.html')
			}

		$results.Keys | %{
			$name = $_
			#$htmlPage +=  header2 "$($results.$name.title)"
			#$htmlPage +=  paragraph "$($results.$name.introduction). $analysis"
			#$htmlPage +=  $results.$name.DataTable  | ConvertTo-Html -Fragment
			$metricCSVFilename = "$logdir\$($results.$($name).title -replace '\s','_').csv"
			$metricNFOFilename = "$logdir\$($results.$($name).title -replace '\s','_').nfo"
			ExportCSV -table $results.$($name).DataTable -thisFileInstead $metricCSVFilename 
			ExportMetaData -metadata $results.$($name).NFO -thisFileInstead $metricNFOFilename
			updateReportIndexer -string "$(split-path -path $metricCSVFilename -leaf)"
		}
	}
}
		
if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}