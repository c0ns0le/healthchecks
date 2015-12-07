# This scripts is intended to be a quick Issues & health check report for vmware environments.
# Author: teiva.rodiere@gmail.com
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
#
param(
	[object]$srvConnection,
	[string]$logDir="output",
	[string]$comment="",
	[bool]$showDate=$false,
	[bool]$openReportOnCompletion=$true,
	[string]$saveReportToDirectory,
	[Parameter(Mandatory=$true)][string]$reportHeader,
	[Parameter(Mandatory=$true)][string]$reportIntro,
	[Parameter(Mandatory=$true)][int]$headerType=1,
	[int]$maxsamples = [int]::MaxValue,
	[int]$performanceLastDays=7,
	$ensureTheseFieldsAreFieldIn,
	[int]$showPastMonths=1,
	[string]$lastDayOfReportOveride,	
	[object]$vmsToCheck,
	[bool]$excludeThinDisks=$false,
	#Future proofing
	[string]$vmsToExclude,
	[string]$vmhostsToCheck,
	[string]$vmhostsToExclude,
	[string]$clustersToCheck,
	[string]$clustersToExclude,
	[string]$datastoresToCheck,
	[string]$datastoresToExclude,
	[bool]$reportThinDisksAsAnIssue=$true
	#[Parameter(Mandatory=$true)][string]$farmName
)
Write-Host "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global
Set-Variable -Name reportIndex -Value "$logDir\index.txt" -Scope Global
$global:logfile
$global:outputCSV

# Want to initialise the module and blurb using this 1 function
#InitialiseModule

# Main Start ---------

if ($saveReportToDirectory)
{
	$outputFile = $saveReportToDirectory + "\" + ($($MyInvocation.MyCommand.Name)).Replace('.ps1','.html')
} else {
	$outputFile = $logDir+"\"+$runtime+"-"+($($MyInvocation.MyCommand.Name)).Replace('.ps1','.html')
}

#Declare the page
if ($srvconnection -and $srvconnection.Count -gt 1)
{
	$htmlTableHeader = "<table><th>Name</th><th>Issues/Actions</th><th>vCenter</th>"
} else {
	$htmlTableHeader = "<table><th>Name</th><th>Issues/Actions</th>"
}

$vmtoolsMatrix = getVMwareToolsVersionMatrix

# define all the Devices to query
$objectsArray = @(
	@($srvConnection | %{ $vcenterName=$_.Name; get-cluster * -server $_ | %{ $obj=$_; $obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenterName; $obj} }),
	@($srvConnection | %{ $vcenterName=$_.Name; get-vmhost * -server $_ | %{ $obj=$_; $obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenterName; $obj} }),
	@($srvConnection | %{ 
		$vcenterName=$_.Name; 
		$targetVMs = get-vm * -server $_ 
		$targetVMs | %{ $obj=$_; $obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenterName; 		
			if ($vmsToCheck -and $vmsToCheck -ne "*" )
			{
				if ($vmsToCheck.Contains($obj.Name))
				{
					$obj
				}
			} else {
				$obj
			}
		}
	}),
	@($srvConnection | %{ $vcenterName=$_.Name; get-datacenter * -server $_ | %{ $obj=$_; $obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenterName; $obj} }),
	@($srvConnection | %{ $vcenterName=$_.Name; get-datastore * -server $_ | ?{$_.type -eq "NFS"} | %{ $obj=$_; $obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenterName; $obj} }),
	@($srvConnection | %{ $vcenterName=$_.Name; get-datastore * -server $_ | ?{$_.type -ne "NFS"} | %{ $obj=$_; $obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenterName; $obj} })
)

#$objectsArray = @(@(get-cluster * -server $srvConnection), @(get-datastore * -Server $srvConnection))
$metaInfo = @()
$metaInfo +="tableHeader=Issues Report"
$metaInfo +="introduction=This report presents the findings."
$metaInfo +="chartable=false"
$metaInfo +="titleHeaderType=h$($headerType)"
$metaInfo +="showTableCaption=false"
$metaInfo +="displayTableOrientation=Table" # options are List or Table
ExportMetaData -metadata $metaInfo
updateReportIndexer -string $global:scriptName

#$objectsArray

#$reportThinDisksAsAnIssue
$parameters = @{
	'objectsArray' = [Object]$objectsArray ;
	'srvconnection' = [Object]$srvconnection ;
	'returnDataOnly' = [bool]$true ;
	'performanceLastDays' = [int]$performanceLastDays  ;
	'headerType' = [int]$($headerType+2) ;
	'showPastMonths' = [int]$lastMonths ;
	'ensureTheseFieldsAreFieldIn' = [Object]$ensureTheseFieldsAreFieldIn;
	'reportThinDisksAsAnIssue' = [bool]$reportThinDisksAsAnIssue
}

#$results = getIssues -objectsArray $objectsArray -srvconnection $srvconnection -returnDataOnly $true -performanceLastDays $performanceLastDays  -headerType $($headerType+2) -showPastMonths $lastMonths -ensureTheseFieldsAreFieldIn $ensureTheseFieldsAreFieldIn
$results = getIssues @parameters 
#$results #| Export-Csv -NoTypeinformation "C:\admin\healthchecks-reports\test\file.csv"
#pause
$totalIssues = $(($results.Values.IssuesCount | measure -Sum).Sum)
#if ($totalIssues) { $analysis =  "A total of $totalIssues issues were found affecting this system.`n" }
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
		
if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}