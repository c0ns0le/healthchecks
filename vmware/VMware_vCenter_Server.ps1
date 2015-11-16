# THIS is teiva's template base script which can be cloned of into new scripts to help accelerating the development process
#Version : 0.1
#Updated : 3th Feb 2015
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
$metaInfo +="tableHeader=vCenter Servers"
$metaInfo +="introduction=The table displays a list of vCenter servers"
$metaInfo +="chartable=false"
$metaInfo +="titleHeaderType=h$($headerType)"
$metaInfo +="displayTableOrientation=List" # options are List or Table
#$metainfo +="displaytable=true"
#$metainfo +="chartStandardWidth=800"
#$metainfo +="chartStandardHeight=400"
#$metainfo +="chartImageFileType=png"
#$metainfo +="chartType=StackedBar100"
#$metainfo +="chartText=Current Virtual Machine Capacity within Managed Services (AUBNE only)"
#$metainfo +="chartTitle=vFolders As seen In vCenter"
#$metainfo +="yAxisTitle=%"
#$metainfo +="xAxisTitle=/"
#$metainfo +="startChartingFromColumnIndex=1"
#$metainfo +="yAxisInterval=10"
#$metainfo +="yAxisIndex=1"
#$metainfo +="xAxisIndex=0"
#$metainfo +="xAxisInterval=-1"

$Report = $srvConnection | %{
	$vcenter = $_
	$lm = Get-view $vcenter.ExtensionData.Content.LicenseManager
	# define an object to capture all the information needed
	#$row = "" | select "Name"
	#$row.Name = $obj.Name
	$row = New-Object System.Object
	$row | add-member -type NoteProperty -Name "Name" -Value $vcenter.Name
	$lm = Get-view $vcenter.ExtensionData.Content.LicenseManager
	$row | add-member -type NoteProperty -Name "Version" -Value "$($vcenter.ExtensionData.Content.About.FullName) ($($vcenter.ExtensionData.Content.About.osType))"
	#$srvconnection.ExtensionData.Content.About.OsType
	$row | add-member -type NoteProperty -Name "Licence" -Value "$($lm.LicensedEdition)"
	# output
	#logThis -msg $row -ForegroundColor green
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