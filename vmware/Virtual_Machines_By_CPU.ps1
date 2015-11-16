# Groups VMs by their vCPU allocations and provides a table summary
#Version : 1.0
#Updated : 23 March 2015
#Author  : teiva.rodiere@gmail.com
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$showDate=$false,[string]$property="NumCPU",[string]$propertyReadable="CPU Size",[string]$unit,[int]$headerType=1)
logThis -msg "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global
$global:logfile
$global:outputCSV

# Want to initialise the module and blurb using this 1 function
InitialiseModule


$array = getVirtualMachinesCapacityBy -srvConnection $srvconnection -property "NumCPU" -propertyDisplayName "CPU Size" -headerType $headerType

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