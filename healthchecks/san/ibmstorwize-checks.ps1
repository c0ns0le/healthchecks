# This script is intended to collect information from IBM SVC/V7000/V5000 (and possibly the rest of the Vxxx series which remains untested).
# The scripts should only export the results into separate CSV in the folder specified by $logDir. Then right at the end the script calls the generateReport script which reads things back in
# and generates the HTML report.
# Version: 0.1 - May 5th 2015
# maintainer: teiva.rodiere-at-gmail.com
#
# see function showSyntax() below for the list of Syntax
#
param([string]$logDir="output",
	[string]$comment="",
	[bool]$openReportOnCompletion=$true,
	[System.Object]$arrayOfTargetDevices,
	[string]$username,
	[string]$cpassword,
	[System.Object]$arrayOfTargetDevicesWithSeparateCredentials,
	#[bool]$DEBUG=$false,
	[Parameter(Mandatory=$false)][int]$showLastMonths=3,
	[int]$logsCount=100,
    [bool]$writeReportToDisk=$true,
    [bool]$process=$true,
    [bool]$generateReport=$true,
    [bool]$importFromThisXML=$false,
    [string]$delimiter=':',
	[Parameter(Mandatory=$false)][int]$headerType=1,
	[Parameter(Mandatory=$false)][string]$customerName="<Your Customer Name>",
	[Parameter(Mandatory=$false)][string]$itoContactName="<Your company Name>",
	[Parameter(Mandatory=$false)][string]$reportHeader ="Storage Health Check",
	[Parameter(Mandatory=$false)][string]$reportIntro="This document presents a series of findings related to storage infrasructure for $customerName. It was prepared by $itoContactName" 
)



function showSyntax()
{
Write-Host @'
# Syntax: .\ibmstorwize-checks.ps1 -logDir "C:\SAN-Checks" -username superuser -cpassword "ClearTextForNow" -arrayOfTargetDevices "IPAddress1"
# Syntax: .\ibmstorwize-checks.ps1 -logDir "C:\SAN-Checks" -username superuser -cpassword "ClearTextForNow" -arrayOfTargetDevices "IPAddress1" -logsCount 100
# Syntax: .\ibmstorwize-checks.ps1 -logDir "C:\SAN-Checks" -username superuser -cpassword "ClearTextForNow" -arrayOfTargetDevices @("IPAddress1","IPAddress2")
# Syntax: .\ibmstorwize-checks.ps1 -logDir "C:\SAN-Checks" -arrayOfTargetDevicesWithSeparateCredentials @( ("IPAddress1","Username","PasswordsInClearText"), ("IPAddress2","Username","PasswordsInClearText") )
#
# Please note the special requirements when using the below parameters
#
# -cpassword [option]:
#	Note that this options requires you to password a clear text password
#
# -arrayOfTargetDevicesWithSeparateCredentials [options]: 
#	Format for [Options]:
# 		@( ("IPAddress1","Username","PasswordsInClearText") )
# 		@( ("IPAddress1","Username","PasswordsInClearText"), ("IPAddress2","Username","PasswordsInClearText") )
#	Special Notes: This option is mutually exclusive with the following other options, therefore dont use the below options with option "-arrayOfTargetDevicesWithSeparateCredentials [Options]"
#			-username 
#			-password
#			-arrayOfTargetDevices
#
# -arrayOfTargetDevices [Options]
#	Format for [Options]:
# 		@("IPAddress1")
# 		@("IPAddress1","IPAddress2","IPAddress3")
#	Special Notes: 
# 		Use this option if all the arrays Ip addresses share the same username and password.
#		When using this option, you MUST use the below parameters with it (They are mutualy inclusive)
#			-username 
#			-password
#		This parameter is mutually EXCLUSIVE with the following other parmeters and MUST NOT be used with option "-arrayOfTargetDevicesWithSeparateCredentials [Options]"
#			-username 
#			-password
#			-arrayOfTargetDevices
#
'@
}


function execute([string]$cmd,[string]$targetDevice,[string]$username,[string]$password)
{
	if ($cmd)
	{
		try 
		{
			$outputString = & ".\plink.exe" $username@$targetDevice -pw $password $cmd
			# Split the headers to create an array to manpulate
			#$headers = @($outputString[0] -replace "\s+","," -replace ",$","" -split ",")
			return $outputString 
		} catch {
			return ""
		}
	} else  {		
		return ""
	}
}

########################################################################
# Call the necessary modules and configure all the logs, metafiles, create the logdir directory 
# if it doesn't exist + more
Write-Host "Importing Module gmsTeivaModules.psm1 (force)"
Import-Module -Name "..\vmware\vmwareModules.psm1" -Force -PassThru
Import-Module -Name ".\storageModules.psm1" -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name reportIndex -Value "$logDir\index.txt" -Scope Global
#Write-Host ":: Log File $global:logfile"
#Write-Host ":: Output CSV $global:outputCSV"


$scriptCSVFilename = $global:outputCSV #).Replace(".csv",".csv")

$currReportingPeriod_LastDayOfMonth = (forThisdayGetFirstDayOfTheMonth -day (get-date)).AddSeconds(-1)
$currReportingPeriod_LastDayOfReport = $currReportingPeriod_LastDayOfMonth
$currReportingPeriod_LastDayOfReportSVCFormat = Get-Date ($currReportingPeriod_LastDayOfMonth) -Format yyMMddHHmmss
$currReportingPeriod_LastDayOfReport_DisplayText = Get-Date ($currReportingPeriod_LastDayOfMonth) -Format "MMMM dd, yyyy"	
	
$currReportingPeriod_FirstDayOfReport = (forThisdayGetLastDayOfTheMonth -day $currReportingPeriod_LastDayOfMonth.AddMonths(-$showLastMonths)).AddSeconds(1)
$currReportingPeriod_FirstDayOfReportSVCFormat = Get-date ( $currReportingPeriod_FirstDayOfReport ) -Format yyMMddHHmmss
$currReportingPeriod_FirstDayOfReportDisplay = Get-date ( $currReportingPeriod_FirstDayOfReport )-Format "MMMM d, yyyy"


# Previous Reporting period - 2 times the window specified in $showLAstMonths
$prevReportingPeriod_LastDayOfMonth=$currReportingPeriod_FirstDayOfReport.AddSeconds(-1)
$prevReportingPeriod_LastDayOfReportSVCFormat = Get-Date ($prevReportingPeriod_LastDayOfMonth) -Format yyMMddHHmmss
$prevReportingPeriod_LastDayOfReport = $prevReportingPeriod_LastDayOfMonth
$prevReportingPeriod_LastDayOfReportDisplay = Get-Date ($prevReportingPeriod_LastDayOfMonth) -Format "MMMM dd, yyyy"
	
$prevReportingPeriod_FirstDayOfReport = (forThisdayGetFirstDayOfTheMonth -day $prevReportingPeriod_LastDayOfMonth.AddMonths(-$showLastMonths).AddSeconds(1))
$prevReportingPeriod_FirstDayOfReportSVCFormat = Get-date ( $prevReportingPeriod_FirstDayOfReport ) -Format yyMMddHHmmss
$prevReportingPeriod_FirstDayOfReportDisplay = Get-date ( $prevReportingPeriod_FirstDayOfReport )-Format "MMMM d, yyyy"
$arrays = @{}

# Define all the command lets
$cmds = @(
	(
		"Alerts",
		"Find below a history of past alerts found on your storage array for the last $showLastMonths months.",
		"Table",
		"IFS=$delimiter; svcinfo lseventlog -filtervalue 'last_timestamp>=$($prevReportingPeriod_FirstDayOfReportSVCFormat):last_timestamp<$($currReportingPeriod_LastDayOfReportSVCFormat)' -fixed yes -alert yes -message no  -delim $delimiter"
	),
	(
		"Degraded Drives",
		"This section lists the configuration information and drive vital product data on your array",
		"Table",
		"IFS=$delimiter; lsdrive -filtervalue status=degraded -delim $delimiter"
	),
	(
		"Offline Drives",
		"This section lists the configuration information and drive vital product data on your array",
		"Table",
		"IFS=$delimiter; lsdrive -filtervalue status=offline -delim $delimiter"
	),
	(
		"Degraded Pools for External Storage",
		"Verifies if one or more pools are degraded",
		"Table",
		"IFS=$delimiter; lsmdisk -filtervalue status=degraded -delim $delimiter"
	),
	(
		"Offline Pools for External Storage",
		"Verifies if one or more pools are offline",
		"Table",
		"IFS=$delimiter; lsmdisk -filtervalue status=offline -delim $delimiter"
	),
	(
		"Degraded Volumes",
		"Checks if one or more Volumes are degraded",
		"Table",
		"IFS=$delimiter; lsvdisk -filtervalue status=degraded -delim $delimiter"
	),
	(
		"Offline Volumes",
		"Checks if one or more Volumes are offline",
		"Table",
		"IFS=$delimiter; lsvdisk -filtervalue status=degraded -delim $delimiter"
	),
	(
		"Enclosures",
		"This section lists the enclosure details within this array",
		"Table",
		"IFS=$delimiter; lsenclosure -delim $delimiter"
	),
	(
		"Drive vital product data",
		"This section lists the configuration information and drive vital product data on your array",
		"Table",
		"IFS=$delimiter; lsdrive -delim $delimiter"
	),
	# Not working.
	#("Host Mappings","List Volumes are that Unmapped.","IFS=$delimiter; echo ""id$($delimiter)name$($delimiter)capacity""; lsvdisk -unit gb -nohdr -delim $delimiter |while IFS=$delimiter read -a v; do rc=`lsvdiskhostmap ${v[0]}|while read var3 rest;do echo $var3;done`;if [[ $rc == "" ]] ; then echo '${v[0]}$'$($delimiter)'${v[1]}'$($delimiter)'${v[7]}'; fi; done; "),
	(
		"Hosts",
		"List of Servers configured in this array.",
		"Table",
		"IFS=$delimiter; lshost -delim $delimiter"
	),(
		"System",
		"Shows systems information for each array.",
		"Table",
		"IFS=$delimiter; lssystem -delim $delimiter"
	),
	(
		"Disk Arrays",
		"Lists the define arrays on this Device.",
		"Table",
		"IFS=$delimiter; lsarray -delim $delimiter"
	),
	(
		"Flash Copy Mappings",
		"a list containing concise information about all of the FlashCopy mappings that are visible to the cluster, or detailed information for a single FlashCopy mapping.",
		"Table",
		"IFS=$delimiter; lsfcmap -delim $delimiter"
	),
	(
		"Consistency Groups",
		"Displays a concise list or a detailed view of FlashCopy consistency groups that are visible to the clustered system (system). This information is useful for tracking FlashCopy consistency groups.",
		"Table",
		"IFS=$delimiter; lsfcconsistgrp  -delim $delimiter"
	),
	(
		"Metro or Global Mirror relationships",
		"A concise list or a detailed view of Metro or Global Mirror relationships visible to the clustered system (system).",
		"Table",
		"IFS=$delimiter; lsrcrelationship -delim $delimiter"
	),
	(
		"Cluster Partnership",
		"Display a concise or detailed view of the current clustered systems (systems) that are associated with thelocal system.",
		"List",
		"IFS=$delimiter; lspartnership -delim $delimiter"
	),
	(
		"Last $logsCount Changes",
		"lists out the last $logsCount events/changes on the array",
		"Table",
		"IFS=$delimiter; svcinfo catauditlog -first $logsCount -delim $delimiter"
	),
	(
		"Licences",
		"Lists available and used licences.",
		"Table",
		"IFS=$delimiter; echo ""Name$($delimiter)Value""; lslicense -delim $delimiter"
	),
	(
		"Email Notifications",
		"Shows how the array is configured for email notifications.",
		"Table",
		"IFS=$delimiter; svcinfo lsemailuser -delim $delimiter"
	),(
		"Cluster Nodes",
		"Lists the service nodes",
		"Table",
		"IFS=$delimiter; sainfo lsservicenodes -delim $delimiter"
	),(
		"System Stats",
		"Provides statistics about each storage array.",
		"Table",
		"IFS=$delimiter; svcinfo lssystemstats -delim $delimiter"
	),(
		"Node Stats",
		"Provides statistics about each storage array.",
		"Table",
		"IFS=$delimiter; svcinfo lsnodestats -delim $delimiter"
	),(
		"Fibre Ports",
		"Provides Fibre Port details for each storage array.",
		"Table",
		"IFS=$delimiter; lsportfc -delim $delimiter"
	),(
		"Disk Group",
		"Provides Fibre Port details for each storage array.",
		"Table",
		"IFS=$delimiter; lsmdiskgrp -delim $delimiter"
	),(
		"Audit Logs",
		"---",
		"Table",
		"IFS=$delimiter; lsaudit"
	)
			
			
	# Future proof
	# System Stats
	# Get current stats using
	#svcinfo lssystemstats
	# from the output you can any stat_name in this way to get the history
	#svcinfo lssystemstats -history vdisk_io -filtervalue 'last_timestamp>=$($prevReportingPeriod_FirstDayOfReportSVCFormat):last_timestamp<$($currReportingPeriod_LastDayOfReportSVCFormat)'
	#svcinfo lsnodecanisterstats -filtervalue 'sample_time>=140701000000:sample_time<150630235959' vdisk_io 
)
# Prechecks
#
if ($arrayOfTargetDevicesWithSeparateCredentials)
{
	$wereAreGood = $true
} elseif ($arrayOfTargetDevices -and $username -and $cpassword)
{
	$wereAreGood = $true
} else {
	$wereAreGood = $false
}


if (!$importFromThisXML)
{
	##################### PARAMETERS ### SOON TO CHANGE
	$exec=".\plink.exe"
	$delimiter=":"
	
	# Because we want to report on both the current reporting period to show current Issues for that window but also the previous reporting period, we 
	# need to double the log collection and then process the data accordingly
		
	

	if ($arrayOfTargetDevices)
	{
		if ($arrayOfTargetDevices.Count -gt 1)
		{
			$deviceList = @()
			$arrayOfTargetDevices | %{				
				$device = New-Object System.Object
				$device | Add-Member -MemberType NoteProperty -Name "Name" -Value "$_"
				$device | Add-Member -MemberType NoteProperty -Name "Username" -Value "$username"
				$device | Add-Member -MemberType NoteProperty -Name "Password" -Value "$cpassword"
				$deviceList +=$device
			}
		
		} else {
			$deviceList = @()
			$device = New-Object System.Object
			$device | Add-Member -MemberType NoteProperty -Name "Name" -Value "$arrayOfTargetDevices"
			$device | Add-Member -MemberType NoteProperty -Name "Username" -Value "$username"
			$device | Add-Member -MemberType NoteProperty -Name "Password" -Value "$cpassword"
			$deviceList +=$device
		}
	}
	if ($arrayOfTargetDevicesWithSeparateCredentials)
	{			
		$deviceList = @()
		$arrayOfTargetDevicesWithSeparateCredentials | %{			
			$device = New-Object System.Object
			$device | Add-Member -MemberType NoteProperty -Name "Name" -Value $_[0]
			$device | Add-Member -MemberType NoteProperty -Name "Username" -Value $_[1]
			$device | Add-Member -MemberType NoteProperty -Name "Password" -Value $_[2]
			$deviceList +=$device
		}
	}
	
	
	

	########################################################################
	# Define Report Headers and export it to the indexer that i may form the title page
	#$metaInfo = @()
	#$metaInfo +="tableHeader=TSM Health Checks"
	#$metaInfo +="introduction=Chapter Introduction about what this health check is about."
	#$metaInfo +="titleHeaderType=h($headerType)"
	#$metaInfo +="displayTableOrientation=Table" # options are List or Table
	#$metaInfo +="chartable=false"
	#$metaInfo +="showTableCaption=false"
	
	$scriptMetaFilename=$global:outputCSV -replace ".csv",".nfo"
	$filename=$title -replace "\/","" -replace "\\","" -replace "\s+","_"
	$csvFilename = $scriptCSVFilename -replace ".csv","-$filename.csv"
	$metaFilename = $scriptCSVFilename -replace ".csv","-$filename.nfo"
	#ExportMetaData -metadata $metaInfo -thisFileInstead $scriptMetaFilename
	#updateReportIndexer -string "$(split-path -path $scriptCSVFilename -leaf)"

	$cmds | %{
		$title=$_[0]
		logThis -msg "-> Looking for ""$title"".."
		$description=$_[1]
		$displayTableOrientation=$_[2]
		#$tableHeaders=$_[3]
		$cmd=$_[3]
		
		# Process all TSM Servers specified and concatinate the output of each into a combined table ready for processing.
			
		$dataTable = $deviceList | %{
			$device=$_
			#Write-Host $_ -ForegroundColor $global:colours.Information
			#Write-Host $cmd
			logthis -msg "`t-> Querying Device ""$($device.Name)/$($device.Username)/$($device.Password)""..."
				
			
			#example:
			#.\ibmstorwize-checks.ps1 -logDir "C:\admin\scripts-current\output\HUTCHIES" -arrayOfTargetDevicesWithSeparateCredentials @( ("192.168.251.100","superuser","St0r@ge7"), ("192.168.251.51","superuser","St0r@ge8") )
			$outputString = execute -cmd $cmd -targetDevice $device.Name -username $device.Username -password $device.Password
				
			if 	($outputString)
			{				
				$headers = @($outputString[0] -split "$delimiter")
				$index=0
				$tmpTable = $outputString | %{
					$data = $_ -split "$delimiter"
					#$row = $_
					# Skip the first row which is headers and stuff
					if ($index -gt 0)
					{
						$obj = New-Object System.Object
						if ($deviceList -and $deviceList.Count -gt 1)
						{
							$obj | Add-Member -MemberType NoteProperty -Name "Array" -Value $device.Name
						}
						$jindex=0
						$headers | %{
							$header=$_
							$result = New-Object DateTime;
							if ($header -eq "timestamp" -or $header -eq "last_timestamp" -or $header -eq "stat_peak_time" -or $header -eq "sample_time" )
							{
								$convertible = [DateTime]::TryParseExact("$($data[$jindex])","yyMMddHHmmss",[System.Globalization.CultureInfo]::InvariantCulture,[System.Globalization.DateTimeStyles]::None,[ref]$result)
								if ($convertible)
								{
									$obj | Add-Member -MemberType NoteProperty -Name $header -Value $(get-date $result -Format "dd-MM-yyyy HH:mm:ss")
								} else {
									$obj | Add-Member -MemberType NoteProperty -Name $header -Value $data[$jindex]
								}
							} else {
								$obj | Add-Member -MemberType NoteProperty -Name $header -Value $data[$jindex]
							}
							$jindex++
						}	
							
							
							
						$obj
					} # Skip the first row beacuse it is a header
					$index++
				}
				if ($tmpTable)
				{
					$tmpTable
				} else {
					$null
				}
			}
			if ($outputString) { Remove-Variable outputString }
			if ($obj) { Remove-Variable obj }
				
			#Write to output which will be captured by the $dataTable variable outside this routine
		}
		# Set text in the metanalytics field which will be appendend to each introduction paragraph.
		# Examples: $metaAnalytics=" The results show that 50% of cows drink milk as well as water."
		$metaAnalytics=""
			
		if ($dataTable)
		{
			
			$arrays[$title]=@{}
			$arrays[$title]=$dataTable				
				
		} else {
			+="analytics="
		}

			
		if ($dataTable) { Remove-Variable dataTable }
		if ($metaAnalytics) { Remove-Variable metaAnalytics }
		if ($metaInfo) { Remove-Variable metaInfo }		
	}

    if ($arrays -and $writeReportToDisk)
    {

        $arrays | Export-Clixml "$logDir\sans.xml"        
    }
		
} else {
    Write-Host "Reading from existing XML file ""$logDir\sans.xml""" 
	$arrays = Import-Clixml "$logDir\sans.xml"
}


# Process Results
$process=$true
if($process -and $arrays)
{
	
	#########################################################################################################
    $showReport=$true
    if ($showReport)
    {
		$title="Storage Subsystems and SAN Switches reviewed"
		$metaInfo = @()
		$metaInfo +="tableHeader=$title"
		$metaInfo +="introduction="
		$metaInfo +="titleHeaderType=h$($headerType+1)"
		$dataTable=($arrays.'Cluster Nodes' | select Array,"Cluster_Name" | sort Array -Unique) | %{
			$obj = $_
			$obj | Add-Member -MemberType NoteProperty -Name "Hardware" -Value "Storage Subsystem"
			$obj
		}
		if ($dataTable)
		{
			$csvFilename=$scriptCSVFilename -replace ".csv","-$($title -replace ' ','_').csv"
			$metaFilename=$csvFilename -replace '.csv','.nfo'	
			if ($metaAnalytics) {$metaInfo += $metaAnalytics}
			ExportCSV -table $dataTable -thisFileInstead $csvFilename 
			ExportMetaData -metadata $metaInfo -thisFileInstead $metaFilename
			updateReportIndexer -string "$(split-path -path $csvFilename -leaf)"
		}
	}


	#########################################################################################################
	# JUST SHOW SUMMARY TITLE
    $showReport=$true
    if ($showReport)
    {
		$title="Summary of Findings"
		$metaInfo = @()
		$metaInfo +="tableHeader=$title"
		$metaInfo +="introduction=The below is a summary of findings in relation to $customerName’s storage systems over the past $showLASTMonths Months."
		$metaInfo +="titleHeaderType=h($headerType)"
		$metaFilename=$scriptCSVFilename -replace ".csv","-$($title -replace ' ','_').nfo"
		ExportMetaData -metadata $metaInfo -thisFileInstead $metaFilename
	}



    # New and Previous Issues
    $showReport=$true
    if ($showReport)
    {
        #$currReportingPeriod_LastDayOfReport
        ( ("New Issues",$currReportingPeriod_FirstDayOfReport,$currReportingPeriod_LastDayOfReport), ("Past Issues",$prevReportingPeriod_FirstDayOfReport,$prevReportingPeriod_LastDayOfReport) ) | %{
            $title=$_[0]
            $firstDay=$_[1]
            $secondDay=$_[2]
            $title
            Write-Host "---------"
            $firstday
            Write-Host "---------"
            $secondDay

            #pause

            #$title=title
		    $metaInfo = @()
		    $metaInfo +="tableHeader=$title"
		    $metaInfo +="introduction=Find below a list of Triggered Alerts between $firstDay and $secondDay ($showLastMonths Months)."
		    $metaInfo +="titleHeaderType=h$($headerType+1)"

            $dataTable = $arrays.'Alerts' | ?{ ( (Get-date $_.last_timestamp) -ge $firstDay -and (Get-date $_.last_timestamp) -le $secondDay)}  | group array | %{
			    $arrayName=$_.Name
			    $_.Group | group Description | %{
				    $errorType=$_
				    $errorTypeFirstDate = Get-date ($errorType.Group.last_timestamp | Get-Date | sort | select -First 1) -Format "MMMM dd, yyyy"
				    $errorTypeLastDate = Get-date ($errorType.Group.last_timestamp | get-date | sort | select -Last 1) -Format "MMMM dd, yyyy"
				    $objectNames=([string](($errorType.Group.object_name |  sort -Unique))) -replace "\s"," and "
				    $objectIds=([string](($errorType.Group.object_id |  sort -Unique))) -replace "\s"," and "
				    $objectCount=([string](($errorType.Group.object_name |  sort -Unique))).Count
				    $objectTypes=([string](($errorType.Group.object_Type | sort -Unique))) -replace "\s"," and "
				    $hasUnfixedIssues=$([string]($errorType.Group.Fixed | sort -Unique)) -like "*no*"
				
				    if ($errorType.Count -gt 1)
				    {
					        $occurence = "$($errorType.COUnt) times"
				    } else {
					        $occurence = "$($errorType.COUnt) time"
				    }
				
				    if ($errorTypeLastDate -eq $errorTypeFirstDate)
				    {
					    $dateWindow = "on $errorTypeFirstDate"
				    } else {
					    $dateWindow = "during $errorTypeFirstDate and $errorTypeLastDate "
				    }
				    #$errorType.Group.object_name
				
				    if ($objectCount -gt 1)
				    {
					    $declaration="Objects"
				    } else {
					    $declaration="Object"
				    }
				    $objectIdsText=""
				    if ($objectIds)
				    {
					    $objectIdsText=" $objectIds"
				    }
				    if ($objectNames)
				    {
					    $startText="$objectNames ($objectTypes$objectIdsText)"
				    } else {
					    $startText="$objectTypes $objectIds"
				    }
				
				    # Status
				    if ($hasUnfixedIssues)
				    {
					    $hasUnfixedIssuesText="No"
				    } else {
					    $hasUnfixedIssuesText="Yes"
				    }
				    New-Object PSObject -Property @{
					    "Array"=$arrayName
					    #"Description"="$declaration of type $objectTypes $objectNames $($errorType.Name) during"
					    #"Description"="$objectNames ($objectTypes type $declaration) reported ""$($errorType.Name)"" during $occurence."
					    "Description"="$startText reported ""$($errorType.Name)"" $occurence $dateWindow"
					    "Fixed"=$hasUnfixedIssuesText
				    }
			    }
		    }
		    
		    if ($dataTable)
		    {
			    $csvFilename=$scriptCSVFilename -replace ".csv","-$($title -replace ' ','_').csv"
			    $metaFilename=$csvFilename -replace '.csv','.nfo'	
			    if ($metaAnalytics) {$metaInfo += $metaAnalytics}
			    ExportCSV -table $dataTable -thisFileInstead $csvFilename 
			    ExportMetaData -metadata $metaInfo -thisFileInstead $metaFilename
			    updateReportIndexer -string "$(split-path -path $csvFilename -leaf)"
		    }       
        }
	}
		
	#########################################################################################################
	# MDISK vs Disk Drive Summary
	$showReport=$true
    if ($showReport)
    {
        $title="Mdisks"
		$metaInfo = @()
		$metaInfo +="tableHeader=$title"
		$metaInfo +="introduction=This table contais a list of MDISKs and number of disks in each."
		$metaInfo +="titleHeaderType=h$($headerType+1)"
		$metaInfo +="displayTableOrientation=Table" # options are List or Table
		$metaInfo +="chartable=false"
		$metaInfo +="showTableCaption=true"
		$csvFilename=$scriptCSVFilename -replace ".csv","-$($title -replace ' ','_').csv"
		$metaFilename=$csvFilename -replace '.csv','.nfo'
		$dataTable = $arrays.'Drive vital product data' | group mdisk_name | select Name,Count
		if ($dataTable)
		{
			if ($metaAnalytics) {$metaInfo += $metaAnalytics}
			ExportCSV -table $dataTable -thisFileInstead $csvFilename 
			ExportMetaData -metadata $metaInfo -thisFileInstead $metaFilename
			updateReportIndexer -string "$(split-path -path $csvFilename -leaf)"		
		}
	}
	#########################################################################################################
	# Export Cluster Nodes Summary
	$showReport=$true
    if ($showReport)
    {
        $title="Cluster Nodes"
		$metaInfo = @()
		$metaInfo +="tableHeader=$title"
		$metaInfo +="introduction=This table contais a list of Clusters and nodes in each."
		$metaInfo +="titleHeaderType=h$($headerType+1)"
		$metaInfo +="displayTableOrientation=Table" # options are List or Table
		$metaInfo +="chartable=false"
		$metaInfo +="showTableCaption=true"
		$csvFilename=$scriptCSVFilename -replace ".csv","-$($title -replace ' ','_').csv"
		$metaFilename=$csvFilename -replace '.csv','.nfo'
		$dataTable = $arrays.'Cluster Nodes' | select "Cluster_name","node_name","Node_Status","Relation"
		if ($dataTable)
		{
			if ($metaAnalytics) {$metaInfo += $metaAnalytics}
			ExportCSV -table $dataTable -thisFileInstead $csvFilename 
			ExportMetaData -metadata $metaInfo -thisFileInstead $metaFilename
			updateReportIndexer -string "$(split-path -path $csvFilename -leaf)"		
		}
	}

	#########################################################################################################
	# Export Capacity Summary
	$showReport=$true
    if ($showReport)
    {
        $title="Capacity Summary"
		$metaInfo = @()
		$metaInfo +="tableHeader=$title"
		$metaInfo +="introduction=This table shows Storage Capacity Summary."
		$metaInfo +="titleHeaderType=h$($headerType+1)"
		$metaInfo +="displayTableOrientation=List" # options are List or Table
		$metaInfo +="chartable=false"
		$metaInfo +="showTableCaption=true"
		$csvFilename=$scriptCSVFilename -replace ".csv","-$($title -replace ' ','_').csv"
		$metaFilename=$csvFilename -replace '.csv','.nfo'
		$dataTable = New-Object System.Object	
		("Cluster Nodes","Node_Status"),("Hosts","Status"),("Enclosures","Status"),("Disk Arrays",("Status","Raid_Level","Tier")),("Drive vital product data","mdisk_name")| %{
			$filter = New-Object PSObject  -Property @{
				"field" = $_[0]
			 	"parameters" = $_[1]
			}
			$objectName=$filter.Field
			$count=($arrays.$objectName | group $val).Count
			$text = "Total of $count"		
			$filter.Parameters | %{
				$deviceStatus=""
				$val = $_			
				$valCOUnt = ($arrays.$objectName | group $val).Name.Count
				if ($valCOUnt -gt 1)
				{
					$pronoun="types"
				} else 
				{
					$pronoun="type"
				}
				$text += ", $valCOUnt $pronoun of $($val -replace '_',' ') ("
				$arrays.$objectName | group $val | %{					
					$deviceStatus += "$($_.Count) x $($_.Name), "
				}
				$deviceStatus = $deviceStatus -replace ",\s$",""
				$text += $deviceStatus
				$text += ")"
			}
			#$text
			$dataTable | Add-Member -MemberType NoteProperty -Name "$objectName" -Value "$text"
		}
		

		if ($dataTable)
		{
			if ($metaAnalytics) {$metaInfo += $metaAnalytics}
			ExportCSV -table $dataTable -thisFileInstead $csvFilename 
			ExportMetaData -metadata $metaInfo -thisFileInstead $metaFilename
			updateReportIndexer -string "$(split-path -path $csvFilename -leaf)"
			#$arrays[$title]=@{}
			#$arrays[$title]=$dataTable				
			
		}
	}


    # Export all the Hash tables in $arrays to CSV
    $showReport=$true
    if ($showReport)
    {
        $cmds | %{            
            $title=$_[0]
		    logThis -msg "-> Looking for ""$title"".."
		    $description=$_[1]
		    $displayTableOrientation=$_[2]
		    #$tableHeaders=$_[3]
		    #$cmd=$_[3]
		    $csvFilename=$scriptCSVFilename -replace ".csv","-$($title -replace ' ','_').csv"
		    $metaFilename=$csvFilename -replace '.csv','.nfo'
		    if ($DEBUG)
		    {
			    $SHOWCOMMANDS = ":- [DEBUG:ON ($($cmd -replace 'IFS=:;','' -replace '-delim :','' -replace '=','(-eq)'))] "
		    }             
            $metaInfo = @()
		    $metaInfo +="tableHeader=$title $SHOWCOMMANDS"
		    $metaInfo +="introduction=$description."
		    $metaInfo +="titleHeaderType=h$($headerType+1)"
		    $metaInfo +="displayTableOrientation=$displayTableOrientation" # options are List or Table
		    $metaInfo +="chartable=false"
		    $metaInfo +="showTableCaption=true"

            if ($metaAnalytics) {$metaInfo += $metaAnalytics}
            if ($arrays.$title)
            {
			    ExportCSV -table $arrays.$title -thisFileInstead $csvFilename 
			    ExportMetaData -metadata $metaInfo -thisFileInstead $metaFilename			    
                updateReportIndexer -string "$(split-path -path $csvFilename -leaf)"
            }
        }
    }

    # Not sure what this was for
	#$cmd="select platform from status"
	#$csvFilename=$scriptCSVFilename -replace ".csv","-$($title -replace ' ','_').csv"
	#$metaFilename=$csvFilename -replace '.csv','.nfo'
}
	
############################################################################################################################################################
#
# SHOW CAPACITY SUMMARY
# 
#
if ($generateReport)
{
    # Now all the individuals TABLES are exported + the NFO Files, call the report generator against them to create the HTML Report.	
	..\vmware\generateInfrastructureReports.ps1 -inDir $logDir -logDir $logDir -reportHeader "$reportHeader" -reportIntro "$reportIntro" -farmName "$customerName" -openReportOnCompletion $openReportOnCompletion -htmlReports $true -emailReport $false -verbose $false -itoContactName $itoContactName
}



