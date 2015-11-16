# Groups VMs by their Hardware Versions and provides a table summary
#Version : 1.0
#Updated : 23 March 2015
#Author  : teiva.rodiere@gmail.com
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$showDate=$false,[int]$headerType=1)
Write-host "Importing Module vmwareModules.psm1 (force)" -ForegroundColor Yellow
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global
$global:logfile
$global:outputCSV

# Want to initialise the module and blurb using this 1 function
InitialiseModule

$propertyDisplayName="Hardware Version"
$property="Version"
$array = getVirtualMachinesCapacityBy -srvConnection $srvconnection -property $property -propertyDisplayName $propertyDisplayName -headerType $headerType

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


# further processing
$headerType+=1
$array.Table_With_Device_Names | ?{$_.$propertyDisplayName -ne "toolsOk"} | %{
	$obj=$_
	$metaInfo = @()
	$metaInfo +="tableHeader=VMs with $propertyDisplayName $($obj.$propertyDisplayName)"
	$metaInfo +="introduction="
	$metaInfo +="chartable=false"
	$metaInfo +="titleHeaderType=h$($headerType)"
	$outputFile = $global:outputCSV -replace ".csv","-$($obj.$propertyDisplayName).csv"
	ExportCSV -table $($obj | select * -ExcludeProperty $propertyDisplayName) -thisFileInstead $outputFile 
	ExportMetaData -metaData $metaInfo -thisFileInstead $($outputFile -replace ".csv",".nfo")
}


if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}