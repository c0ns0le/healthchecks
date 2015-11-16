# Documents Guests by  Operating Systems type
# The results is used as an input into a Capacity Review Report
# Last updated: 8 March 2012
# Author: teiva.rodiere@gmail.com
#
param(	[object]$srvConnection,
		[string]$logDir="output",
		[string]$comment="",
		[bool]$showDate=$false,
		[bool]$returnReportOnly=$false,
		[bool]$showExtra=$true,
		[string]$property="Operating Systems",
		[string]$configFile="E:\scripts\customerEnvironmentSettings-ALL.ini",
		[int]$headerType=1
	)
	
Write-Host "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global
$global:logfile
$global:outputCSV

# Want to initialise the module and blurb using this 1 function
InitialiseModule
	
$array = getVirtualMachinesCapacityBy -srvConnection $srvconnection -property "ExtensionData.Config.GuestFullName" -propertyDisplayName "Tool Status" -headerType $headerType

############### THIS IS WHERE THE STUFF HAPPENS
if ($returnReportOnly)
{ 
	return $array.table
} else {
	ExportCSV -table $array.Table 
}

# Post Creation of Report
if ($array.MetaInfo)
{
	ExportMetaData -meta $array.MetaInfo
}

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}