########################################################################
# This file contains a generic collection of necessray and usefull functions 
# to minimise foot script development and for better better code managemnt
#
# Maintained by: teiva.rodiere@gmail.com
#
# Usage: in any of your scripts, just add this line "Import-Module <path>\gmsTeivaModules.psm1"
#
#######################################################################
# Logger Module - Used to log script runtime and output to screen
#######################################################################
# Source = VM (VirtualMachineImpl) or ESX objects(VMHostImpl)
# metrics = @(), an array of valid metrics for the object passed
# filters = @(), and array which contains inclusive filtering strings about specific Hardware Instances to filter the results so that they are included 
# returns a script of HTML or CSV or what

###############################################
# CSV META FILES
###############################################
# Meta data needed by the porting engine to 
# These are the available fields for each report
#$metaInfo = @()
#$metaInfo +="tableHeader=IBM V7000 Storage Arrays"
#$metaInfo +="introduction=This report exports a list of Storage Arrays Identified in your VMware Infrastructure"
#$metaInfo +="chartable=false"
#$metaInfo +="displayTableOrientation=List"
#$metaInfo +="showTableCaption=false"
#$metainfo +="displaytable=true"
#$metainfo +="generateTopConsumers=10
#$metainfo +="generateTopConsumersSortByColumn=Count
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
################################################
#Import-Module -Name .\gmsTeivaModule-VMware.psm1 -Force -PassThru

function InitialiseModule ()#([Parameter(Mandatory=$true)][string] $script)#, [Parameter(Mandatory=$true)][string] $logDir)
{
	$global:runtime="$(date -f dd-MM-yyyy)"
	if ((Test-Path -path $global:logDir) -ne $true) {
		New-Item -type directory -Path $global:logDir
		$childitem = Get-Item -Path $global:logDir
		$global:logDir = $childitem.FullName
	}
	#$childitem = Get-Item -Path $global:logDir
	#$global:logDir = $childitem.FullName
	#$runtimeLogFile = $global:logDir + "\"+$runtime+"_"+$global:scriptName.Replace(".ps1",".log")
	#$global:runtimeCSVOutput = $global:logDir + "\"+$runtime+"_"+$global:scriptName.Replace(".ps1",".csv")
	#$runtimeCSVMetaFile = $global:logDir + "\"+$runtime+"_"+$global:scriptName.Replace(".ps1",".nfo")
	$runtimeLogFile = $global:logDir + "\"+$global:scriptName.Replace(".ps1",".log")
	$global:runtimeCSVOutput = $global:logDir+"\"+$global:scriptName.Replace(".ps1",".csv")
	$runtimeCSVMetaFile = $global:logDir+"\"+$global:scriptName.Replace(".ps1",".nfo")
	$scriptsHomeDir = split-path -parent $global:scriptName
	
	$global:today = Get-Date
	$global:startDate = (Get-Date (forThisdayGetFirstDayOfTheMonth -day $today) -Format "dd-MM-yyyy midnight")
	$global:lastDate = (Get-date ( forThisdayGetLastDayOfTheMonth -day $(Get-Date $today).AddMonths(-$showLastMonths) ) -Format "dd-MM-yyyy midnight")

	if (!$global:reportIndex)
	{
		
		Write-Host "Creating the Indexer File $global:logDir\index.txt"
		setReportIndexer -fullName "$global:logDir\index.txt"
	}

	SetmyLogFile -filename $runtimeLogFile
	logThis -msg " ****************************************************************************"
	logThis -msg "Script Started @ $(get-date)" -ForegroundColor Cyan
	logThis -msg "Executing script: $global:scriptName " -ForegroundColor Cyan
	logThis -msg "Logging Directory: $global:logDir" -ForegroundColor  Cyan
	logThis -msg "Script Log file: $global:logfile" -ForegroundColor  Cyan
	logThis -msg "Indexer: $global:reportIndex" -ForegroundColor  Cyan
	#logThis -msg "vCenter Server: $global:vCenter" -ForegroundColor  Cyan
	logThis -msg " ****************************************************************************"
	logThis -msg "Loading Session Snapins.."
	#loadSessionSnapings
	SetmyCSVOutputFile -filename $global:runtimeCSVOutput
	SetmyCSVMetaFile -filename $runtimeCSVMetaFile
}


function SetmyCSVMetaFile(
	[Parameter(Mandatory=$true)][string] $filename
	)
{
	if($global:metaFile)
	{
		$global:metaFile = $filename
	} else {
		Set-Variable -Name metaFile -Value $filename -Scope Global
	}
}

function ExportMetaData([Parameter(Mandatory=$true)][object[]] $metaData, [Parameter(Mandatory=$false)]$thisFileInstead)
{
	if ((Test-Path -path $global:logDir) -ne $true) {
		New-Item -type directory -Path $global:logDir
		$childitem = Get-Item -Path $global:logDir
		$global:logDir = $childitem.FullName
	}
	
	$tmpMetafile = $global:metaFile
	if( $thisFileInstead)
	{
		$tmpMetafile = $thisFileInstead
	}
	if ($global:metaFile)
	{
		 $metadata | Out-File -FilePath $tmpMetafile
	}
}

function getRuntimeMetaFile()
{
	return "$global:metaFile"
}

function setRuntimeMetaFile([string]$filename)
{
	$global:metaFile = $filename
}

function updateRuntimeMetaFile([object[]] $metaData)
{
	$metadata | Out-File -FilePath $global:metaFile -Append
}

function getRuntimeCSVOutput()
{
	return "$global:runtimeCSVOutput"
	#return "$global:outputCSV"
}

function setReportIndexer($fullName="$global:logDir\index.txt")
{
	Set-Variable -Name reportIndex -Value "$fullName" -Scope Global
	New-Item "$global:reportIndex" -type file
}

function getReportIndexer()
{
	return $global:reportIndex
}

function updateReportIndexer($string)
{
	if (!(getReportIndexer))
	{
		setReportIndexer
	}
	echo $string | Out-file -Append -FilePath $global:reportIndex
}
function Get-LDAPUser ($UserName) {
    $queryDC = (get-content env:logonserver).Replace('\','');
    $domain = new-object DirectoryServices.DirectoryEntry `
        ("LDAP://$queryDC")
    $searcher = new-object DirectoryServices.DirectorySearcher($domain)
    $searcher.filter = "(&(objectClass=user)(sAMAccountName=$UserName))"
    return $searcher.FindOne().Properties.displayname
} 


function getObjectVMwareLicence([Object]$obj)
{
	#$lm = Get-view $_.ExtensionData.Content.LicenseManager
}

Function LoadNFOVariables([string]$file) {
    Get-Content $file | Foreach-Object {
        $var = $_.Split('=')
        New-Variable -Name $var[0] -Scope Global -Value $var[1]
    }
}

Function UnloadNFOVariables([string]$file) {
	logThis -msg "`t`t-> Unloading variables"
    Get-Content $file | Foreach-Object {
        $var = $_.Split('=')
        $variableName = $var[0]
		logThis -msg "`t`t-> Removing Variable `$$variableName = $variableName" -ForegroundColor Green		
		Remove-Variable $variableName -Scope Global
	
    }
}

function createChart(
	[string]$sourceCSV,
	[string]$outputFileLocation, 
	[string]$chartTitle,
	[string]$xAxisTitle,
	[string]$yAxisTitle,
	[string]$imageFileType,
	[string]$chartType,
	[int]$width=800,
	[int]$height=600,
	[int]$startChartingFromColumnIndex=1,
	[int]$yAxisInterval=5,
	[int]$yAxisIndex=1,
	[int]$xAxisIndex=0,
	[int]$xAxisInterval,
	[int]$numberOfPointsForXAxis=14
	)
{
	#logThis -msg "`tProcessing chart for $chartTitle"
	#logThis -msg "`t`t$sourceCSV $chartTitle $xAxisTitle $yAxisTitle $imageFileType $chartType"	
	if (!$outputFileLocation)
	{
		$outputFileLocation=$sourceCSV.Replace(".csv",".$imageFileType")
		#$imageFilename=$($sourceCSV |  Split-Path -Leaf).Replace(".csv",".$imageFileType");	
	}
	$tableCSV=Import-Csv $sourceCSV
	if ($xAxisInterval -eq -1)
	{
		# I want to plot ALL the graphs
		$xAxisInterval = 1
	} else {
		$xAxisInterval = [math]::round($tableCSV.Count/$numberOfPointsForXAxis,0)
	}
	#$xAxisInterval = $tableCSV.Count-2
	
	$dunnowhat=.\generate-chartImageFile.ps1 -datasource $tableCSV `
							-title $chartTitle `
							-outputImageName $outputFileLocation `
							-chartType  $chartType `
							-xAxisIndex $xAxisIndex `
							-xAxisTitle $xAxisTitle `
							-xAxisInterval $xAxisInterval `
							-yAxisIndex $yAxisIndex `
							-yAxisTitle $yAxisTitle `
							-yAxisInterval $yAxisInterval `
							-startChartingFromColumnIndex $startChartingFromColumnIndex `
							-width $width `
							-height $height `
							-fileType $imageFileType
							
	return $outputFileLocation
}

function recurseThruObject(
	[Parameter(Mandatory=$true)][Object]$obj
)
{
	$properties = $obj | Get-Member -MemberType Property
	$table = @()
	#$myobject = @()
	$col = New-Object System.Object
	#$row.Name = $name
 	$properties | %{
		$property = $_
		$type,$field,$therest=$property.definition.Split('')
		
		#if (!$type.Contains("string") -and !$type.Contains("type") -and !$type.Contains("System.Reflection"))
		if ($type.Contains("System.Object"))
		{
			Write-Host "Recursing ...$property " -ForegroundColor Yellow
			#$table += return recurseThruObject $obj.$field
		} elseif ($type -eq "string") 
		{
			#$row += $obj.$($_.Definition)
			Write-Host $type $field
			$table = $col | Add-Member -MemberType NoteProperty -Name $field -Value $($obj.$field)
		}
	}
	return $table
}



# pass a date to this function, and it will return the 1st day of the month for this day.
# Meaning, if you pass a day of 10th January 2014, then the function should return 1 January 2014
function forThisdayGetFirstDayOfTheMonth([DateTime]$day)
{
	return get-date "1/$((Get-Date $day).Month)/$((Get-Date $day).Year)"
}

# pass a date to this function, and it will return the Last day of the month for this day.
# Meaning, if you pass a day of 10th January 2014, then the function should return 31 January 2014
function forThisdayGetLastDayOfTheMonth([DateTime]$day)
{
	return get-date "$([System.DateTime]::DaysInMonth((get-date $day).Year, (get-date $day).Month))/$((get-date $day).Month)/$((get-date $day).Year) 23:59:59"
}

function getMonthYearColumnFormatted([DateTime]$day)
{
	return Get-Date $day -Format "MMM yyyy"
}

function daysSoFarInThisMonth([DateTime] $day)
{
	return $day.Day
}

function createChartOld(
	[Object[]]$datasource,
	[string]$outputImage,
	[string]$chartTitle,
	[string]$xAxisTitle,
	[string]$yAxisTitle,
	[string]$imageFileType,
	[string]$chartType,
	[int]$width=800,
	[int]$height=600,
	[int]$startChartingFromColumnIndex=1,
	[int]$yAxisInterval=5,
	[int]$yAxisIndex=1,
	[int]$xAxisIndex=0,
	[int]$xAxisInterval
	)
{
	#logThis -msg "`tProcessing chart for $chartTitle"
	#logThis -msg "`t`t$sourceCSV $chartTitle $xAxisTitle $yAxisTitle $imageFileType $chartType"	
	#if (!$outputImage)
	#{
		#$outputImage=$sourceCSV.Replace(".csv",".$imageFileType")
		#$imageFilename=$($sourceCSV |  Split-Path -Leaf).Replace(".csv",".$imageFileType");	
	#}
	#Eventually change to table
	#$tableCSV=Import-Csv $sourceCSV
	if ($xAxisInterval -eq -1)
	{
		# I want to plot ALL the graphs
		$xAxisInterval = 1
	} else {
		$xAxisInterval = [math]::round($datasource.Count/7,0)
	}
	#$xAxisInterval = $tableCSV.Count-2
	
	$dunnowhat=.\generate-chartImageFile.ps1 -datasource $datasource `
							-title $chartTitle `
							-outputImageName $outputImage `
							-chartType  $chartType `
							-xAxisIndex $xAxisIndex `
							-xAxisTitle $xAxisTitle `
							-xAxisInterval $xAxisInterval `
							-yAxisIndex $yAxisIndex `
							-yAxisTitle $yAxisTitle `
							-yAxisInterval $yAxisInterval `
							-startChartingFromColumnIndex $startChartingFromColumnIndex `
							-width $width `
							-height $height `
							-fileType $imageFileType
							
	return $outputImage
}



function formatHeaderString ([string]$string)
{
	return [Regex]::Replace($string, '\b(\w)', { param($m) $m.Value.ToUpper() });
}

function header1([string]$string)
{
	return "<h1>$(formatHeaderString $string)</h1>"
}

function header2([string]$string)
{
	return "<h2>$(formatHeaderString $string)</h2>"
}

function header3([string]$string)
{
	return "<h3>$(formatHeaderString $string)</h3>"
}
function header4([string]$string)
{
	return "<h4>$(formatHeaderString $string)</h4>"
}

function paragraph([string]$string)
{
	return "<p>$string</p>"
}

function htmlFooter()
{
	return "<p><small>$runtime | $global:srvconnection | generated from $env:computername.$env:userdnsdomain </small></p></body></html>"
	
}

function htmlHeader()
{
	return @"
	<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">
<html><head><title>Health Check Report</title>
<style type="text/css">
<!--
body {
	font-family: Verdana, Geneva, Arial, Helvetica, sans-serif;
}

#report { width: 835px; }
.red td{
	background-color: red;
}
.yellow  td{
	background-color: yellow;
}
.green td{
	background-color: green;
}

a:link, span.MsoHyperlink
	{color:blue;
	text-decoration:underline;}
a:visited, span.MsoHyperlinkFollowed
	{color:purple;
	text-decoration:underline;}
p
	{margin-top:0in;
	margin-right:0in;
	margin-bottom:8.5pt;
	margin-left:0in;
	line-height:13.0pt;
	font-size:9.5pt;
	font-family:"Century Gothic",sans-serif;}
	
h1
	{mso-style-link:"Heading 1 Char";
	padding-top:20px;
	margin-top:24.0pt;
	margin-right:0in;
	margin-bottom:8.5pt;
	margin-left:40.5pt;
	text-indent:-.5in;
	line-height:20.0pt;
	page-break-after:avoid;
	font-size:18.0pt;
	font-family:"Century Gothic",sans-serif;
	color:#ED1C24;
	font-weight:normal;}
h2
	{mso-style-link:"Heading 2 Char";
	padding-top:20px;
	margin-top:.25in;
	margin-right:0in;
	margin-bottom:2.85pt;
	margin-left:.5in;
	text-indent:-.5in;
	line-height:15.0pt;
	page-break-after:avoid;
	font-size:12.0pt;
	font-family:"Century Gothic",sans-serif;
	color:#ED1C24;
	font-weight:bold;}
h3
	{mso-style-link:"Heading 3 Char";
	padding-top:20px;
	margin-top:.25in;
	margin-right:0in;
	margin-bottom:2.85pt;
	margin-left:.5in;
	text-indent:-.5in;
	page-break-after:avoid;
	font-size:11.0pt;
	font-family:"Century Gothic",sans-serif;
	color:#D7181E;
	font-weight:normal;}
h4 {
	mso-style-link:"Heading 4 Char";
	padding-top:20px;
	margin-top:5.65pt;
	margin-right:0in;
	margin-bottom:2.85pt;
	margin-left:.5in;
	text-indent:-.5in;
	line-height:10.8pt;
	page-break-after:avoid;
	font-size:9.5pt;
	font-family:"Century Gothic",sans-serif;
	color:#D7181E;
	font-weight:normal;
}

li	{
	margin-top:0in;
	margin-right:0in;
	margin-bottom:8.5pt;
	margin-left:0in;
	line-height:13.0pt;
	font-size:9.5pt;
	font-family:"Century Gothic",sans-serif;
}
ol	{margin-bottom:0in;}
ul	{margin-bottom:0in;}
table{
   border-collapse: collapse;
   border: 1px solid #cccccc;
   font: 10pt Verdana, Geneva, Arial, Helvetica, sans-serif;
   color: black;
   margin-bottom: 10px;
   width: auto;
}
table td{
       font-size: 12px;
       padding-left: 2px;padding-right: 2px;
       text-align: left;
	   width: auto;
	   border: 1px solid #cccccc;
}
table th {
       font-size: 12px;
       font-weight: bold;
       padding-left: 0px;
       padding-right: 20px;
       text-align: left;
	   border: 1px solid #cccccc;
	   width: auto;
	   border: 1px solid #cccccc;
}

table.list td:nth-child(1){font-weight: bold; border-right: 1px grey solid; text-align: right;}
table th {background: #ED1C24;font-size:10.0pt; color:white;padding-left: 2px;padding-right: 2px;}
table.list td:nth-child(2){border-top:none;border-left:none;border-bottom:solid white 1.0pt; border-right:solid white 1.0pt;padding:0in 0in 0in 0in}
table tr:nth-child(even) td:nth-child(even){ background: #CCCCCC; }
table tr:nth-child(odd) td:nth-child(odd){ background: #F2F2F2; }
table tr:nth-child(even) td:nth-child(odd){ background: #DDDDDD; }
table tr:nth-child(odd) td:nth-child(even){ background: #E5E5E5; }
div.column {width: 320px; float: left;}
div.first{padding-right: 20px; border-right: 1px  grey solid; }
div.second{margin-left: 30px; }
caption {
    display: table-caption;
    text-align: right;
	font-size: 10px;
    font-weight: bold;
	border: 1px solid #cccccc;
}
-->
</style>
</head>
<body>

"@
}
function htmlHeaderPrev()
{
	return @"
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">
<html><head><title>Virtual Machine ""$guestName"" System Report</title>
<style type="text/css">
<!--
body {
	font-family: Verdana, Geneva, Arial, Helvetica, sans-serif;
}

#report { width: 835px; }
.red td{
	background-color: red;
}
.yellow  td{
	background-color: yellow;
}
.green td{
	background-color: green;
}
table{
   border-collapse: collapse;
   border: 1px solid #cccccc;
   font: 10pt Verdana, Geneva, Arial, Helvetica, sans-serif;
   color: black;
   margin-bottom: 10px;
   margin-left: 20px;
   width: auto;
}
table td{
       font-size: 12px;
       padding-left: 0px;
       padding-right: 20px;
       text-align: left;
	   width: auto;
	   border: 1px solid #cccccc;
}
table th {
       font-size: 12px;
       font-weight: bold;
       padding-left: 0px;
       padding-right: 20px;
       text-align: left;
	   border: 1px solid #cccccc;
	   width: auto;
	   border: 1px solid #cccccc;
}

h1{ 
	clear: both; 
	font-size: 160%;
}

h2{ 
	clear: both; 
	font-size: 130%; 
}

h3{
   clear: both;
   font-size: 120%;
   margin-left: 20px;
   margin-top: 30px;
   font-style: italic;
}

h3{
   clear: both;
   font-size: 100%;
   margin-left: 20px;
   margin-top: 30px;
   font-style: italic;
}

p{ margin-left: 20px; font-size: 12px; }

ul li {
	font-size: 12px;
}

table.list{ float: left; }

table.list td:nth-child(1){
       font-weight: bold;
       border-right: 1px grey solid;
       text-align: right;
}

table.list td:nth-child(2){ padding-left: 7px; }
table tr:nth-child(even) td:nth-child(even){ background: #CCCCCC; }
table tr:nth-child(odd) td:nth-child(odd){ background: #F2F2F2; }
table tr:nth-child(even) td:nth-child(odd){ background: #DDDDDD; }
table tr:nth-child(odd) td:nth-child(even){ background: #E5E5E5; }

div.column { width: 320px; float: left; }
div.first{ padding-right: 20px; border-right: 1px  grey solid; }
div.second{ margin-left: 30px; }
-->
</style>
</head>
<body>
"@
}


function sanitiseTheReport([Object]$tmpReport)
{
	$Members = $tmpReport | Select-Object `
	  @{n='MemberCount';e={ ($_ | Get-Member).Count }}, `
	  @{n='Members';e={ $_.PsObject.Properties | %{ $_.Name } }}
	$AllMembers = ($Members | Sort-Object MemberCount -Descending)[0].Members

	$Report = $tmpReport | %{
	  ForEach ($Member in $AllMembers)
	  {
	    If (!($_ | Get-Member -Name $Member))
	    { 
	      $_ | Add-Member -Type NoteProperty -Name $Member -Value ""
	    }
	  }
	  Write-Output $_
	}
	
	return $Report
}

# Simple arithmetic addition to see if the value is a number
function isNumeric ($x) {
    try {
        0 + $x | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Enables all scripts to use the character or word that indicates that data is missing
function printNoData()
{
	return "-"
}

# a standard way to format numbers for reporting purposes
function formatNumbers (
	[Parameter(Mandatory=$true)]$value,
	[int]$deci=0
)
{
	#Write-Host $("{0:n2}" -f $val)
	#logThis -msg $($var.gettype().Name)
	if ($(isNumeric $value))
	{
		return "{0:N$deci}" -f $value
	} else {
		return printNoData
	}
	#return "$([math]::Round($val,2))"
}

function showError ([Parameter(Mandatory=$true)][string] $msg, $errorColor="Red")
{
	logThis ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" -ForegroundColor $errorColor
	logThis ">> " -ForegroundColor $errorColor
	logThis ">> $msg" -ForegroundColor $errorColor
	logThis ">> " -ForegroundColor $errorColor
	logThis ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" -ForegroundColor $errorColor
}

function verboseThis ([Parameter(Mandatory=$true)][object] $msg, $errorColor="Cyan")
{
	logThis ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" -ForegroundColor $errorColor
	logThis ">> " -ForegroundColor $errorColor
	logThis ">> $msg" -ForegroundColor $errorColor
	logThis ">> " -ForegroundColor $errorColor
	logThis ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" -ForegroundColor $errorColor
}

#Log To Screen and file
function logThis (
	[Parameter(Mandatory=$true)][string] $msg, 
	[Parameter(Mandatory=$false)][string] $logFile,
	[Parameter(Mandatory=$false)][string] $ForegroundColor = "yellow",
	[Parameter(Mandatory=$false)][bool]$logToScreen = $true
	)
{

	#Write-Host "-->[$global:logFile]" -ForegroundColor Yellow
	#Write-Host "[$logFile]"
	if ((Test-Path -path $global:logDir) -ne $true) {
				
		New-Item -type directory -Path $global:logDir
		$childitem = Get-Item -Path $global:logDir
		$global:logDir = $childitem.FullName
	}
	if ($logToScreen)
	{
		# Also verbose to screent
		Write-Host $msg -ForegroundColor $ForegroundColor;
	} 
	
	if ($global:logFile)
	{
		$msg  | out-file -filepath $global:logFile -append
	} elseif ($logFile)
	{
		$msg  | out-file -filepath $logFile -append
	} else {
		# do nothing
	}
}

function SetmyLogFile(
		[Parameter(Mandatory=$true)][string] $filename
	)
{
	if($global:logFile)
	{
		$global:logFile = $filename
	} else {
		Set-Variable -Name logFile -Value $filename -Scope Global
	}
	
	# Empty the file
	"" | out-file -filepath $global:logFile
	logThis -msg "This script will be logging to $global:logFile"
}

function SetmyCSVOutputFile(
		[Parameter(Mandatory=$true)][string] $filename
	)
{
	if($global:outputCSV)
	{
		$global:outputCSV = $filename
	} else {
		Set-Variable -Name outputCSV -Value $filename -Scope Global
	}
	logThis -msg "This script will log all data output to CSV file called $global:outputCSV"
}

	
function AppendToCSVFile (
	[Parameter(Mandatory=$true)][string] $msg
	)
{
	if ((Test-Path -path $global:logDir) -ne $true) {
		New-Item -type directory -Path $global:logDir
		$childitem = Get-Item -Path $global:logDir
		$global:logDir = $childitem.FullName
	}
	Write-Output $msg >> $global:outputCSV
}

function ExportCSV (
	[Parameter(Mandatory=$true)][Object] $table,
	[Parameter(Mandatory=$false)][string] $sortBy,
	[Parameter(Mandatory=$false)][string] $thisFileInstead,
	[Parameter(Mandatory=$false)][object[]] $metaData
	)
{

	$report = sanitiseTheReport $table
	if ((Test-Path -path $global:logDir) -ne $true) {
		New-Item -type directory -Path $global:logDir
		$childitem = Get-Item -Path $global:logDir
		$global:logDir = $childitem.FullName
	}
	$filename=$global:outputCSV
	if ($thisFileInstead)
	{
		$filename = $thisFileInstead
	}
	LogThis "outputCSV = $filename" 
	if ($sortBy)
	{
		$report | sort -Property $sortBy -Descending | Export-Csv -Path $filename -NoTypeInformation
	} else {
		$report | Export-Csv -Path $filename -NoTypeInformation
	}
	
	if ($metadata)
	{
		ExportMetaData -metadata $metadata
	}
}

function launchReport()
{
	Invoke-Expression $global:outputCSV
}



#######################################################################
# This function can be used to pass a username to it and secure file with 
# encrypted password and generate a powershell script
#######################################################################
function GetmyCredentialsFromFile(
	[Parameter(Mandatory=$true)][string]$User,
	[Parameter(Mandatory=$true)][string]$File
	) 
{
	
	$password = Get-Content $File | ConvertTo-SecureString 
	$credential = New-Object System.Management.Automation.PsCredential($user,$password)
	Write-Host "Am i in here [$($credential.Username)]" -BackgroundColor Red -ForegroundColor Yellow
	return $credential
}

#######################################################################
# This function will assist in generating an encrypted password into a 
# nominated file. Noted that the password can only be decrypted by the 
#user who has encrypted it
#######################################################################
# Syntax
# Set-Credentials -File securestring.txt
# Set-Credentials 
# maintained by: teiva.rodiere@mincomc.com
# You need to open run this under the account that will be using to run the reports or the automation
# GMS\svc-autobot is a domain account which most scripts run under on mmsbnevmm01.
#   if you want to use GMS\svc-autobot to call any scripts under scheduled task, you need to create the password file for the target account to 
# be used in the target vcenter server. So for exampl: if you want to automate scripts from MMSBNEVMM01.gms.mincom.com against the DEV Domain
# you need 
# 1) Launch cmd.exe as the GMS\svc-autobot account on MMSBNEVMM01
#   C:\>runas /user:gms\svc-autobot cmd.exe
# 2) in the command line cmd.exe shell, launch powershell.exe
# 3) in powershell run this script, where securetring.txt should be named meaningfully..like securestring-dev-autobot.txt
# 
function Set-Credentials ([Parameter(Mandatory=$true)][string]$File="securestring.txt")
{
	# This will prompt you for credentials -- be sure to be calling this function from the appropriate user 
	# which will decrypt the password later on
	$Credential = Get-Credential
	$credential.Password | ConvertFrom-SecureString | Set-Content $File
}


#######################################################################
# This function can be used to email html with or without attachments. 
# Be sure to set parameters correctly.
#######################################################################
function sendEmail
	(	[Parameter(Mandatory=$true)][string] $smtpServer,  
		[Parameter(Mandatory=$true)][string] $from, 
		[Parameter(Mandatory=$true)][string] $replyTo=$from, 
		[Parameter(Mandatory=$true)][string] $toAddress,
		[Parameter(Mandatory=$true)][string] $subject, 
		[Parameter(Mandatory=$true)][string] $body="",
		[Parameter(Mandatory=$false)][object] $attachements # An array of filenames with their full path locations
	)  
{
	Write-Host "[$attachments]" -ForegroundColor Blue
	if (!$smtpServer -or !$from -or !$replyTo -or !$toAddress -or !$subject -or !$body)
	{
		Write-Host "Cannot Send email. Missing parameters for this function. Note that All fields must be specified" -BackgroundColor Red -ForegroundColor Yellow
		Write-Host "smtpServer = $smtpServer"
		Write-Host "from = $from"
		Write-Host "replyTo = $replyTo"
		Write-Host "toAddress = $toAddress"
		Write-Host "subject = $subject"
		Write-Host "body = $body"
	} else {
		#Creating a Mail object
		$msg = new-object Net.Mail.MailMessage
		#Creating SMTP server object
		$smtp = new-object Net.Mail.SmtpClient($smtpServer)
		#Email structure
		$msg.From = $from
		$msg.ReplyTo = $replyTo
		$msg.To.Add($toAddress)
		$msg.subject = $subject
		$msg.IsBodyHtml = $true
		$msg.body = $body.ToString();
		$msg.DeliveryNotificationOptions = "OnFailure"
		
		if ($attachments)
		{
			$attachments | %{
				#Write-Host $_ -ForegroundColor Blue
				$attachment = new-object System.Net.Mail.Attachment($_, ‘Application/Octet’)
				$msg.Attachments.Add($attachment)
			}
		} else {
			#Write-Host "No $attachments"
		}
		
		Write-Host "Sending email from iwthin this routine"
		$smtp.Send($msg)
	}
}


##################
#
#
function ChartThisTable( [Parameter(Mandatory=$true)][array]$datasource,
		[Parameter(Mandatory=$true)][string]$outputImageName,
		[Parameter(Mandatory=$true)][string]$chartType="line",
		[Parameter(Mandatory=$true)][int]$xAxisIndex=0,
		[Parameter(Mandatory=$true)][int]$yAxisIndex=1,
		[Parameter(Mandatory=$true)][int]$xAxisInterval=1,
		[Parameter(Mandatory=$true)][string]$xAxisTitle,
		[Parameter(Mandatory=$true)][int]$yAxisInterval=50,
		[Parameter(Mandatory=$true)][string]$yAxisTitle="Count",
		[Parameter(Mandatory=$true)][int]$startChartingFromColumnIndex=1, # 0 = All columns, 1 = starting from 2nd column, because you want to use Colum 0 for xAxis
		[Parameter(Mandatory=$true)][string]$title="EnterTitle",
		[Parameter(Mandatory=$true)][int]$width=800,
		[Parameter(Mandatory=$true)][int]$height=800,
		[Parameter(Mandatory=$true)][string]$BackColor="White",
		[Parameter(Mandatory=$true)][string]$fileType="png"
	  )
{
	[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")
	$colorChoices=@("#0000CC","#00CC00","#FF0000","#2F4F4F","#006400","#9900CC","#FF0099","#62B5FC","#228B22","#000080")

	$scriptpath = Split-Path -parent $outputImageName

	$headers = $datasource | Get-Member -membertype NoteProperty | select -Property Name

	Write-Host "+++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor Yellow
	Write-Host "Output image: $outputImageName" -ForegroundColor Yellow

	Write-Host "Table to chart:" -ForegroundColor Yellow
	Write-Host "" -ForegroundColor Yellow
	Write-Host $datasource  -ForegroundColor Yellow
	Write-Host "+++++++++++++++++++++++++++++++++++++++++++ " -ForegroundColor Yellow

	# chart object
	$chart1 = New-object System.Windows.Forms.DataVisualization.Charting.Chart
	$chart1.Width = $width
	$chart1.Height = $height
	$chart1.BackColor = [System.Drawing.Color]::$BackColor

	# title 
	[void]$chart1.Titles.Add($title)
	$chart1.Titles[0].Font = "Arial,13pt"
	$chart1.Titles[0].Alignment = "topLeft"

	# chart area 
	$chartarea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
	$chartarea.Name = "ChartArea1"
	$chartarea.AxisY.Title = $yAxisTitle #$headers[$yAxisIndex]
	$chartarea.AxisY.Interval = $yAxisInterval
	$chartarea.AxisX.Interval = $xAxisInterval
	if ($xAxisTitle) {
		$chartarea.AxisX.Title = $xAxisTitle
	} else {
		$chartarea.AxisX.Title = $headers[$xAxisIndex].Name
	}
	$chart1.ChartAreas.Add($chartarea)


	# legend 
	$legend = New-Object system.Windows.Forms.DataVisualization.Charting.Legend
	$legend.name = "Legend1"
	$chart1.Legends.Add($legend)

	# chart data series
	$index=0
	#$index=$startChartingFromColumnIndex
	$headers | %{
		$header = $_.Name
		if ($index -ge $startChartingFromColumnIndex)# -and $index -lt $headers.Count)
	    {
			Write-Host "Creating new series: $($header)"
			[void]$chart1.Series.Add($header)
			$chart1.Series[$header].ChartType = $chartType #Line,Column,Pie
			$chart1.Series[$header].BorderWidth  = 3
			$chart1.Series[$header].IsVisibleInLegend = $true
			$chart1.Series[$header].chartarea = "ChartArea1"
			$chart1.Series[$header].Legend = "Legend1"
			Write-Host "Colour choice is $($colorChoices[$index])"
			$chart1.Series[$header].color = "$($colorChoices[$index])"
		#   $datasource | ForEach-Object {$chart1.Series["VMCount"].Points.addxy( $_.date , ($_.VMCountorySize / 1000000)) }
			$datasource | %{
				$chart1.Series[$header].Points.addxy( $_.date , $_.$header )
			}
		}
		$index++;
	}
	# save chart
	$chart1.SaveImage($outputImageName,$fileType) 

}


function mergeTables(
	[Parameter(Mandatory=$true)][string]$lookupColumn,
	[Parameter(Mandatory=$true)][Object]$refTable,
	[Parameter(Mandatory=$true)][Object]$lookupTable
)
{
	$dict=$lookupTable | group $lookupColumn -AsHashTable -AsString
	$additionalProps=diff ($refTable | gm -MemberType NoteProperty | select -ExpandProperty Name) ($lookupTable | gm -MemberType NoteProperty |
		select -ExpandProperty Name) |
		where {$_.SideIndicator -eq "=>"} | select -ExpandProperty InputObject
	$intersection=diff $refTable $lookupTable -Property $lookupColumn -IncludeEqual -ExcludeDifferent -PassThru 
	foreach ($prop in $additionalProps) { $refTable | Add-Member -MemberType NoteProperty -Name $prop -Value $null -Force}
	foreach ($item in ($refTable | where {$_.SideIndicator -eq "=="})){
		$lookupKey=$(foreach($key in $lookupColumn) { $item.$key} ) -join ""
		$newVals=$dict."$lookupKey" | select *
		foreach ( $prop in $additionalProps){
			$item.$prop=$newVals.$prop
		}
	}
	$refTable | select * -ExcludeProperty SideIndicator
}
#
# This file contains a collection of parame
#
function Get-myCredentials (
			[Parameter(Mandatory=$true)][string]$User,
		  	[Parameter(Mandatory=$true)][string]$SecureFileLocation)
{
	$password = Get-Content $SecureFileLocation | ConvertTo-SecureString 
	$credential = New-Object System.Management.Automation.PsCredential($user,$password)
	if ($credential)
	{
		return $credential
	} else {
		return $null
	}
}

# Main function
#Add-pssnapin VMware.VimAutomation.Core
function getRuntimeDate()
{
	#return [date]$global:runtime
	
}
function getRuntimeDateString()
{
	return $global:runtime
	
}

function getCapacityInGB([string]$capacity)
{
	#$number,$unit=$capacity.Split(" ")
	try {
	
			$capacity = $capacity -replace "for OS", "" -replace "TB GB","TB" -replace "for data","" -replace "N/A","0" -replace ".:\\\s*", "" -replace ",","" # -replace ".:\\", ""  -replace "\s","" -replace "?:\\", "" -replace "C:\\", ""
		if ($capacity.Contains("KB"))
		{
			$number=$capacity.Replace("KB","").Trim()
			return $((iex $number) / 1024 / 1024)
		} elseif ($capacity.Contains("MB"))
		{
			
			$number=$capacity.Replace("MB","").Trim()
			return $((iex $number) / 1024)
			
		} elseif ($capacity.Contains("GB"))
		{
			$number=$capacity.Replace("GB","").Trim()
			return $(iex $number)
		} elseif ($capacity.Contains("TB"))
		{
			$number=$capacity.Replace("TB","").Trim()
			return $((iex $number) / 1024 * 1024 * 1024)
		} else {
			return 0
		}
	} catch { 
            Write-Warning "Value $capacity $_" 
     }#End Catch 
}

#getCapacityInGB -capacity "1 TB"

# Functions
function Export-ExcelWorkSheetsToMultipleCSV ([string]$excelFileName, [string]$csvLoc)
{
    $excelFile = $excelFileName
    $excelObj = New-Object -ComObject Excel.Application
    $excelObj.Visible = $false
    $excelObj.DisplayAlerts = $false
    $workbook = $excelObj.Workbooks.Open($excelFile)
    foreach ($worksheet in $workbook.Worksheets)
    {
		$filename,$filetype=(Split-Path -Path $excelFileName -Leaf).Split(".")
        $sheetName = ($filename+ "-" + $worksheet.Name).Replace(",","")
		Write-Host "Processing worksheet: $sheetName..."
		$worksheet.SaveAs("$csvLoc\$sheetName.csv", 6)
    }
    $excelObj.Quit()
}


function getCapacityInGiga([string]$capacity)
{
	#$number,$unit=$capacity.Split(" ")
	try {
	
			$capacity = $capacity -replace "for OS", "" -replace "TB GB","TB" -replace "for data","" -replace "N/A","0" -replace ".:\\\s*", "" -replace ",","" # -replace ".:\\", ""  -replace "\s","" -replace "?:\\", "" -replace "C:\\", ""
		if ($capacity.Contains("KB") -or $capacity.Contains("KHz") -or $capacity.Contains("Kbps") -or $capacity.Contains("Kps"))
		{
			$number,$other=$capacity -split "\s*K\s*"
			return $((iex $number) / 1024 / 1024)
		} elseif ($capacity.Contains("MB") -or $capacity.Contains("MHz") -or $capacity.Contains("Mbps") -or $capacity.Contains("Mps"))
		{
			$number,$other=$capacity -split "\s*M\s*"
			return $((iex $number) / 1024)
			
		} elseif ($capacity.Contains("GB") -or $capacity.Contains("GHz") -or $capacity.Contains("Gbps") -or $capacity.Contains("Gps"))
		{
			$number,$other=$capacity -split "\s*G\s*"
			return $((iex $number) * 1)
		} elseif ($capacity.Contains("TB") -or $capacity.Contains("THz") -or $capacity.Contains("Tbps") -or $capacity.Contains("Tps"))
		{
			$number,$other=$capacity -split "\s*T\s*"
			return $((iex $number) * 1024)
		} elseif ($capacity.Contains("PB") -or $capacity.Contains("PHz") -or $capacity.Contains("Pbps") -or $capacity.Contains("Pps"))
		{
			$number,$other=$capacity -split "\s*P\s*"
			return $((iex $number) * 1024 * 1024)
		} else {
			return 0
		}
	} catch { 
            Write-Warning "Value $capacity $_" 
     }#End Catch 
}