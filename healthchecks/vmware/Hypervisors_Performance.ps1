# Exports performance results for VMHosts
#Version : 0.1
#Updated : 3th Feb 2015
#Author  : teiva.rodiere-at-gmail.com
param([object]$srvConnection="",
	[string]$logDir="output",
	[string]$comment="",
	[bool]$showDate=$false,
	[int]$showPastMonths=6,
	[bool]$showIndividualDevicesStats=$false,
	[int]$maxsamples=([int]::MaxValue),
	[bool]$unleashAllStats=$false,
	[int]$headerType=1,
	[bool]$consolidateResults=$true,
	[bool]$returnResults=$true	
)

Write-Host -msg "Importing Module vmwareModules.psm1 (force)"
$silencer = Import-Module -Name vmwareModules.psm1 -Force -PassThru -Verbose:$false
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global

$performanceParameters = @{
	'type'="Hypervisors";
	'objects'=(getVMhosts -server $srvConnection);
	'stats'= @("cpu.usage.average","mem.usage.average","net.usage.average");
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


