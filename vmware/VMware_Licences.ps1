# This script exports the Licences in this environment
#Version : 1.0
#Updated : 24 March 2015
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

# Meta data needed by the porting engine to 
$metaInfo = @()
$metaInfo +="tableHeader=VMware License"
$metaInfo +="introduction=The table below contains an export of all your licences currently assigned by your vCenter."
$metaInfo +="chartable=false"
$metaInfo +="titleHeaderType=h$($headerType)"
$metaInfo +="displayTableOrientation=Table" # options are List or Table

$Report = (Get-view $($srvConnection | select -First 1).ExtensionData.Content.LicenseManager | select -First 1).Licenses | %{
	$row = New-Object System.Object
	$row | add-member -type NoteProperty -Name "Name" -Value $_.Name
	$row | add-member -type NoteProperty -Name "Key" -Value $_.LicenseKey
	$row | add-member -type NoteProperty -Name "Total" -Value $_.Total
	$row | add-member -type NoteProperty -Name "Used" -Value $_.Used
	$row | add-member -type NoteProperty -Name "Packed As" -Value $_.CostUnit
	$row | add-member -type NoteProperty -Name "Customer Label" -Value $_.Labels.Value
	logThis -msg $row -ForegroundColor green
	$row 
}

############### THIS IS WHERE THE STUFF HAPPENS
if ($returnReportOnly)
{ 
	return $Report
} else {
	#ExportCSV -table ($Report | sort -Property VMs -Descending) 
	ExportCSV -table $Report -sortBy "Count"
}

# Post Creation of Report
if ($metaAnalytics)
{
	$metaInfo += "analytics="+$metaAnalytics
}
ExportMetaData -meta $metaInfo

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}