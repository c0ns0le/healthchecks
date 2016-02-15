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

$performanceParameters = @{
	'type'="Clusters";
	'objects'=(getClusters -server $srvConnection);
	'stats'= @("cpu.usage.average","mem.usage.average","mem.totalmb.average","mem.consumed.average","mem.swapused.average","mem.vmmemctl.average","clusterServices.effectivemem.average");
	'showPastMonths'= $showPastMonths;
	'showIndividualDevicesStats'=$showIndividualDevicesStats;
}

$bigreport,$metaInfo,$logs = getPerformanceReport @performanceParameters

if ($bigreport)
{
	if ($returnResults)
	{ 
			
		return $bigreport,$metaInfo,$logs
	} else {
		# Not yet implemented
		#ExportCSV -table $finalreport
		#ExportMetaData -metadata $metaInfo
	}
}


if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}