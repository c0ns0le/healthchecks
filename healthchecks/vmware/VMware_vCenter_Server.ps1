# THIS is teiva's template base script which can be cloned of into new scripts to help accelerating the development process
#Version : 0.1
#Updated : 3th Feb 2015
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
$silencer = Import-Module -Name .\vmwareModules.psm1 -Force -PassThru -Verbose:$false
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global

# Want to initialise the module and blurb using this 1 function

# Meta data needed by the porting engine to 
$metaInfo = @()
$metaInfo +="tableHeader=vCenter Servers"
$metaInfo +="introduction=The table displays a list of vCenter servers"
$metaInfo +="chartable=false"
$metaInfo +="titleHeaderType=h$($headerType)"
$metaInfo +="displayTableOrientation=List" # options are List or Table

$dataTable = $srvConnection | %{
	$vcenter = $_
	$licenseMgr = Get-view $vcenter.ExtensionData.Content.LicenseManager
	$licenseMgrAssignment = Get-View $licenseMgr.LicenseAssignmentManager	
	$license=($licenseMgrAssignment.QueryAssignedLicenses($vcenter.ExtensionData.Content.About.InstanceUuid)).AssignedLicense.Name
	#$licenseMgrAssignment
	# define an object to capture all the information needed
	#$row = "" | select "Name"
	#$row.Name = $obj.Name
	$row = New-Object System.Object
	$row | add-member -type NoteProperty -Name "Name" -Value $vcenter.Name
	#$lm = Get-view $vcenter.ExtensionData.Content.LicenseManager
	$row | add-member -type NoteProperty -Name "Version" -Value "$($vcenter.ExtensionData.Content.About.FullName) ($($vcenter.ExtensionData.Content.About.osType))"
	$row | add-member -type NoteProperty -Name "OS" -Value $vcenter.ExtensionData.Content.About.OsType
	$row | add-member -type NoteProperty -Name "Licence" -Value $license
	# output
	$row 
	Remote-variable licenseMgr
	Remote-variable licenseMgrAssignment
	Remote-variable license

} | Sort -Property Count

############### THIS IS WHERE THE STUFF HAPPENS
if ($dataTable)
{
	if ($metaAnalytics)
	{
		$metaInfo += "analytics="+$metaAnalytics
	}	
	if ($returnResults)
	{
		return $dataTable,$metaInfo,(getRuntimeLogFileContent)
	} else {
		ExportCSV -table $dataTable -sortBy "Count"
		ExportMetaData -meta $metaInfo
	}
}

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}