############## CUSTOMER PROPERTIES DECLARATION
<#Add-Type @"
Class MetaInfo
{
	[string]"TableHeader"
	[string]"Introduction"
	[string]"Chartable"
	[int[]]"TitleHeaderType"
	[string]"ShowTableCaption"
	#[string[]]"DisplayTableOrientation"="List","Table","None";
}
"@#>

$global:colours = @{
	"Information"="Yellow";
	"Error"="Red";
	"ChangeMade"="Blue";
	"Highlight"="Green";
	"Note"=""
}

## LOGING OPTIONS
[bool]$global:logTofile = $false
[bool]$global:logInMemory = $true
[bool]$global:logToScreen = $true

<#
		function declarations
#>
function setLoggingDirectory([string]$dirPath)
{
	if (!$dirPath)
	{
		$global:logDir=".\output"
	} else {
		$global:logDir=$dirPath
	}
}

function showError ([Parameter(Mandatory=$true)][string] $msg, $errorColor=$global:colours.Error)
{
	logThis ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" -ForegroundColor $errorColor
	logThis ">> " -ForegroundColor $errorColor
	logThis ">> $msg" -ForegroundColor $errorColor
	logThis ">> " -ForegroundColor $errorColor
	logThis ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" -ForegroundColor $errorColor
}

function verboseThis ([Parameter(Mandatory=$true)][object] $msg, $colour=$global:colours.Highlight)
{
	logThis ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" -ForegroundColor $colour
	logThis ">> " -ForegroundColor $colour
	logThis ">> $msg" -ForegroundColor $colour
	logThis ">> " -ForegroundColor $colour
	logThis ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" -ForegroundColor $colour
}

function getRuntimeLogFileContent()
{
	if ($global:runtimeLogFile) { return get-content $global:runtimeLogFile }
	if ($global:logInMemory ) { return Get-Content $global:logInMemory }
	#Get-Content $logFile
}


function printToScreen([string]$msg,[string]$ForegroundColor="Yellow")
{
	if (!$global:silent)
	{
		logThis -msg $msg -ForegroundColor $ForegroundColor
	}
}

function getmycredentialsfromFile (
	[Parameter(Mandatory=$true)][string]$User,
	[Parameter(Mandatory=$true)][string]$SecureFileLocation) 
{
	#logThis -msg $SecureFileLocation
	$password = Get-Content $SecureFileLocation | ConvertTo-SecureString 
	return (New-Object System.Management.Automation.PsCredential($user,$password))
}

function set-mycredentials ([string]$filename)
{

	#$Credential = Get-Credential -Message "Enter your credentials for this connection: "
	# old versions of powershell can't display custom messages
	$Credential = Get-Credential #-Message "Enter your credentials for this connection: "
	$credential.Password | ConvertFrom-SecureString | Set-Content $filename
}

########################################################################################
# examples
# $card = Get-HashtableAsObject @{
#	Card = {2..9 + "Jack", "Queen", "King", "Ace" | Get-Random}
#	Suit = {"Clubs", "Hearts", "Diamonds", "Spades" | Get-Random}
# }
# $card
#
# $userInfo = @{
#    LocalUsers = {Get-WmiObject "Win32_UserAccount WHERE LocalAccount='True'"}
#    LoggedOnUsers = {Get-WmiObject "Win32_LoggedOnUser" }    
# }
# $liveUserInfo = Get-HashtableAsObject $userInfo
function Get-HashtableAsObject([Hashtable]$hashtable)
{  
    #.Synopsis
    #    Turns a Hashtable into a PowerShell object
    #.Description
    #    Creates a new object from a hashtable.
    #.Example
    #    # Creates a new object with a property foo and the value bar
    #    Get-HashtableAsObject @{"Foo"="Bar"}
    #.Example
    #    # Creates a new object with a property Random and a value
    #    # that is generated each time the property is retreived
    #    Get-HashtableAsObject @{"Random" = { Get-Random }}
    #.Example
    #    # Creates a new object from a hashtable with nested hashtables
    #    Get-HashtableAsObject @{"Foo" = @{"Random" = {Get-Random}}} 
    process {       
        $outputObject = New-Object Object
        if ($hashtable -and $hashtable.Count) {
            $hashtable.GetEnumerator() | Foreach-Object {
                if ($_.Value -is [ScriptBlock]) {
                    $outputObject = $outputObject | 
                        Add-Member ScriptProperty $_.Key $_.Value -passThru
                } else {
                    if ($_.Value -is [Hashtable]) {
                        $outputObject = $outputObject | 
                            Add-Member NoteProperty $_.Key (Get-HashtableAsObject $_.Value) -passThru
                    } else {                    
                        $outputObject = $outputObject | 
                            Add-Member NoteProperty $_.Key $_.Value -passThru
                    }
                }                
            }
        }
        $outputObject
    }
}

function sendEmail
	(	[Parameter(Mandatory=$true)][string] $smtpServer,  
		[Parameter(Mandatory=$true)][string] $from, 
		[Parameter(Mandatory=$true)][string] $replyTo=$from, 
		[Parameter(Mandatory=$true)][string] $toAddress,
		[Parameter(Mandatory=$true)][string] $subject, 
		[Parameter(Mandatory=$true)][string] $body="",
		[Parameter(Mandatory=$false)][PSCredential] $credentials,
		[Parameter(Mandatory=$false)][string]$fromContactName="",
		[Parameter(Mandatory=$false)][object] $attachments # An array of filenames with their full path locations
		
	) 
{
	logThis -msg "[$attachments]" -ForegroundColor $global:colours.ChangeMade
	if (!$smtpServer -or !$from -or !$replyTo -or !$toAddress -or !$subject -or !$body)
	{
		logThis -msg "Cannot Send email. Missing parameters for this function. Note that All fields must be specified" -BackgroundColor $global:colours.Error -ForegroundColor $global:colours.Information
		logThis -msg "smtpServer = $smtpServer"
		logThis -msg "from = $from"
		logThis -msg "replyTo = $replyTo"
		logThis -msg "toAddress = $toAddress"
		logThis -msg "subject = $subject"
		logThis -msg "body = $body"
	} else {
		if ($attachments)
		{
			
			<#$attachments | %{
				#logThis -msg $_ -ForegroundColor $global:colours.ChangeMade
				$attachment = new-object System.Net.Mail.Attachment($_,"Application/Octet")
				$msg.Attachments.Add($attachment)
			}
			#>
			logThis -msg "Sending email with attachments"
			Send-MailMessage -SmtpServer $smtpServer -Credential $Credentials -From $from -Subject $subject -To $toAddress -BodyAsHtml $body -Attachments $(([string]$attachments).Trim() -replace ' ',',')
		} else {
			logThis -msg "Sending email without attachments"
			Send-MailMessage -SmtpServer $smtpServer -Credential $Credentials -From $from -Subject $subject -To $toAddress -BodyAsHtml $body -DeliveryNotificationOption OnFailure
		}
	}
}

function New-ZipFile {
	#.Synopsis
	#  Create a new zip file, optionally appending to an existing zip...
	[CmdletBinding()]
	param(
		# The path of the zip to create
		[Parameter(Position=0, Mandatory=$true)]
		$ZipFilePath,
 
		# Items that we want to add to the ZipFile
		[Parameter(Position=1, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
		[Alias("PSPath","Item")]
		[string[]]$InputObject = $Pwd,
 
		# Append to an existing zip file, instead of overwriting it
		[Switch]$Append,
 
		# The compression level (defaults to Optimal):
		#   Optimal - The compression operation should be optimally compressed, even if the operation takes a longer time to complete.
		#   Fastest - The compression operation should complete as quickly as possible, even if the resulting file is not optimally compressed.
		#   NoCompression - No compression should be performed on the file.
		[System.IO.Compression.CompressionLevel]$Compression = "Optimal"
	)
	begin {
		# Make sure the folder already exists
		Add-Type -As System.IO.Compression.FileSystem
		[string]$File = Split-Path $ZipFilePath -Leaf
		[string]$Folder = $(if($Folder = Split-Path $ZipFilePath) { Resolve-Path $Folder } else { $Pwd })
		$ZipFilePath = Join-Path $Folder $File
		# If they don't want to append, make sure the zip file doesn't already exist.
		if(!$Append) {
			if(Test-Path $ZipFilePath) { Remove-Item $ZipFilePath }
		}
		$Archive = [System.IO.Compression.ZipFile]::Open( $ZipFilePath, "Update" )
	}
	process {
		foreach($path in $InputObject) {
			foreach($item in Resolve-Path $path) {
				# Push-Location so we can use Resolve-Path -Relative
				Push-Location (Split-Path $item)
				# This will get the file, or all the files in the folder (recursively)
				foreach($file in Get-ChildItem $item -Recurse -File -Force | % FullName) {
					# Calculate the relative file path
					$relative = (Resolve-Path $file -Relative).TrimStart(".\")
					# Add the file to the zip
					$null = [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($Archive, $file, $relative, $Compression)
				}
				Pop-Location
			}
		}
	}
	end {
		$Archive.Dispose()
		Get-Item $ZipFilePath
	}
}
     
     
function Expand-ZipFile {
	#.Synopsis
	#  Expand a zip file, ensuring it's contents go to a single folder ...
	[CmdletBinding()]
	param(
		# The path of the zip file that needs to be extracted
		[Parameter(ValueFromPipelineByPropertyName=$true, Position=0, Mandatory=$true)]
		[Alias("PSPath")]
		$FilePath,
 
		# The path where we want the output folder to end up
		[Parameter(Position=1)]
		$OutputPath = $Pwd,
 
		# Make sure the resulting folder is always named the same as the archive
		[Switch]$Force
	)
	process {
		Add-Type -As System.IO.Compression.FileSystem
		$ZipFile = Get-Item $FilePath
		$Archive = [System.IO.Compression.ZipFile]::Open( $ZipFile, "Read" )
 
		# Figure out where we'd prefer to end up
		if(Test-Path $OutputPath) {
			# If they pass a path that exists, we want to create a new folder
			$Destination = Join-Path $OutputPath $ZipFile.BaseName
		} else {
			# Otherwise, since they passed a folder, they must want us to use it
			$Destination = $OutputPath
		}
 
		# The root folder of the first entry ...
		$ArchiveRoot = ($Archive.Entries[0].FullName -Split "/|\\")[0]
 
		Write-Verbose "Desired Destination: $Destination"
		Write-Verbose "Archive Root: $ArchiveRoot"
 
		# If any of the files are not in the same root folder ...
		if($Archive.Entries.FullName | Where-Object { @($_ -Split "/|\\")[0] -ne $ArchiveRoot }) {
			# extract it into a new folder:
			New-Item $Destination -Type Directory -Force
			[System.IO.Compression.ZipFileExtensions]::ExtractToDirectory( $Archive, $Destination )
		} else {
			# otherwise, extract it to the OutputPath
			[System.IO.Compression.ZipFileExtensions]::ExtractToDirectory( $Archive, $OutputPath )
 
			# If there was only a single file in the archive, then we'll just output that file...
			if($Archive.Entries.Count -eq 1) {
				# Except, if they asked for an OutputPath with an extension on it, we'll rename the file to that ...
				if([System.IO.Path]::GetExtension($Destination)) {
					Move-Item (Join-Path $OutputPath $Archive.Entries[0].FullName) $Destination
				} else {
					Get-Item (Join-Path $OutputPath $Archive.Entries[0].FullName)
				}
			} elseif($Force) {
				# Otherwise let's make sure that we move it to where we expect it to go, in case the zip's been renamed
				if($ArchiveRoot -ne $ZipFile.BaseName) {
					Move-Item (join-path $OutputPath $ArchiveRoot) $Destination
					Get-Item $Destination
				}
			} else {
				Get-Item (Join-Path $OutputPath $ArchiveRoot)
			}
		}
 
		$Archive.Dispose()
	}
}


function Set-Credentials ([Parameter(Mandatory=$true)][string]$File="securestring.txt")
{
	# This will prompt you for credentials -- be sure to be calling this function from the appropriate user 
	# which will decrypt the password later on
	$Credential = Get-Credential
	$credential.Password | ConvertFrom-SecureString | Set-Content $File
}


# Add the aliases ZIP and UNZIP
#new-alias zip new-zipfile
#new-alias unzip expand-zipfile


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

	logThis -msg  "+++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor $global:colours.Information
	logThis -msg  "Output image: $outputImageName" -ForegroundColor $global:colours.Information

	logThis -msg  "Table to chart:" -ForegroundColor $global:colours.Information
	logThis -msg  "" -ForegroundColor $global:colours.Information
	logThis -msg  $datasource  -ForegroundColor $global:colours.Information
	logThis -msg  "+++++++++++++++++++++++++++++++++++++++++++ " -ForegroundColor $global:colours.Information

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
			logThis -msg  "Creating new series: $($header)"
			[void]$chart1.Series.Add($header)
			$chart1.Series[$header].ChartType = $chartType #Line,Column,Pie
			$chart1.Series[$header].BorderWidth  = 3
			$chart1.Series[$header].IsVisibleInLegend = $true
			$chart1.Series[$header].chartarea = "ChartArea1"
			$chart1.Series[$header].Legend = "Legend1"
			logThis -msg  "Colour choice is $($colorChoices[$index])"
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
	return get-date "$([System.DateTime]::DaysInMonth((get-date $day).Year, (get-date $day).Month)) / $((get-date $day).Month) / $((get-date $day).Year) 23:59:59"
}

function getMonthYearColumnFormatted([DateTime]$day)
{
	return Get-Date $day -Format "MMM yyyy"
}

function daysSoFarInThisMonth([DateTime] $day)
{
	return $day.Day
}

function createChart(
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
	#$content += (Get-content $global:htmlHeaderCSS)
	#$content += @"

	$content = @"
	<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">
	<html><head><title>Report</title>
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
	return $content

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
	[Parameter(Mandatory=$true)]$var
)
{
	#logThis -msg  $("{0:n2}" -f $val)
	#logThis -msg $($var.gettype().Name)
	if ($(isNumeric $var))
	{
		return "{0:n2}" -f $var
	} else {
		return printNoData
	}
	#return "$([math]::Round($val,2))"
}

function showError ([Parameter(Mandatory=$true)][string] $msg, $errorColor="Red")
{
	logThis -msg ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" -ForegroundColor $errorColor
	logThis -msg ">> " -ForegroundColor $errorColor
	logThis -msg ">> $msg" -ForegroundColor $errorColor
	logThis -msg ">> " -ForegroundColor $errorColor
	logThis -msg ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" -ForegroundColor $errorColor
}

function verboseThis ([Parameter(Mandatory=$true)][object] $msg, $errorColor="Cyan")
{
	logThis -msg ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" -ForegroundColor $errorColor
	logThis -msg ">> " -ForegroundColor $errorColor
	logThis -msg ">> $msg" -ForegroundColor $errorColor
	logThis -msg ">> " -ForegroundColor $errorColor
	logThis -msg ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" -ForegroundColor $errorColor
}

#Log To Screen and file
function logThis (
	[Parameter(Mandatory=$true)][string] $msg, 
	[Parameter(Mandatory=$false)][string] $logFile,
	[Parameter(Mandatory=$false)][string] $ForegroundColor = "yellow",
	[Parameter(Mandatory=$false)][string] $BackgroundColor = "black",
	[Parameter(Mandatory=$false)][bool]$logToScreen = $false,
	[Parameter(Mandatory=$false)][bool]$NoNewline = $false,
	[Parameter(Mandatory=$false)][bool]$keepLogInMemoryAlso=$false
	)
{
	if ($global:logToScreen -or $logToScreen -and !$global:silent)
	{
		# Also verbose to screent
		if ($NoNewline)
		{
			Write-host $msg -ForegroundColor $ForegroundColor -NoNewline;
		} else {
			Write-host "$msg" -ForegroundColor $ForegroundColor;
		}
	} 
	if ($global:logTofile)
	{
		#logThis -msg "Also writing message to file.log"
		
		if ($logFile) { "$msg`n"  | out-file -filepath $logFile -append}
		if ((Test-Path -path $global:logDir) -ne $true) {
					
			New-Item -type directory -Path $global:logDir
			$childitem = Get-Item -Path $global:logDir
			$global:logDir = $childitem.FullName
		}	
		if ($global:runtimeLogFile)
		{
			"$msg`n" | out-file -filepath $global:runtimeLogFile -append
		} 
	}	
	if ($global:logInMemory -or $keepLogInMemoryAlso)
	{
		$global:runtimeLogFileInMemory += "$msg`n"
	}
}

function getRuntimeLogFileContent()
{
	if ($global:logTofile -and $global:runtimeLogFile) { return get-content $global:runtimeLogFile }
	if ($global:logInMemory ) { return $global:runtimeLogFileInMemory }
	#Get-Content $logFile
}

function SetmyLogFile(
		[Parameter(Mandatory=$true)][string] $filename
	)
{
	if($global:runtimeLogFile)
	{
		$global:runtimeLogFile = $filename
	} else {
		Set-Variable -Name runtimeLogFile -Value $filename -Scope Global
	}
	
	# Empty the file
	#"" | out-file -filepath $global:runtimeLogFile
	logThis -msg "This script will be logging to $global:runtimeLogFile"
}

function SetmyCSVOutputFile(
		[Parameter(Mandatory=$true)][string] $filename
	)
{
	#logThis -msg "[SetmyCSVOutputFile] This script will log all data output to CSV file called $global:runtimeCSVOutput"
	$global:runtimeCSVOutput = $filename
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
	Write-Output $msg >> $global:runtimeCSVOutput
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
	$filename=$global:runtimeCSVOutput
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
	Invoke-Expression $global:runtimeCSVOutput
}


#######################################################################
# Logger Module - Used to log script runtime and output to screen
#######################################################################
# Source = VM (VirtualMachineImpl) or ESX objects(VMHostImpl)
# metrics = @(), an array of valid metrics for the object passed
# filters = @(), and array which contains inclusive filtering strings about specific Hardware Instances to filter the results so that they are included 
# returns a script of HTML or CSV or what
function compareString([string] $first, [string] $second, [switch] $ignoreCase)
{
	 
	# No NULL check needed
	# PowerShell parameter handling converts Nulls into empty strings
	# so we will never get a NULL string but we may get empty strings(length = 0)
	#########################
	 
	$len1 = $first.length
	$len2 = $second.length
	 
	# If either string has length of zero, the # of edits/distance between them
	# is simply the length of the other string
	#######################################
	if($len1 -eq 0)
	{ return $len2 }
	 
	if($len2 -eq 0)
	{ return $len1 }
	 
	# make everything lowercase if ignoreCase flag is set
	if($ignoreCase -eq $true)
	{
	  $first = $first.tolowerinvariant()
	  $second = $second.tolowerinvariant()
	}
	 
	# create 2d Array to store the "distances"
	$dist = new-object -type 'int[,]' -arg ($len1+1),($len2+1)
	 
	# initialize the first row and first column which represent the 2
	# strings we're comparing
	for($i = 0; $i -le $len1; $i++) 
	{  $dist[$i,0] = $i }
	for($j = 0; $j -le $len2; $j++) 
	{  $dist[0,$j] = $j }
	 
	$cost = 0
	 
	for($i = 1; $i -le $len1;$i++)
	{
	  for($j = 1; $j -le $len2;$j++)
	  {
	    if($second[$j-1] -ceq $first[$i-1])
	    {
	      $cost = 0
	    }
	    else   
	    {
	      $cost = 1
	    }
	    
	    # The value going into the cell is the min of 3 possibilities:
	    # 1. The cell immediately above plus 1
	    # 2. The cell immediately to the left plus 1
	    # 3. The cell diagonally above and to the left plus the 'cost'
	    ##############
	    # I had to add lots of parentheses to "help" the Powershell parser
	    # And I separated out the tempmin variable for readability
	    $tempmin = [System.Math]::Min(([int]$dist[($i-1),$j]+1) , ([int]$dist[$i,($j-1)]+1))
	    $dist[$i,$j] = [System.Math]::Min($tempmin, ([int]$dist[($i-1),($j-1)] + $cost))
	  }
	}
	 
	# the actual distance is stored in the bottom right cell
	return $dist[$len1, $len2];
}
 
function setSectionHeader (
		[Parameter(Mandatory=$true)][ValidateSet('h1','h2','h3','h4','h5')][string]$type="h1",
		[Parameter(Mandatory=$true)][object]$title,
		[Parameter(Mandatory=$false)][object]$text
	)
{
	$csvFilename=(getRuntimeCSVOutput) -replace ".csv","-$($title -replace ' ','_').csv"
	$metaFilename=$csvFilename -replace '.csv','.nfo'
	$metaInfo = @()
	$metaInfo +="tableHeader=$title $SHOWCOMMANDS"	
	$metaInfo +="titleHeaderType=$type"
	if ($text) { $metaInfo +="introduction=$text" }
	#$metaInfo +="displayTableOrientation=$displayTableOrientation"
	#$metaInfo +="chartable=false"
	#$metaInfo +="showTableCaption=$showTableCaption"
	#if ($metaAnalytics) {$metaInfo += $metaAnalytics}
	#ExportCSV -table $dataTable -thisFileInstead $csvFilename 
	ExportMetaData -metadata $metaInfo -thisFileInstead $metaFilename
	updateReportIndexer -string "$(split-path -path $csvFilename -leaf)"
}

function convertEpochDate([Parameter(Mandatory=$true)][double]$sec)
{
	$dayone=get-date "1-Jan-1970"
	return $(get-date $dayone.AddSeconds([double]$sec) -format "dd-MM-yyyy hh:mm:ss")
}

function getTimeSpanFormatted($timespan)
{
	$timeTakenStr=""
	if ($timespan.Days -gt 0)
	{
		$timeTakenStr += "$($timespan.days) days "
	}
	if ($timespan.Hours -gt 0)
	{
		$timeTakenStr += "$($timespan.Hours) hrs "
	}
	if ($timespan.Minutes -gt 0)
	{
		$timeTakenStr += "$($timespan.Minutes) min "
	}
	if ($timespan.Seconds -gt 0)
	{
		$timeTakenStr += "$($timespan.Seconds) sec "
	}
	return $timeTakenStr
}


function getSize($TotalKB,$unit,$val)
{

	if ($TotalKB) { $unit="KB"; $val=$TotalKB}
	
	if ($unit -eq "B") { $bytes=$val}
	elseif ($unit -eq "KB") { $bytes=$val*1KB }
	elseif ($unit -eq "MB") {  $bytes=$val*1MB }
	elseif ($unit -eq "GB") { $bytes=$val*1GB }
	elseif ($unit -eq "TB") { $bytes=$val*1TB }
	elseif ($unit -eq "GB") { $bytes=$val*1PB }
	
	If ($bytes -lt 1MB) # Format TotalKB to reflect: 
    { 
     $value = "{0:N} KB" -f $($bytes/1KB) # KiloBytes or, 
    } 
    If (($bytes -ge 1MB) -AND ($bytes -lt 1GB)) 
    { 
     $value = "{0:N} MB" -f $($bytes/1MB) # MegaBytes or, 
    } 
    If (($bytes -ge 1GB) -AND ($bytes -lt 1TB)) 
     { 
     $value = "{0:N} GB" -f $($bytes/1GB) # GigaBytes or, 
    } 
    If ($bytes -ge 1TB -and $bytes -lt 1PB)
    { 
     $value = "{0:N} TB" -f $($bytes/1TB) # TeraBytes 
    }
	If ($bytes -ge 1PB) 
  	 { 
		$value = "{0:N} PB" -f $($bytes/1PB) # TeraBytes 
    }
	return $value
}

function getSpeed($unit="KBps", $val) #$TotalBps,$kbps,$TotalMBps,$TotalGBps,$TotalTBps,$TotalPBps)
{
	if ($unit -eq "bps") { $bytesps=$val }
	elseif ($unit -eq "kbps") { $bytesps=$val*1KB }
	elseif ($unit -eq "mbps") {  $bytesps=$val*1MB }
	elseif ($unit -eq "gbps") { $bytesps=$val*1GB }
	elseif ($unit -eq "tbps") { $bytesps=$val*1TB }
	elseif ($unit -eq "pbps") { $bytesps=$val*1PB }
	
	If ($bytesps -lt 1MB) # Format TotalKB to reflect: 
    { 
     $value = "{0:N} KBps" -f $($bytesps/1KB) # KiloBytes or, 
    } 
    If (($bytesps -ge 1MB) -AND ($bytesps -lt 1GB)) 
    { 
     $value = "{0:N} MBps" -f $($bytesps/1MB) # MegaBytes or, 
    } 
    If (($bytesps -ge 1GB) -AND ($bytesps -lt 1TB)) 
     { 
     $value = "{0:N} GBps" -f $($bytesps/1GB) # GigaBytes or, 
    } 
    If ($bytesps -ge 1TB -and $bytesps -lt 1PB)
    { 
     $value = "{0:N} TBps" -f $($bytesps/1TB) # TeraBytes 
    }
	 If ($bytesps -ge 1PB) 
    { 
     $value = "{0:N} PBps" -f $($bytesps/1PB) # TeraBytes 
    }
	return $value
}
#getSpeed -unit $unit 100
function convertValue($unit,$val)
{
	switch($unit)
	{
		"%"    { $value = "{0:N} %" -f $val; $type="perc" }
		"bps"  { $bytes=$val; type="speed" }
		"kbps" { $bytes=$val*1KB; type="speed" }
		"mbps" {  $bytes=$val*1MB; type="speed" }
		"gbps" { $bytes=$val*1GB; type="speed" }
		"tbps" { $bytes=$val*1TB; type="speed" }
		"pbps" { $bytes=$val*1PB; type="speed" }
		"bytes"{ $bytes=$val; type="size" }
		"KB" { $bytes=$val*1KB; type="size"}
		"MB" { $bytes=$val*1MB; type="size"}
		"GB" { $bytes=$val*1GB; type="size"}
		"TB" { $bytes=$val*1TB; type="size"}
		"PB" { $bytes=$val*1PB; type="size"}
		"Hz" { $bytes=$val; type="frequency"}
		"Khz" { $bytes=$val*1000; type="frequency"}
		"Mhz" { $bytes=$val*1000*1000; type="frequency"}
		"Ghz" { $bytes=$val*1000*1000*1000; type="frequency"}
		"Thz" { $bytes=$val*1000*1000*1000*1000; type="frequency"}
	}
}

function SetmyCSVMetaFile(
	[Parameter(Mandatory=$true)][string] $filename
	)
{	
	if($global:runtimeCSVMetaFile)
	{
		$global:runtimeCSVMetaFile = $filename
	} else {
		Set-Variable -Name runtimeCSVMetaFile -Value $filename -Scope Global
	}
}

###############################################
# CSV META FILES
###############################################
# Meta data needed by the porting engine to 
# These are the available fields for each report
#$metaInfo = @()
function New-MetaInfo {
    param(
        [Parameter(Mandatory=$true)][string]$file,
		[Parameter(Mandatory=$true)][string]$TableHeader,
		[Parameter(Mandatory=$false)][string]$Introduction,
        [Parameter(Mandatory=$false)][ValidateSet('h1','h2','h3','h4','h5',$null)][string]$titleHeaderType="h1",
		[Parameter(Mandatory=$false)][ValidateSet('false','true')][string]$TableShowCaption='false',
		[Parameter(Mandatory=$false)][ValidateSet('Table','List')][string]$TableOrientation='Table',		
		[Parameter(Mandatory=$false)]$displaytable="true",
		[Parameter(Mandatory=$false)]$TopConsumer=10,
		[Parameter(Mandatory=$false)]$Top_Column,
		[Parameter(Mandatory=$false)]$chartStandardWidth="800",
		[Parameter(Mandatory=$false)]$chartStandardHeight="400",
		[Parameter(Mandatory=$false)][ValidateSet('png')]$chartImageFileType="png",
		[Parameter(Mandatory=$false)][ValidateSet('StackedBar100')]$chartType="StackedBar100",
		[Parameter(Mandatory=$false)]$chartText,
		[Parameter(Mandatory=$false)]$chartTitle,
		[Parameter(Mandatory=$false)]$yAxisTitle="%",
		[Parameter(Mandatory=$false)]$xAxisTitle="/",
		[Parameter(Mandatory=$false)]$startChartingFromColumnIndex=1,
		[Parameter(Mandatory=$false)]$yAxisInterval=10,
		[Parameter(Mandatory=$false)]$yAxisIndex=1,
		[Parameter(Mandatory=$false)]$xAxisIndex=0, 
		[Parameter(Mandatory=$false)]$xAxisInterval=-1,
		[Parameter(Mandatory=$false)][Object]$Table
	)
    New-Object psobject -property @{
        file = $file
		Table = $null
		TableHeader = $TableHeader
		TableOrientation = $displayTableOrientation
		TableShowCaption = $TableShowCaption
		Introduction = $Introduction
		titleHeaderType = $titleHeaderType
		displaytable = $displaytable
		generateTopConsumers = $generateTopConsumers
		generateTopConsumersSortByColumn = $generateTopConsumersSortByColumn
		chartStandardWidth = $chartStandardWidth
		chartStandardHeight = $chartStandardHeight
		chartImageFileType = $chartImageFileType
		chartType = $chartType
		chartText = $chartText
		chartTitle = $chartTitle
		yAxisTitle = $yAxisTitle
		xAxisTitle = $xAxisTitle
		startChartingFromColumnIndex = $startChartingFromColumnIndex
		yAxisInterval = $yAxisInterval
		yAxisIndex = $yAxisIndex
		xAxisIndex= $xAxisIndex
		xAxisInterval = $xAxisInterval
		
    }
}

function ExportMetaData([Parameter(Mandatory=$true)][object[]] $metaData, [Parameter(Mandatory=$false)]$thisFileInstead)
{
	if ((Test-Path -path $global:logDir) -ne $true) {
		New-Item -type directory -Path $global:logDir
		$childitem = Get-Item -Path $global:logDir
		$global:logDir = $childitem.FullName
	}
	
	$tmpMetafile = $global:runtimeCSVMetaFile
	if( $thisFileInstead)
	{
		$tmpMetafile = $thisFileInstead
	}
	#if ($global:runtimeCSVMetaFile)
	if ($global:logTofile -and $tmpMetafile)
	{
		 $metadata | Out-File -FilePath $tmpMetafile
	}
}
function getRuntimeMetaFile()
{
	return "$global:runtimeCSVMetaFile"
}

function setRuntimeMetaFile([string]$filename)
{
	$global:runtimeCSVMetaFile = $filename
}

function updateRuntimeMetaFile([object[]] $metaData)
{
	if ($global:logTofile) { $metadata | Out-File -FilePath $global:runtimeCSVMetaFile -Append }
}

function getRuntimeCSVOutput()
{
	return "$global:runtimeCSVOutput"
}

function setReportIndexer($fullName)
{
	Set-Variable -Name reportIndex -Value $fullName -Scope Global
}

function getReportIndexer()
{
	return $global:reportIndex
}

function updateReportIndexer($string)
{
	if ($global:logTofile) 
	{
		$string -replace ".csv",".nfo" -replace ".ps1",".nfo" -replace ".log",".nfo" | Out-file -Append -FilePath $global:reportIndex 
	}
}
#######################################################################################################
# Generate Reports from XML to HTML
#######################################################################################################
function generateHTMLReport(
			[Parameter(Mandatory=$true)][string]$reportHeader,
			[Parameter(Mandatory=$true)][string]$reportIntro,
			[Parameter(Mandatory=$true)][string]$farmName,
			[Parameter(Mandatory=$False)][bool]$openReportOnCompletion=$False,
			[Parameter(Mandatory=$true)][string]$itoContactName,
			[Parameter(Mandatory=$false)][string]$css,
			[Parameter(Mandatory=$true)]$xml)
{
	$htmlPage = htmlHeader
	$htmlPage += "`n<h1>$reportHeader</h1>"
	$htmlPage += "`n<p>$reportIntro</p>"
	$reportTitles = $xml.keys | ?{$_ -ne "Runtime"}	
	logThis -msg "Keys = $([string]$reportTitles)"
	$index=1
	$reportTitles | %{		
		#$subReportXML = $_
		$reportTitle = $_
		Write-Progress -Id 1 -Activity "Processing $reportTitle" -CurrentOperation "$index/$($reportTitles.Count)" -PercentComplete $($index/$($reportTitles.Count)*100)
		logThis -msg "[$index / $($reportTitles.Count)] reportTitle = $_"
		$htmlPage += "`n<h1>$($reportTitle)</h1>"
		
		#LogThis -msg "$($xml.$reportTitle.
		$subReportsTitles = $xml.$reportTitle.Reports.keys
		#logThis -msg $subReportsTitles
		$subReportsTitles | %{
			$subReportsTitle = $_			
			$htmlPage +=  "<h2>$subReportsTitle</h2>"
			logThis -msg "subReportsTitle = $subReportsTitle"
			for ($jindex = 0 ; $jindex -lt $xml.$reportTitle.Reports.$subReportsTitle.Count; $jindex++)
			{			
				if ($xml.$reportTitle.Reports.$subReportsTitle[$jindex].MetaData)
				{
					$metaData = convertTextVariablesIntoObject ($xml.$reportTitle.Reports.$subReportsTitle[$jindex].MetaData)		
				} 
				$dataTable = $xml.$reportTitle.Reports.$subReportsTitle[$jindex].DataTable
				logThis -msg ">> [$($jindex+1)/$($xml.$reportTitle.Reports.$subReportsTitle.Count)] $($metaData.tableHeader)"
				<## if ($metaData)
				{
					Write-Output "<$($metaData.titleHeaderType)>$($metaData.tableHeader)</$($metaData.titleHeaderType)>"
					if ($metaData.introduction)
					{
						Write-Output "<p>$($metaData.introduction)</p>"
					}
				}
				if ($dataTable)
				{
					if ($metaData -and $metaData.displayTableOrientation)
					{

					}
				}
				#>
				$expectedPassesToMakeForTopConsumers = 2
				if ($metaData.generateTopConsumers)
				{
					# Report specifies that the report should generate a Top 10 (or other NUMBER) for this report, so need to make a second pass for the Top consumer report
					$passesToMake = $expectedPassesToMakeForTopConsumers
				} else {
					$passesToMake = 1
				}
			
				$passesSoFar=1;
				# If the report NFO file 
				while ($passesSoFar -le $passesToMake) 
				{
					if ($passesSoFar -eq $expectedPassesToMakeForTopConsumers)
					{
						$extraText = "(Top ($metaData.generateTopConsumers))"
					} else {
						$extraText = ""
					}
					
					if ($metaData.titleHeaderType)
					{	
						logThis -msg "`t-> Using header Type $($metaData.titleHeaderType) found in NFO $extraText" # -foregroundColor $color
						#$headerType = $metaData.titleHeaderType # + " " + $extraText
						$headerType = "h3"
						#Write-Host "Here $headerType  <<"
						#pause
					} else 
					{
						logThis -msg "`t-> No header types found in NFO, using H2 instead $extraText"  -ForegroundColor $global:colours.Information
						$headerType = "h3"
					}

					if ($metaData.tableHeader)
					{
						logThis -msg "`t-> Using heading from NFO: $($metaData.tableHeader) $extraText"  #-foregroundColor $color
						$htmlPage += "`n<$headerType>$($metaData.tableHeader) $extraText</$headerType>"
						#Write-Host $htmlPage
						#pause
						#Remove-Variable tableHeader
					
					} else {
						logThis -msg "`t-> Will derive Heading from the original filename" #-foregroundColor $color
						if ($vcenterName)
						{
							#$title = $metaData.Filename.Replace($runtime+"_","").Replace("$vcenterName","").Replace(".csv","").Replace("_"," ")
							$title = $metaData.Filename.Replace("$vcenterName","").Replace(".csv","").Replace("_"," ") + " " + $extraText
						} else {
							#$title = $metaData.Filename.Replace($runtime+"_","").Replace(".csv","").Replace("_"," ")
							$title = $metaData.Filename.Replace(".csv","").Replace("_"," ") + " " + $extraText
						}
						$htmlPage += "`n<$headerType>$title $extraText</$headerType>"
						logThis -msg "`t`t-> $title $extraText" -foreground yellow
					
					}

					if ($metaData.introduction)
					{
						logThis -msg "`t-> Special introduction found in the NFO $extraText"  -foreground blue
						$htmlPage += "`n<p>$($metaData.introduction) $($metaData.analytics)</p>"
						#Remove-Variable introduction
					} else {
						logThis -msg "`t-> No introduction found in the NFO $extraText"  -foreground yellow
					}
					if ($metaData.metaAnalytics)
					{
						#$htmlPage += 
					}
				
					$style="class=$setTableStyle"
					#pause
					if($dataTable)
					{
						if ($passesSoFar -eq $expectedPassesToMakeForTopConsumers)
						{
							if ($metaData.generateTopConsumersSortByColumn)
							{
								$tmpreport = $dataTable | sort -Property $metaData.generateTopConsumersSortByColumn -Descending | Select -First $metaData.generateTopConsumers
								$ataTable = $tmpreport
							} else {
								$tmpreport = $dataTable | sort | Select -First $metaData.generateTopConsumers
								$dataTable = $tmpreport
							}
						}
						if ($metaData.chartable -eq "true")
						{
							if ((Test-Path -path $metaData.ImageDirectory) -ne $true) {
								New-Item -type directory -Path $metaData.ImageDirectory
							}
							logThis -msg "-> Need to Chart this table according to NFO" -foreground blue
							# do the charting here instead of the table
							$htmlPage += "`n<table>"
							#$chartStandardWidth
							#$chartStandardHeight
							#$imageFileType
							logThis -msg $dataTable -ForegroundColor $global:colours.Information
							$report["OutputChartFile"] = createChart -sourceCSV $metaData.File -outputFileLocation $(($metaData.ImageDirectory)+"\"+$metaData.Filename.Replace(".csv",".$chartImageFileType")) -chartTitle $chartTitle `
								-xAxisTitle $xAxisTitle -yAxisTitle $yAxisTitle -imageFileType $chartImageFileType -chartType $chartType `
								-width $chartStandardWidth -height $chartStandardHeight -startChartingFromColumnIndex $startChartingFromColumnIndex -yAxisInterval $yAxisInterval `
								-yAxisIndex  $yAxisIndex -xAxisIndex $xAxisIndex -xAxisInterval $xAxisInterval
							
							$report["outputChartFileName"] = Split-Path -Leaf $metaData.OutputChartFile

							logThis -msg "-> image: ($metaData.OutputChartFile)" -foreground blue
							$htmlPage += "`n<tr><td>"
							if ($emailReport)
							{
								$htmlPage += "`n<div><img src=""$($metaData.OutputChartFile)""></img></div>"
								$attachments += ($metaData.OutputChartFile)
							} else
							{
								$htmlPage += "`n<div><img src=""$($metaData.OutputChartFile)""></img></div>"
								# "<div><img src=""$($metaData.OutputChartFile)""></img></div>"
							}
							#$htmlPage += $metaData.DataTableCSV | ConvertTo-HTML -Fragment
							#$htmlPage += "`n</td></tr></table>"
							$htmlPage += "`n</td></tr>"
							#logThis -msg $imageFileLocation -BackgroundColor $global:colours.Error -ForegroundColor $global:colours.Information
							#$attachments += $imageFileLocation			
							#$htmlPage += "`n<div><img src=""$outputChartFileName""></img></div>"
							#$attachments += $imageFileLocation
						
							#Remove-Variable imageFileLocation
							#Remove-Variable imageFilename
						
							$htmlPage += "`n</td></tr></table>"
							#Remove-Variable chartable
						} else { 
							# displayTableOrientation can be List or Table, must be set in the NFO file
							if ($dataTable.Count)
							{
								$count = $dataTable.Count
							} else {
								$count = 1
							}
							$caption = ""
							#if (!$metaData.showTableCaption -or ($report.showTableCaption -eq $true))
							if ($metaData.showTableCaption -eq $true)
							{
								$caption = "<p>Number of items: $count</p>"

							}
							if ($metaData.displayTableOrientation -eq "List")
							{
								$dataTable | %{
									$htmlPage += ($_ | ConvertTo-HTML -Fragment -As $metaData.displayTableOrientation) -replace "<table","$caption<table class=aITTablesytle" -replace "&lt;/li&gt;","</li>" -replace "&lt\;li&gt;","<li>" -replace "&lt\;/ul&gt;","</ul>" -replace "&lt\;ul&gt;","<ul>"

								}						
							} elseif ($metaData.displayTableOrientation -eq "Table") {
								#User has specified TABLE
								$htmlPage += ($dataTable | ConvertTo-HTML -Fragment -As "Table") -replace "<table","$caption<table class=aITTablesytle" -replace "&lt;/li&gt;","</li>" -replace "&lt\;li&gt;","<li>" -replace "&lt\;/ul&gt;","</ul>" -replace "&lt\;ul&gt;","<ul>"
								$htmlPage += "`n"
							
							} else {
								# Do this regardless
								$htmlPage += ($dataTable | ConvertTo-HTML -Fragment -As "Table") -replace "<table","$caption<table class=aITTablesytle" -replace "&lt;/li&gt;","</li>" -replace "&lt\;li&gt;","<li>" -replace "&lt\;/ul&gt;","</ul>" -replace "&lt\;ul&gt;","<ul>"
								$htmlPage += "`n"
								#$htmlPage += "`n<p>Invalid property in variable `$metaData.displayTableOrientation found in NFO. The only options are ""List"" and ""Table"" or don't put a variable in the NFO. <p>"
							}
							#Remove-Variable $report
						}
					} else {
						#$htmlPage += "`n<p><i>No items found.</i></p>"
					}
					$passesSoFar++
				}
			}
		}
		$index++
	}
	$htmlPage += "`n<p>If you need clarification or require assistance, please contact $itoContactName ($replyToRecipients)</p><p>Regards,</p><p>$itoContactName</p>"		
	$htmlPage += "`n"	
	$htmlPage += htmlFooter
	return $htmlPage
}


function convertTextVariablesIntoObject ([Parameter(Mandatory=$true)][object]$obj)
{
	#logThis -msg "Reading in configurations from file $inifile"
	$configurations = @{}
	$obj | %{
		if ($_ -notlike "#*")
		{
			$var = $_.Split('=')
			#logThis -msg $var
			#Write-Host $var[0]
			if ($var.Count -gt 1)
			{
				$name=$var[0]
				#Write-Host "$($var[0]) $($var[1])"
				if ($var[1] -eq "true")
				{
					#$configurations.Add($var[0],$true)
					$value=$true
					#New-Variable -Name $var[0] -Value $true
				} elseif ($var[1] -eq "false")
				{
					#$configurations.Add($var[0],$false)
					$value=$false
					#New-Variable -Name $var[0] -Value $false
				} else {
					if ($var[1] -match ',')
					{
						$value = $var[1] -split ','
						#New-Variable -Name $var[0] -Value ($var[1] -split ',')
					} else {
						$value = $var[1]
						#New-Variable -Name $var[0] -Value $var[1]
					}
				}
				$configurations.Add($name,$value)
			}
		}
	}
	
	
	if ($configurations)
	{
		# Perform post processing by replace all strings with  $ sign in them with the content of their respective Content.
		# for example: replaceing $customer with the actual customer name specified by the key $configurations.customer
		$postProcessConfigs = @{}
		$configurations.Keys | %{
			$keyname=$_
			#Write-Host $keyname
			# just in case the value is an array, process each
			$updatedValue=""
			#Write-Host  $configurations.$keyname		 -ForegroundColor White
			$updatedField = $configurations.$keyname | %{
				$curr_string = $_						
				
				if ($curr_string -match '\$')
				{
					# replace the string with a $ sign in it with the content of the variable it is expected
					$newstring=""
					$newstring_array = $curr_string -split ' ' | %{
						$word = $_
						#Write-Host "`tBefore $word"
						if ($word -like '*$*')
						{
							$key=$word -replace '\$'
							$configurations.$key
							#Write-Host "Needs replacing $word with $($configurations.$key)"
						} else {
							$word
							#Write-Host "$($word)"
						}
					}
					$updatedValue = [string]$newstring_array
					#Write-Host "-t>>>$updatedValue" -ForegroundColor $global:colours.ChangeMade
				} elseif ($curr_string -eq $true)
				{
					$updatedValue = $true
					#Write-Host "-t>>>$updatedValue" -ForegroundColor $global:colours.Information
				} elseif ($curr_string -eq $false)
				{
					$updatedValue = $false
					#Write-Host "-t>>>$updatedValue" -ForegroundColor $global:colours.Highlight
				} else {
					
					$updatedValue = $curr_string
					#Write-Host "-t>>>$updatedValue" -ForegroundColor $global:colours.Information
				}
				$updatedValue
			}
			$postProcessConfigs.Add($keyname,$updatedField)
		}
		#$postProcessConfigs.Add("inifile",$inifile)
		#return $configurations,$postProcessConfigs
	
		return $postProcessConfigs#,$configurations
	} else {
		return $null
	}
}

#######################################################################################
# MAIN 
if ((Test-Path -path $global:logDir) -ne $true) {
	
	New-Item -type directory -Path $global:logDir
	$childitem = Get-Item -Path $global:logDir
	$global:logDir = $childitem.FullName
}
$global:runtime="$(date -f dd-MM-yyyy)"	
$global:today = Get-Date
$global:startDate = (Get-Date (forThisdayGetFirstDayOfTheMonth -day $today) -Format "dd-MM-yyyy midnight")
$global:lastDate = (Get-date ( forThisdayGetLastDayOfTheMonth -day $(Get-Date $today).AddMonths(-$showLastMonths) ) -Format "dd-MM-yyyy midnight")
$global:runtimeLogFileInMemory=""

SetmyCSVOutputFile -filename $($global:logDir+"\"+$global:scriptName.Replace(".ps1",".csv"))
SetmyCSVMetaFile -filename $($global:logDir+"\"+$global:scriptName.Replace(".ps1",".nfo"))
SetmyLogFile -filename $($global:logDir + "\"+$global:scriptName.Replace(".ps1",".log"))

logThis -msg "****************************************************************************" -foregroundColor $global:colours.Highlight
logThis -msg "Script Started @ $(get-date)" -ForegroundColor $global:colours.Highlight
logThis -msg "Executing script: $global:scriptName " -ForegroundColor $global:colours.Highlight
logThis -msg "Output Dir = $global:logDir" -ForegroundColor $global:colours.Highlight
#logThis -msg " Runtime log file = $global:runtimeLogFile" -ForegroundColor $global:colours.Highlight
#logThis -msg " Runtime CSV File = $global:runtimeCSVOutput" -ForegroundColor $global:colours.Highlight
#logThis -msg " Runtime Meta File = $global:runtimeCSVMetaFile" -ForegroundColor $global:colours.Highlight
#logThis -msg " Runtime Meta File (In Memory) = $global:runtimeLogFileInMemory" -ForegroundColor $global:colours.Highlight
logThis -msg "****************************************************************************" -ForegroundColor $global:colours.Highlight

<# OLD STUFF TO CLEAR OUT
#$global:runtime="$(date -f dd-MM-yyyy)"
	
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
logThis -msg "Script Started @ $(get-date)" -ForegroundColor $global:colours.Information
logThis -msg "Executing script: $global:scriptName " -ForegroundColor $global:colours.Information
logThis -msg "Logging Directory: $global:logDir" -ForegroundColor  $global:colours.Yellow
logThis -msg "Script Log file: $global:logfile" -ForegroundColor  $global:colours.Yellow
logThis -msg "Indexer: $global:reportIndex" -ForegroundColor  $global:colours.Yellow
logThis -msg " ****************************************************************************"
logThis -msg "Loading Session Snapins.."
#loadSessionSnapings
SetmyCSVOutputFile -filename $global:runtimeCSVOutput
SetmyCSVMetaFile -filename $runtimeCSVMetaFile
#>