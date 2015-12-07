# Groups VMs by their vCPU allocations and provides a table summary
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
#InitialiseModule


$array = getVirtualMachinesCapacityBy -srvConnection $srvconnection -property "NumCPU" -propertyDisplayName "CPU Size" -headerType $headerType

############### THIS IS WHERE THE STUFF HAPPENS

if ($array.Table)
{
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