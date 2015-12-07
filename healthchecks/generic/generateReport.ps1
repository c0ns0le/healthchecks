# Reads in reports from collectAll.ps1 from a single directory and Generates a HTML report to display or email
# Reports outputed by collectAll.ps1 are placed in a single directory with a file called index.txt. This file contains a list of CS
# files in the order which this script is going to place the tables in the html report. If you want to permanently change the order
# of CSV, then make the change in collectAll.ps1. It is achieved by changing the order of the scripts from $defaultReports and $extraReports
#
# Version : 1.2
#Author : 24/03/2015, by teiva.rodiere@gmail.com
# Syntax
# ./generateInfrastructureReports.ps1 -srvconnection $srvconnection -emailReport [$true|$false] -verboseHTMLFilesToFile [$true|$false]
#
# Examples - 
# 1) Only create a HTML output of the infrastructure report email (not actually emailing it)
# ./generateInfrastructureReports.ps1 -srvconnection $srvconnection -emailReport $false -verboseHTMLFilesToFile $true
#
# 2) Only create a email the infrastructure report email 
# ./generateInfrastructureReports.ps1 -srvconnection $srvconnection -emailReport $true -verboseHTMLFilesToFile $false
#[object]$srvConnection,
#
# Each NFO file can include the below metadata . this script will read the NFO file and if it finds the below variables, then it does something with it
# ----------------------------------------------
#      tableHeader=What you want the section header to be called
#      titleHeaderType=h2|h1|h3
#      introduction=Paragraph describing your report
#      chartable=false|true
#      reportPeriodInDays=Number value for the number of days for this reporting period, exampe 7 for seven days
#      reportPeriodInvtervalsInMins=Number value for sample period. 5 would indicate a 5 minute interval between samples
#      displayTableOrientation=Table|List
#	   metaAnalytics=This one is special as it enables you to analyse your results, formulate some smarts analytics and add it to your meta data (NFO)
#
param(
	#[Parameter(Mandatory=$true)][object]$srvConnection,
	[Parameter(Mandatory=$true)][string]$inDir,
	[Parameter(Mandatory=$true)][string]$logDir,
	[Parameter(Mandatory=$true)][string]$reportHeader,
	[Parameter(Mandatory=$true)][string]$reportIntro,
	[Parameter(Mandatory=$true)][string]$farmName,
	[string]$setTableStyle="aITTablesytle",
	[string]$itoContactName,
	[string]$replyToRecipients,
	[string]$fromContactName,
	[string]$fromRecipients,
	[string]$toRecipients,
	[bool]$useConfig=$false,
	[string]$configFile="",
	[string]$smtpServer,
	[string]$smtpDomainFQDN,
	[string]$comment="",
	[bool]$emailReport=$false,
	[bool]$createHTMLFile=$true,
	[string]$overwriteRuntimeDate,
	[string]$thisContactOnly="",
	[bool]$openReportOnCompletion=$false
)


Write-Host "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
#Set-Variable -Name vCenter -Value $srvConnection -Scope Global
#$global:logfile
#$global:outputCSV
# Want to initialise the module and blurb using this 1 function
InitialiseModule -logDir $logDir -parentScriptName $($MyInvocation.MyCommand.name)



###################################
# DEFINE THE IMPORTANT STUFF HERE
###################################


#$fromContactName="Teiva Rodiere"
#$fromRecipients="teiva.rodiere@gms.ventyx.abb.com"



#$toRecipients="logwatch@andersenit.com.au"
$silenceAllReports=$false # $true to stop all reports

# Initialise the Report Variable
$attachments = @("");

if ($overwriteRuntimeDate)
{
	$runtime = $overwriteRuntimeDate
} else {
	$runtime = "$(get-date -f dd-MM-yyyy)"
}
if ($logfile)
{
	$log = $logfile;
} else {
	#$log = "$logDir\collectAll-scheduler.log";
	$log = $runtime+"-"+($($MyInvocation.MyCommand.Name)).Replace('.ps1','.log');
}

# Create the html page including headers up to the body including body
$htmlPage = htmlHeader

#$tmpHTMLOutput=$logDir+"\"+$runtime+"-"+($($MyInvocation.MyCommand.Name)).Replace('.ps1','.html')
$tmpHTMLOutput=$logDir+"\"+$reportHeader+".html"


if ((Test-Path -path $logDir) -ne $true) {
	New-Item -type directory -Path $logDir
}

#[vSphere PowerCLI] D:\INF-VMware\scripts> $viEvent = $vms | Get-VIEvent -Types info | where { $_.Gettype().Name -eq "VmBeingDeployedEvent"}
#$runtime="$(date -f dd-MM-yyyy)"
$filename = ($($MyInvocation.MyCommand.Name)).TrimEnd('.ps1');
logThis -msg "$filename";
$reportIndex = "$inDir\index.txt"

if ($emailReport -or $createHTMLFile)
{
	#######################################################################################################
	# Generate Manager Reports
	# This section generates a report based on Virtual Machines list found in $serverListReport, 
	# then creates various reports and emails it to $fromRecipients
	#######################################################################################################
	#$htmlPage ="";

	if ($configFile)
	{			
		$ifConfig=Import-Csv $configFile
	}
	# HTML header style
	LogThis -msg "BEGINNING OF REPORTS"
	$htmlPage += "<h1>$reportHeader</h1>"
	$htmlPage += "<p>$reportIntro</p>"
	#$htmlPage += "<br><br>"		
	
	if ($silenceAllReports)
	{
		$showThisReport=!$silenceAllReports # <-----$silenceAllReports
	} else {
		$showThisReport = $true #$false to permanently turn off this report
	}
	
	if($showThisReport)
	{
		logThis -msg "###########################################################" -foregroundColor Green
		logThis -msg "# REPORT 1: IMPORT ALL CSV FOR PROCESSING" -foreground Green
		logThis -msg "###########################################################" -foregroundColor Green
		logthis -msg "-> Reading all CSV files from $inDir for date $runtime" -foreground Yellow
		if (Test-Path -Path $reportIndex)
		{
			logThis -msg "Found a reportIndex file specifying an ordered list of reports to include in this report:" -foregroundColor Yellow
			$reportIndexFileObj = Get-ChildItem -Path $reportIndex
			$nfoList = Get-Content -Path $reportIndexFileObj | %{
				if ($_)
				{
					Write-Output "$inDir\$_"
				}
			}
			logThis -msg "-> [$($nfoList.Count)] reports found in the index file $reportIndex" -foregroundColor Yellow
			$nfoList | %{
				logThis $_ -ForegroundColor Yellow
			}
			#logthis -msg $nfoList
		} else {
			logThis -msg "No reportIndex file found specifying an ordered list of reports to include in this report:" -foregroundColor Yellow 
			logThis -msg "The report will enumerate all CSV files found at location: $inDir, and include all found CSV in this report" -foregroundColor Yellow
			#$nfoList = Get-ChildItem -Path $inDir -Filter "$runtime*.csv"
			$nfoList = Get-ChildItem -Path $inDir -Filter "*.nfo" |%{
				Write-Output "$inDir\$_"
			}
			logThis -msg "-> [$($nfoList.Count)] reports found in directory $inDir" -foregroundColor Yellow
			$nfoList | %{
				logThis $_  -foregroundColor Yellow
			}
		}
		
		$reportIndexer=1
		logThis -msg "Enumerating through the $($nfoList.Count) CSV Files found"
		$color="Cyan"
		#$nfoList | %{
		$nfoList | %{
			$report = @{}
			$report["NFO"] = $_
			if (Test-Path -Path $report.NFO)
			{
				logThis -msg "-> Found NFO. Loading its content" -foregroundColor $color
				#LoadNFOVariables $report.NFO
				
				Get-Content $report.NFO | Foreach-Object {
			        $var = $_.Split('=')
			        #New-Variable -Name $var[0] -Scope Global -Value $var[1]
					$report[$var[0]] = $var[1]
			    }
				
			} else {
				logThis -msg "`t-> No NFO file found" -foregroundColor $color
				#Remove-Variable tableHeader
			}
			
			$report["Index"]=$reportIndexer
			$report["Filename"]=$(Split-Path -Path $_ -Leaf)
			Write-Progress -Activity "Processing Reports.." -CurrentOperation "$reportIndexer/$($nfoList.Count) :- $($report.Filename)" -PercentComplete ($reportIndexer /  $nfoList.Count * 100)
			# Soon read the CSV Filename from the NFO file not from a derivative
			$report["File"]=$_.Replace(".nfo",".csv")
			$report["LogFile"] = $_.Replace(".csv",".log")
			
			#$report.File = $_;
			logThis -msg "++++++++++++++++++++++++++++++++++++++++++"
			logThis -msg "Processing [$($report.Index) of $($nfoList.Count)] :- $($report.File)" -foregroundColor $color
			logThis -msg "-> Looking for fileNFO $($report.NFO) " -foregroundColor $color
			#$report.Filename = $_.Name #(Split-Path -Path $_ -Leaf)
			#$report.File = $_.Fullname;
			#$report.Filename = $_.Name;

						#$fileLog = $report.File.Replace(".csv",".log")
			#$report.NFO = $report.File.Replace(".csv",".nfo")
			$report["ImageDirectory"] = "$inDir\img"
			
			#$report.ImageDirectory = "$inDir\img"
			
			
			
			$expectedPassesToMakeForTopConsumers = 2
			if ($report.generateTopConsumers)
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
					$extraText = "(Top ($report.generateTopConsumers))"
				} else {
					$extraText = ""
				}
				if ($report.titleHeaderType)
				{	logThis -msg "`t-> Using header Type $($report.titleHeaderType) found in NFO $extraText" -foregroundColor $color
					$headerType = $report.titleHeaderType # + " " + $extraText
				} else 
				{
					logThis -msg "`t-> No header types found in NFO, using H2 instead $extraText"  -foregroundColor Yellow
					$headerType = "h2"
				}
				if ($report.tableHeader)
				{
					logThis -msg "`t-> Using heading from NFO: $($report.tableHeader) $extraText"  -foregroundColor $color
					$htmlPage += "<$headerType>$($report.tableHeader) $extraText</$headerType>"
					#Remove-Variable tableHeader
					
				} else {
					logThis -msg "`t-> Will derive Heading from the original filename" -foregroundColor $color
					if ($vcenterName)
					{
						#$title = $report.Filename.Replace($runtime+"_","").Replace("$vcenterName","").Replace(".csv","").Replace("_"," ")
						$title = $report.Filename.Replace("$vcenterName","").Replace(".csv","").Replace("_"," ") + " " + $extraText
					} else {
						#$title = $report.Filename.Replace($runtime+"_","").Replace(".csv","").Replace("_"," ")
						$title = $report.Filename.Replace(".csv","").Replace("_"," ") + " " + $extraText
					}
					$htmlPage += "<$headerType>$title $extraText</$headerType>"
					logThis -msg "`t`t-> $title $extraText" -foreground yellow
					
				}
				if ($report.introduction)
				{
					logThis -msg "`t-> Special introduction found in the NFO $extraText"  -foreground blue
					$htmlPage += "<p>$($report.introduction) $($report.analytics)</p>"
					#Remove-Variable introduction
				} else {
					logThis -msg "`t-> No introduction found in the NFO $extraText"  -foreground yellow
				}
				if ($report.metaAnalytics)
				{
					#$htmlPage += 
				}
				
				#if ($report.UseTableStyle)
				#{
				#	$style="class=$($report.UseTableStyle)"
				#} else {
				$style="class=$setTableStyle"
				#}
				# Read the data in
				if( Test-Path -path $report.File)
				{
					$report["DataTable"] = Import-Csv -Path $report.File
					$report["DataTable"] | %{ if ($_.Issues) { $_.Issues = $_.Issues -replace "^","<ul><li>" -replace "`n","</li><li>" -replace "</li><li>$","</li></ul>" } }
				}
				if($report.DataTable)
				{
					if ($passesSoFar -eq $expectedPassesToMakeForTopConsumers)
					{
						if ($report.generateTopConsumersSortByColumn)
						{
							$tmpreport = $report.DataTable | sort -Property $report.generateTopConsumersSortByColumn -Descending | Select -First $report.generateTopConsumers
							$report.DataTable = $tmpreport
						} else {
							$tmpreport = $report.DataTable | sort | Select -First $report.generateTopConsumers
							$report.DataTable = $tmpreport
						}
					}
					if ($report.chartable -eq "true")
					{
						if ((Test-Path -path $report.ImageDirectory) -ne $true) {
							New-Item -type directory -Path $report.ImageDirectory
						}
						logThis -msg "-> Need to Chart this table according to NFO" -foreground blue
						# do the charting here instead of the table
						$htmlPage +="<table>"
						#$chartStandardWidth
						#$chartStandardHeight
						#$imageFileType
						logThis -msg $report.DataTable -ForegroundColor Cyan
						$report["OutputChartFile"] = createChart -sourceCSV $report.File -outputFileLocation $(($report.ImageDirectory)+"\"+$report.Filename.Replace(".csv",".$chartImageFileType")) -chartTitle $chartTitle `
							-xAxisTitle $xAxisTitle -yAxisTitle $yAxisTitle -imageFileType $chartImageFileType -chartType $chartType `
							-width $chartStandardWidth -height $chartStandardHeight -startChartingFromColumnIndex $startChartingFromColumnIndex -yAxisInterval $yAxisInterval `
							-yAxisIndex  $yAxisIndex -xAxisIndex $xAxisIndex -xAxisInterval $xAxisInterval
							
						$report["outputChartFileName"] = Split-Path -Leaf $report.OutputChartFile

						logThis -msg "-> image: ($report.OutputChartFile)" -foreground blue
						$htmlPage += "<tr><td>"
						if ($emailReport)
						{
							$htmlPage += "<div><img src=""$($report.OutputChartFile)""></img></div>"
							$attachments += ($report.OutputChartFile)
						} else
						{
							$htmlPage += "<div><img src=""$($report.OutputChartFile)""></img></div>"
							Write-Host "<div><img src=""$($report.OutputChartFile)""></img></div>"
						}
						#$htmlPage += $report.DataTableCSV | ConvertTo-HTML -Fragment
						#$htmlPage +="</td></tr></table>"
						$htmlPage += "</td></tr>"
						#logThis -msg $imageFileLocation -BackgroundColor Red -ForegroundColor Yellow
						#$attachments += $imageFileLocation			
						#$htmlPage += "<div><img src=""$outputChartFileName""></img></div>"
						#$attachments += $imageFileLocation
						
						#Remove-Variable imageFileLocation
						#Remove-Variable imageFilename
						
						$htmlPage +="</td></tr></table>"
						#Remove-Variable chartable
					} else { 
						# displayTableOrientation can be List or Table, must be set in the NFO file
						if ($report.DataTable.Count)
						{
							$count = $report.DataTable.Count
						} else {
							$count = 1
						}
						$caption = ""
						#if (!$report.showTableCaption -or ($report.showTableCaption -eq $true))
						if ($report.showTableCaption -eq $true)
						{
							$caption = "<p>Number of items: $count</p>"
						}
						if ($report.displayTableOrientation -eq "List")
						{
							$report.DataTable | %{
								$htmlPage += ($_ | ConvertTo-HTML -Fragment -As $report.displayTableOrientation) -replace "<table","$caption<table class=aITTablesytle" -replace "&lt;/li&gt;","</li>" -replace "&lt\;li&gt;","<li>" -replace "&lt\;/ul&gt;","</ul>" -replace "&lt\;ul&gt;","<ul>"
							}						
						} elseif ($report.displayTableOrientation -eq "Table") {
							#User has specified TABLE
							$htmlPage += ($report.DataTable | ConvertTo-HTML -Fragment -As "Table") -replace "<table","$caption<table class=aITTablesytle" -replace "&lt;/li&gt;","</li>" -replace "&lt\;li&gt;","<li>" -replace "&lt\;/ul&gt;","</ul>" -replace "&lt\;ul&gt;","<ul>"
							
						} else {
							# Do this regardless
							$htmlPage += ($report.DataTable | ConvertTo-HTML -Fragment -As "Table") -replace "<table","$caption<table class=aITTablesytle" -replace "&lt;/li&gt;","</li>" -replace "&lt\;li&gt;","<li>" -replace "&lt\;/ul&gt;","</ul>" -replace "&lt\;ul&gt;","<ul>"
							#$htmlPage += "<p>Invalid property in variable `$report.displayTableOrientation found in NFO. The only options are ""List"" and ""Table"" or don't put a variable in the NFO. <p>"
						}
						#Remove-Variable $report
					}
				} else {
					#$htmlPage += "<p><i>No items found.</i></p>"
				}
				$passesSoFar++
			}
			# Post report clearance of variales etc..
			#if (Test-Path -Path $report.NFO)
			#{
			#logThis -msg "`t-> Need to remove all the variables created from the NFO"  -foreground blue
			#UnloadNFOVariables $report.NFO				
			Remove-Variable report
			#}
			logThis -msg " "
			$reportIndexer++
		}
	}
	
	
	####################################################################
	# Show email footer
	####################################################################

	if ($emailReport)
	{	
		$showFooter=$true
		if ($showFooter)
		{
			# Footer
			$htmlPage += "<p>If you need clarification or require assistance, please contact $itoContactName ($replyToRecipients)</p><p>Regards,</p><p>$itoContactName</p>"
			
		}
	}
	#$htmlPage += "<br><br><small>$runtime | $farmname | $srvconnection | generated from $env:computername.$env:userdnsdomain </small>";
	$htmlPage += htmlFooter
	if ($createHTMLFile)
	{
		
		$htmlPage | Out-File "$tmpHTMLOutput"
		logThis -msg "---> Opening $tmpHTMLOutput"
		if ($openReportOnCompletion)
		{
			start "$tmpHTMLOutput"
		}
	}
	
	if ($emailReport)
	{
		# This routine sends the email
		#function emailContact ([string] $smtpServer,  [string] $from, [string] $replyTo, [string] $toAddress ,[string] $subject, [string] $htmlPage) {
		if ($scriptParams) {remove-variable scriptParams}
			$scriptParams = @{ 
				'subject' = $subject;
				'smtpServer' = $smtpServer;
				'smtpDomainFQDN' = $smtpDomainFQDN;
				'replyTo' = $replyToRecipients;
				'from' = $fromRecipients;
				'toAddress' = $toRecipients;
				'body' = $htmlPage;
				'attachements' = $attachments;
				'fromContactName' = $fromContactName
			}
			
			# This routine sends the email
			#function emailContact ([string] $smtpServer,  [string] $from, [string] $replyTo, [string] $toAddress ,[string] $subject, [string] $htmlPage) {
			sendEmail @scriptParams		
	}
	# return the filname of the HTML report
	return $tmpHTMLOutput
} else {
	logThis -msg "User Choice : Choosing NOT to generate HTML or emailing reports"
}
