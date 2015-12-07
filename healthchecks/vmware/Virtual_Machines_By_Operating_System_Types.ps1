# Documents Guests by  Operating Systems type
# The results is used as an input into a Capacity Review Report
# Last updated: 8 March 2012
# Author: teiva.rodiere@gmail.com
#

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

$array = getVirtualMachinesCapacityBy -srvConnection $srvconnection -property "ExtensionData.Config.GuestFullName" -propertyDisplayName "Tool Status" -headerType $headerType

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