# This script exports the Licences in this environment
#Version : 1.0
#Updated : 24 March 2015
#Author  : teiva.rodiere-at-gmail.com
param(
	[object]$srvConnection="",
	[string]$logDir="output",
	[string]$comment="",
	[bool]$showDate=$false,
	[int]$headerType=1,
	[bool]$showKeys=$false,
	[bool]$returnResults=$true
)
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru -Verbose:$false
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global

# Want to initialise the module and blurb using this 1 function
#InitialiseModule

# Meta data needed by the porting engine to 
$metaInfo = @()
$metaInfo +="tableHeader=VMware License"
$metaInfo +="introduction=The table below contains an export of all your licences currently assigned by your vCenter."
$metaInfo +="chartable=false"
$metaInfo +="titleHeaderType=h$($headerType)"
$metaInfo +="displayTableOrientation=Table" # options are List or Table

# Select the -first 1 assumes that the vCenter are in linked mode. If they are in linked mode, then the results will report double the actual capacity.
# if the 2 or more vcenter servers are not in a linked-mode configuration then this code needs to be revisited.
$ReportPass1 = (Get-view $($srvConnection | select -First 1).ExtensionData.Content.LicenseManager | select -First 1).Licenses | %{
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
# will display by types instead of individual entries
$dataTable = $ReportPass1 | group Name | %{ 
	$licenseType = $_
	$individualLicenses = $_.Group
	$row = New-Object System.Object
	$row | add-member -type NoteProperty -Name "Name" -Value $licenseType.Name
	$row | add-member -type NoteProperty -Name "Total" -Value $(($individualLicenses | measure -Property Total -Sum).Sum)
	$row | add-member -type NoteProperty -Name "Available" -Value $(($individualLicenses | measure -Property Total -Sum).Sum - ($individualLicenses | measure -Property Used -Sum).Sum)
	if ($showKeys) { $row | add-member -type NoteProperty -Name "Keys" -Value $([string]$individualLicenses.Key -replace ' ',', ') }
	$row
}
#$report | fl
$metaAnalytics = " A total of $(($Report.Used | measure -sum).Sum) licenses out of $(($Report.Total | measure -sum).Sum) are used."

############### THIS IS WHERE THE STUFF HAPPENS

if ($dataTable)
{
	#$dataTable $dataTable
	if ($metaAnalytics)
	{
		$metaInfo += "analytics="+$metaAnalytics
	}	
	if ($returnResults)
	{
		return $dataTable,$metaInfo,(getRuntimeLogFileContent)
	} else {
		ExportCSV -table $dataTable
		ExportMetaData -meta $metaInfo
	}
}
if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}