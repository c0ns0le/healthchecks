# Groups VMs by their MemoryMB allocations and provides a table summary
#Version : 1.0
#Updated : 23 March 2015
#Author  : teiva.rodiere@gmail.com
param(
	[object]$srvConnection="",
	[string]$logDir="output",
	[string]$comment="",
	[bool]$verbose=$false,
	[int]$headerType=1,
	[bool]$returnResults=$true,
	[bool]$showDate=$false
)
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru -Verbose:$false
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global
InitialiseModule

$array = getVirtualMachinesCapacityBy -srvConnection $srvconnection -property "MemoryMB" -propertyDisplayName "Memory Size" -unit "MB" -headerType $headerType

if ($array.Table )
{
	#$dataTable $dataTable
	if ($metaAnalytics)
	{
		$array.MetaInfo += "analytics="+$metaAnalytics
	}	
	if ($returnResults)
	{
		return $array.Table,$array.MetaInfo,(getRuntimeLogFileContent)
	} else {
		ExportCSV -table $array.Table
		ExportMetaData -meta $array.MetaInfo
	}
}

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}