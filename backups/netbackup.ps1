# This has to be executed locally on the symantec environment
# its not 100% as a couple of sections rely on report exports out of Netbackup Console for processing. Not
# everything has been converted to a netbackup command execution to retrieve the required information.
param (
	[int]$previousMonths=5,
	[string]$logDir="C:\admin\results\output",
	[string]$inDir="C:\admin\results\inputdir",
	[bool]$showUnitsWithValues=$true,
	[bool]$showThisIncompleteMonth=$true,
	[bool]$launchOnCSVCreation=$true,
	[string]$servername
)
############################################################################################################################################
#
# FUNCTIONS
#
############################################################################################################################################
#
# $types = [-media,-tape,-problems,-all]
function blah()
{
	#$splitstr[1],$splitstr[6],$splitstr[12],$splitstr[18],$splitstr[51]
	$backupPolicies=Invoke-Expression "bppllist.exe"
	$clients=Invoke-Expression "bpplclients.exe"
	$clientImages=Invoke-Expression "bpimagelist.exe -client $servername -L -d $startdate -e $endDate 2>&1"
	$numberofImages= ($clientImages | select-string "^Client:").Count
	
	$headers = $clientImages | %{
		$field,$content=$_ -split ':',2
		$field -replace "\s",""
	} | select -unique
	
	$linesPerSection=$clientImages.Count/$numberofImages
	for($num=0;$num -lt $linesPerSection; $num++)
	{
	
		$startValue=$headers.count * 
		$clientImages | Select-String "^Client:|^Storage Lifecycle Policy:|Schedule|^Retention Level|^Kilobytes|^Elapsed|^Policy Type"
	}
}

# convert Epoch seconds to actual date
function convertEpochDate($sec)
{
	$dayone=get-date "1-Jan-1970"
	return $(get-date $dayone.AddSeconds([double]$sec) -format "dd-MM-yyyy hh:mm:ss")
}

function getJobType($val)
{
	switch ($val)
	{
		0 { return "Backup"}
		1 { return "Archive"}
		2 { return "Restore"}
		3 { return "Verify"}
		4 { return "Duplicate"}
		5 { return "Import"}
		6 { return "Catalog backup"}
		7 { return "Vault"}
		8 { return "Label"}
		9 { return "Erase"}
		10 { return "Tape Request"}
		11 { return "Tape Clean"}
		12 { return "Format tape"}
		13 { return "Physical Inventory"}
		14 { return "Qualification"}
		15 { return "Database Recovery"}
		16 { return "Media Contents"}
		17 { return "Image Delete"}
		18 { return "LiveUpdate"}
		default { return "$val" }
	}
}

function getSeverity($val)
{
	switch ($val)
	{
		0 { return "Backup"}
		1 { return "Debug"}
		2 { return "Info"}
		4 { return "Info"}
		8 { return "Warning"}
		16 { return "Error"}
		32 { return "Critical"}
		default { return "$val"}
	}
}

function getType($val)
{
	switch ($val)
	{
		1 { return "Unknown" }
		2 { return "General"}
		4 { return "Backup"}
		16 { return "Retrieve"}
		388 { return "Media Device"}
		386 { return "Media Device"}
		1536 { return "Media Device" }
		33410 { return "Media Device"}
		33412 { return "Media Device"}
		33424 { return "Media Device"}
		33280 { return "Media Device"}
		66 { return "Backup Status"}
		64 { return "Backup Status"}
		68 { return "Backup Status"}
		default { return "$val"}
	}

}

# Start Date format "month/day/year
function getNBLogs([System.DateTime]$startDate)
{
	#$inputstring=bperror.exe -l -media
	#$inputstring=bperror.exe -l -hoursago 12 -backstat
	Write-Host "reading all the events since $startDate"  
	#$inputstring=bperror.exe -all -d "01/06/2015"
	$inputstring=bperror.exe -all -d "$(get-date $startDate -format 'MM-dd-yyyy')"
	Write-Host "Processing the data now"
	$index=1
	$dataTable=$inputstring | %{
		$row = $_ -replace '\s+',' '
		$obj = $row -split "\s+",11
		Write-Progress -Activity "Processing results" -Status "Event $index of $($inputstring.Count)" -PercentComplete (($index/$($inputstring.Count))*100)
		
		if ($obj[18] -ne 0)
		{
			new-object psobject -property @{
				"Date" = convertEpochDate -sec $($obj[0])
				"NetBackup Version" = $obj[1]
				"Type" = getType -val $($obj[2])
				"Severity" = getSeverity -val $($obj[3])
				"Server"= $obj[4]
				"Job Id"= $obj[5]
				"Job Category"= "$(getJobType -val $($obj[6]))"
				#""= $obj[7]
				"Client"= $obj[8]
				"Process"= $obj[9]
				"Description"= $obj[10]
				#------------------ Anything after that is the Error TEXT which is specific to the type of bperror
				#""= $obj[10]
				#"Client 2"= $obj[11]
				#""= $obj[12]
				#"Policy Name" = $obj[13]
				#""= $obj[14]
				#"Schedule Name" = $obj[15]
				#""= $obj[16]
				#""= $obj[17]
				#"Status Code" = $obj[18]
				#"Status Explained" = $obj[19]

			} 
		}
		$index++
	}

	#$datatable[0]
	#$datatable[10]
	#$dataTable | %{get-date $_.date} | sort Date | select -first 1
	#$dataTable | %{get-date $_.date} | sort Date | select -last 1
	$dataTable
}
function getErrorLog()
{
	logthis -msg "Getting Media Logs"
	$output=Invoke-Expression "bperror.exe -U $type"
}
function exportTable ([Parameter(Mandatory=$true)]$table,[Parameter(Mandatory=$true)]$toThisFile)
{
	logthis -msg "Exporting table to file $toThisFile"
	(sanitiseTable -table $table) | Export-Csv -NoTypeInformation "$toThisFile"
	if ($launchOnCSVCreation) {start "$toThisFile"}
}

#logthis -msg $dataTable
function sanitiseTable ([Parameter(Mandatory=$true)]$table)
{
	$Members = $table | Select-Object `
	  @{n='MemberCount';e={ ($_ | Get-Member).Count }}, `
	  @{n='Members';e={ $_.PsObject.Properties | %{ $_.Name } }}
	$AllMembers = ($Members | Sort-Object MemberCount -Descending)[0].Members
	$formattedTable = $table | %{
	  ForEach ($Member in $AllMembers)
	  {
	    If (!($_ | Get-Member -Name $Member))
	    { 
	      $_ | Add-Member -Type NoteProperty -Name $Member -Value ""
	    }
	  }
	  Write-Output $_
	}
	return $formattedTable
}
# the input file for this function should be obtained using "nbstl -L > outfiletxt"
function returnTableFromSlpsOutput([Parameter(Mandatory=$true)]$output)
{
	$table = [System.Collections.ArrayList]@()
	$obj=New-Object System.Object

	$separator= "----"	
	$output | %{
		$string=$_
		#logthis -msg $string
		if ($string.Contains($separator))
		{
			$table.Add($obj)
			$prefix=""
			$obj = New-Object System.Object
		} else {
			$header,$value = $string -split ":",2
			$header = $header -replace "\s",""
			$value = $value -replace "^\s","" -replace "\s$",""
			if ($header -and $value)
			{
				if ($string.Contains("Use for"))
				{
					$prefix,$value2=$string -split ":"
					$prefix = $($prefix -replace "Operation  ","Operation-" -replace "Use for","" -replace "\s","")+"-"
				}
				$obj | Add-Member -MemberType NoteProperty -Name "$prefix$header" -Value "$value"
				#$obj
			}
		}
	}
	return $table 
}

# the input file for this function should be obtained using ""

function returnTableFromPoliciesOutput([Parameter(Mandatory=$true)]$output)
{
	$filter="Policy Name:|^+$|Residence is Storage Lifecycle Policy:|Residence:|Schedule:|Retention Level:|Policy Type:|Active:|^  Type:| ^  Incr Type:|^  Volume Pool:|  Server Group:"
	$table = [System.Collections.ArrayList]@()
	#$policyObj=New-Object System.Object
	#$schedule=New-Object System.Object
	$schedCount=0
	$separator= "---"
	for ($rowNum = 0; $rowNum -lt $output.Count; $rowNum++)
	{
		#($output | select-string $filter) -replace "^+$","$separator" | %{
		$line=($output[$rowNum] | select-string $filter) -replace "^+$","$separator"
		$nextLine=($output[$rowNum+1] | select-string $filter) -replace "^+$","$separator"		
		if ($line -eq $separator)
		{
		} else {
			$header,$value = $line -split ":",2
			$header = $header #-replace "^\s","" -replace "\s$",""
			$value = $value -replace "^\s","" -replace "\s$",""
			if ($header -and $value)
			{
				$value = $value.Trim()
				#$header = $header.Trim()
				#if ($header -eq "Policy Name" -or $header -eq "Residence is Storage Lifecycle Policy" -or $header -eq "Residence" -or $header -eq "Policy Type")
				#{
					#$obj | Add-Member -MemberType NoteProperty -Name "$header" -Value "$value"
				#}
				if ($header -eq "Policy Name")
				{							
					if ($schedule."Policy Name")
					{
						# flush the previous schedule to the array before starting a new section
						#logthis -msg "Flushing last schedule for the previous Policy <<<<<<<<<<<<<<<<<<<< [$($schedule.'Policy Name')]"
						$table.Add($schedule)
						#remove-variable schedule
					} else {
						#logthis -msg "No SChedule for this policy <<<<<<<< ------------ <<<<<<<<<<<< [$($schedule.'Policy Name')]"
					}
					$policyObj = New-Object System.Object
					$schedule = New-Object System.Object
					$schedCount=0
					$policyObj | Add-Member -MemberType NoteProperty -Name "$header" -Value "$value"
				} elseif ($header -eq "Schedule") 
				{
					if ($schedCount -gt 0)
					{
						#logthis -msg "Writing previous schedule [$schedCount]$>>>>>>>>> [$($policyObj.'Policy Name')]"	
						$table.Add($schedule)
						
					} else {
						#logthis -msg "Starting a new schedule >>>>>>>>>$($schedule)"
					}
					#$schedule = New-Object System.Object
					$schedule = New-Object System.Object
					($policyObj | gm -MemberType NoteProperty).Name | %{
						$fieldname=$_
						#logthis -msg $policyObj.$fieldname
						$schedule | Add-Member -MemberType NoteProperty -Name "$fieldname" -Value $($policyObj.$fieldname)
					}
					$schedCount++
					$schedule | Add-Member -MemberType NoteProperty -Name "Schedule Name" -Value "$value"
				
				} elseif (
						  $header -eq "  Retention Level"  -or
						  $header -eq "  Residence is Storage Lifecycle Policy" -or 
						  $header -eq "  Residence" -or
						  $header -eq "  Retention Level" -or 
						  $header -eq "  Type" -or
						  $header -eq "  Frequency" -or 
						  $header -eq "  Incr Type" -or  
						  $header -eq "  Volume Pool" -or 
						  $header -eq "  Server Group"
					)
				{
					$schedule | Add-Member -MemberType NoteProperty -Name "Schedule $($header.Trim())" -Value "$value"

				} else {
					$policyObj | Add-Member -MemberType NoteProperty -Name "$header" -Value "$value"
				}
			}
		}
	}
	return $table
}

function logThis (
	[Parameter(Mandatory=$true)][string] $msg, 
	[Parameter(Mandatory=$false)][string] $logFile,
	[Parameter(Mandatory=$false)][string] $ForegroundColor = "yellow",
	[Parameter(Mandatory=$false)][bool]$logToScreen = $true,
	[Parameter(Mandatory=$false)][bool]$NoNewline=$false
	)
{

	#logthis -msg "-->[$global:logFile]" -ForegroundColor Yellow
	#logthis -msg "[$logFile]"
	if ((Test-Path -path $global:logDir) -ne $true) {
				
		New-Item -type directory -Path $global:logDir
		$childitem = Get-Item -Path $global:logDir
		$global:logDir = $childitem.FullName
	}
	if ($logToScreen)
	{
		# Also verbose to screent
		if ($NoNewline)
		{
			Write-Host $msg -NoNewline -ForegroundColor $ForegroundColor;
		} else {
			Write-Host $msg -ForegroundColor $ForegroundColor;
		}
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


# the input value needs to be on Kilobytes as to expect the correct returned value
function getSize($TotalKB)
{
	$bytes=$TotalKB*1KB
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


############################################################################################################################################
#
# MAIN 
#
############################################################################################################################################
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
SetmyLogFile -filename $($global:logDir + "\"+$global:scriptName.Replace(".ps1",".log"))

# READ IN ALL THE DATA
logthis -msg "Importing Client Backups...."
$allClientBackups=import-csv "$inDir\ClientBackups.csv"
logthis -msg "Loading Policies...."
$allpolicies=Import-Csv "$inDir\policies.csv"
logthis -msg "Loading Policies v Schedules...."
$allpolicies_and_schedules=Import-Csv "$inDir\policies_and_schedules.csv"
logthis -msg "Loading Schedules...."
$allSchedules = returnTableFromPoliciesOutput -output (Get-content "$inDir\all_policies.txt") | ?{$_."Policy Name"}
logthis -msg "Loading Storage Lifecycle Policies"
#$nbstl-output = Invoke-Expression "nbstl -L"
$storageLifeCyclePolicies=returnTableFromSlpsOutput -output (Get-Content "$inDir\slp-longlist.txt") | ?{$_.Name}


$showClientBackupSummary=$true
if ($showClientBackupSummary)
{
	logThis -msg "############################################################################################################################################"
	logThis -msg "# Client Specific Stuff"
	$dates=$allClientBackups | %{GET-DATE $_."Backup Date"}
	$oldestBackupDate=get-date ($dates | sort | select -First 1) # -format "MMM-yyyy"
	$newestBackupDate=get-date ($dates | sort | select -Last 1) # -format "MMM-yyyy"
	# Today should be hte last day of the collected data
	$today=get-date ($dates | sort | select -Last 1)
	
	

	############################################################################################################################################
	#
	# SHOW PER CLIENT BACKUP SUMMARY
	#
	############################################################################################################################################
	$showReport=$false
	if ($showReport)
	{
		
		$firstDay = forThisdayGetFirstDayOfTheMonth ( $(Get-Date $today).AddMonths(-$previousMonths) )
		$lastDay = $today
		#$clientBackups=$allClientBackups | group Client
		# Filter out all the irrelevant backups that don't fit within the reporting period (specified by $previousMonths)
		$clients = $allClientBackups | ?{$(get-date $_."Backup Date") -ge $firstDay -and $(get-date $_."Backup Date") -le $lastDay} | group Client
		
		$totalClients=$clients.Count
		#$clients
		logthis -msg  "Processing Per Client Backup Summary" -NoNewline $true
		$index=1
		$dataTableChart = [System.Collections.ArrayList]@()
		$dataTable = [System.Collections.ArrayList]@()
		
		#$dataTable = [System.Collections.ArrayList]@()
		#$dataTable = 
		$clients | sort Name | %{
			$client=$_
			$thisClientBackups=$client.Group
			Write-Progress -Activity "Creating Client Backup Report" -status " $index/$totalClients :- Processing node $($client.Name) - $([math]::round($index/$totalClients*100,2)) %" -percentComplete $($index/$totalClients*100)
			logthis -msg "." -NoNewline $true
			$tmpDataTableObj = New-Object System.Object
			$tmpDataTableChartObj = New-Object System.Object
			
			$tmpDataTableChartObj | Add-Member -MemberType NoteProperty -Name "Client" -Value $client.Name			
			$tmpDataTableObj | Add-Member -MemberType NoteProperty -Name "Client" -Value $client.Name
			$tmpDataTableObj | Add-Member -MemberType NoteProperty -Name "Total Backups since $(getMonthYearColumnFormatted($oldestBackupDate))" -Value $client.Count
			
			$thisBackupPolicies=($thisClientBackups | group Policy).Name | %{
				$policyName=$_
				$allpolicies | ?{$_."Policy Name" -eq $policyName}
			}
			
			#logthis -msg $thisBackupPolicies."Policy Name"
			
			if ($thisBackupPolicies -and !$thisBackupPolicies.Count)
			{
				$tmpDataTableObj | Add-Member -MemberType NoteProperty -Name "Total Policies" -Value 1
			} elseif ($thisBackupPolicies -and $thisBackupPolicies.Count)
			{
				$tmpDataTableObj | Add-Member -MemberType NoteProperty -Name "Total Policies" -Value $thisBackupPolicies.Count
			} else {
				$tmpDataTableObj | Add-Member -MemberType NoteProperty -Name "Total Policies" -Value 0
			}
			$policyCount=1
			$transport=""
			$protocol=""
			$thisBackupPolicies | %{
				$policy=$_
				$protocol=($allpolicies | ?{$_."Policy Name" -eq $policy."Policy Name"} | select "Transport Protocol")."Transport Protocol"
				if (!$protocol)
				{
					$protocol="LAN"
				}
				$transport+=$policy."Policy Name" + "("+ $protocol + "),"
				
				$tmpDataTableObj | Add-Member -MemberType NoteProperty -Name "Policy $policyCount - Name " -Value $policy."Policy Name"
				$thisClientSchedules = $allSchedules | ?{$_."Policy Name" -eq $policy."Policy Name"}
				$scheduleCount=1
				$thisClientSchedules | %{
					$thisClientSchedule=$_
					$tmpDataTableObj | Add-Member -MemberType NoteProperty -Name "Policy $policyCount - Schedule $scheduleCount - Name " -Value $thisClientSchedule."Schedule Name"
					if ($thisClientSchedule."Residence" -eq "-")
					{
						$slpName=$thisClientSchedule."Schedule Residence"
					} else {
						$slpName=$thisClientSchedule."Residence"
					}
					
					$siteCodeLong,$therest=$slpName -split "-"
					$siteCode=$siteCodeLong[0..2] -join '' # clean up extra bits
					
					# get the SLP Object
					#$storageLifeCyclePolicies
					# Determine the exact steps for each Schedule
					$slpObj=$storageLifeCyclePolicies | ?{$_.Name -eq $slpName}
					try {
						$ops=(($slpObj | select "Operation-*-OperationIndex") | gm -MemberType NoteProperty)
						logthis -msg "------------ " -ForegroundColor Yellow
						logthis -msg $slpObj.Name# | select "Operation-*-OperationIndex")
						logthis -msg "------------ " -ForegroundColor Yellow
						$totalOperationsCountForThisSchedule=$ops.Count
					} catch
					{
						logthis -msg ($slpObj | select "Operation-*-OperationIndex")
						logthis -msg "------------ " -ForegroundColor Yellow
						logthis -msg $slpObj.Name
						logthis -msg "------------ " -ForegroundColor Yellow
					}
					for ($opNum=1;$opNum -le $totalOperationsCountForThisSchedule; $opNum++)
					{		
						$scheduleSummaryString=""
						$storageType=$slpObj."Operation-$opNum-Storage"
						#$storageType2=$slpObj."Operation-$scheduleCount-Storage"
						logthis -msg ">>$($client.Name)\$($policy.'Policy Name')\$($thisClientSchedule.'Schedule Name')\$($slpObj.Name)\Operation $opNum\$storageType"
						$storageDeviceSiteCode=$storageType[3..5] -join ''
						if ($siteCode -eq $storageDeviceSiteCode)
						{
							$siteInfo="On site"
						} else {
							$siteInfo="Off site"
						}
						if  ($storageType)
						{
							if ($storageType.Contains("MSDP"))
							{
								$storageType="Disk"
							} elseif ($storageType.Contains("HCART"))
							{
								$storageType="Tape"
							} 
						} else {
							$storageType="Uncaught Exception"
						}
						$internalIndexCode,$jobType = (($slpObj."Operation-$opNum-Operation$($opNum)Usefor") -split '\(') -replace '\)'
						$internalIndexCode,$retention=(($slpObj."Operation-$opNum-RetentionLevel") -split '\(') -replace '\)'
						$scheduleSummaryString="$siteInfo $jobType to $storageType for $retention"
						$tmpDataTableObj | Add-Member -MemberType NoteProperty -Name "Policy $policyCount - Schedule $scheduleCount - Step $opNum - Summary " -Value $scheduleSummaryString
					}
					$scheduleCount++
				}
				$policyCount++
			}
			$tmpDataTableObj | Add-Member -MemberType NoteProperty -Name "Policies" -Value $($([string]$transport) -replace ",$","" )
			$tmpDataTableObj | Add-Member -MemberType NoteProperty -Name "Schedule Types" -Value $(([string]$(($thisClientBackups | group "Schedule Type").Name -replace "$",",")) -replace ",$")			
			$lastBackup=get-date $($thisClientBackups | group "Backup Date" | %{ Get-Date $_.Name} | Sort | Select -Last 1) -Format "dd-MM-yyyy"
			$tmpDataTableObj | Add-Member -MemberType NoteProperty -Name "Last Backup" -Value $lastBackup
			
			$firstBackup=get-date $($thisClientBackups | group "Backup Date" | %{ Get-Date $_.Name} | Sort | Select -First 1) -Format "dd-MM-yyyy"
			$tmpDataTableObj | Add-Member -MemberType NoteProperty -Name "First Backup for this Reporting Period" -Value $firstBackup
			
			#Determine a few things
			$tmpTypeOfBackups = $thisClientBackups | %{
				$tmpObj = $_ #[System.Collections.ArrayList]@()
				#$tmpObj.Add($_)
				
				#calculate the number duration of backups in seconds
				$timeStr=$tmpObj."Elapsed Time"
				$days=0;$hours=0;$minutes=0;$seconds=0;
				$checkfordays=$timeStr -split "\s"
				if ($checkfordays.Count -gt 1)
				{
					$days=$checkfordays[0]
					$remainder=$checkfordays[1]
					$hours=($remainder -split ':')[0] -replace "00","0"
					$minutes=($remainder -split ':')[1] -replace "00","0"
					$seconds=($remainder -split ':')[2] -replace "00","0"
					$tmpObj | Add-Member -MemberType NoteProperty -Name "Backup Duration (sec)" -Value $(New-TimeSpan -Days $days -Hours $hours -Minutes $minutes -Seconds $seconds).TotalSeconds
					
				} else {
					$hours=($timeStr -split ':')[0] -replace "00","0"
					$minutes=($timeStr -split ':')[1] -replace "00","0"
					$seconds=($timeStr -split ':')[2] -replace "00","0"							
					$tmpObj | Add-Member -MemberType NoteProperty -Name "Backup Duration (sec)" -Value $(New-TimeSpan -Hours $hours -Minutes $minutes -Seconds $seconds ).TotalSeconds
				}
				#Calculate the speed of backups in MBps (Throughput for this backup)
				$tmpObj | Add-Member -MemberType NoteProperty -Name "Throuput (MBps)" -Value $("{0:N2}" -f $(($tmpObj.Kilobytes/1024) / $tmpObj."Backup Duration (sec)"))
				
				# Calculate Find out the backup protocol used: LAN, SAN, etcc
				$tmpObj | Add-Member -MemberType NoteProperty -Name "Transport" -Value $(($allpolicies | ?{$_."Policy Name" -eq $tmpObj.Policy})."Transport Protocol")
				$residence=$(($allpolicies | ?{$_."Policy Name" -eq $tmpObj.Policy})."Residence")
				$tmpObj | Add-Member -MemberType NoteProperty -Name "Residence" -Value $residence
				#Now output the object
				$tmpObj
				#logthis -msg ">>"
				#logthis -msg $tmpObj
				#remove-variable tmpObj
			}
			$thisClientBackups = $tmpTypeOfBackups
			
			# Total backups for the last 7 and 30 days (from the last backup in the series, not from "Today")
			7,30 | %{	
				$lastDays=$_
				
				#$startDate=(Get-Date $today).AddDays(-$lastDays)
				# no longer using last 7 days because if you run the report against a month old data then nothing will show up 
				$startDate=$newestBackupDate.AddDays(-$lastDays)
				$thisClientBackups | ?{$(get-date $_."Backup Date") -ge $startDate} | group "Schedule Type" | %{
					$schedule=$_
					$thisTypeOfBackups=$schedule.Group

					$amountKB=0
					$amountKB=($thisTypeOfBackups | measure Kilobytes -Sum).Sum
					if ($showUnitsWithValues)
					{
						$amount=getSize -totalKB $amountKB
						$tmpDataTableObj | Add-Member -MemberType NoteProperty -Name "$lastDays days - $($schedule.Name) - Amount" -Value $amount
					} else {
						$tmpDataTableObj | Add-Member -MemberType NoteProperty -Name "$lastDays days - $($schedule.Name) - Amount" -Value $("{0:N2}" -f $($amountKB/1024))
					}
					$tmpDataTableChartObj | Add-Member -MemberType NoteProperty -Name "$lastDays days - $($schedule.Name) - Amount (MB)" -Value $("{0:N2}" -f $($amountKB/1024))	
					
					
					$timespans=""
					$timeTakenStr=""
					$timespans=($thisTypeOfBackups."Backup Duration (sec)" | measure -Average).Average
					#$timespans
					if ($timespans)
					{
						$timeTaken = New-TimeSpan -Seconds $timespans
						$timeTakenStr=""
						if ($timeTaken.Days -gt 0)
						{
							$timeTakenStr += "$($timeTaken.days) days "
						}
						if ($timeTaken.Hours -gt 0)
						{
							$timeTakenStr += "$($timeTaken.Hours) hrs "
						}
						if ($timeTaken.Minutes -gt 0)
						{
							$timeTakenStr += "$($timeTaken.Minutes) min "
						}
						if ($timeTaken.Seconds -gt 0)
						{
							$timeTakenStr += "$($timeTaken.Seconds) sec "
						}
						$tmpDataTableObj | Add-Member -MemberType NoteProperty -Name "$lastDays days - $($schedule.Name) - Avg Duration" -Value $timeTakenStr
						$throughput=0
						$throughput=($thisTypeOfBackups."Throuput (MBps)" | measure -Average).Average
						$tmpDataTableObj | Add-Member -MemberType NoteProperty -Name "$lastDays days - $($schedule.Name) - Avg Throughput (MB/sec)" -Value $("{0:N2} MB/s" -f $throughput)
					} else {
						$tmpDataTableObj | Add-Member -MemberType NoteProperty -Name "$lastDays days - $($schedule.Name) - Avg Throughput" -Value "-"
						$tmpDataTableObj | Add-Member -MemberType NoteProperty -Name "$lastDays days - $($schedule.Name) - Avg Duration" -Value "-"
					}
					
					$filesamount=($thisTypeOfBackups | measure "Number of files" -Sum).Sum
					$tmpDataTableObj | Add-Member -MemberType NoteProperty -Name "$lastDays days - $($schedule.Name) - Total File Count" -Value $filesamount
				}
			}
			
			# Show Monthly Backup
			if ($previousMonths -gt 0)
			{
				$monthlyCapacityKB=0
				$monthIndex = $previousMonths
				while ($monthIndex -le $previousMonths -and $monthIndex -gt 0)
				{
					$firstDay = forThisdayGetFirstDayOfTheMonth ( $(Get-Date $today).AddMonths(-$monthIndex) )
					$lastDay = forThisdayGetLastDayOfTheMonth ( $(Get-Date $today).AddMonths(-$monthIndex) )			
					$nameofdate = "Total for $(getMonthYearColumnFormatted($firstDay))"
					#logthis -msg "Processing capacity for month of $nameofdate ($firstDay-$lastDay)"
					#$tableColumnHeaders += $nameofdate
					$monthlyCapacityKB = ($thisClientBackups | ?{$(get-date $_."Backup Date") -ge $firstDay -and $(get-date $_."Backup Date") -le $lastDay } | measure Kilobytes -Sum).Sum
					if ($showUnitsWithValues)
					{
						$fieldname="$nameofdate"
						if ($monthlyCapacityKB)
						{
							$monthlyCapacity=getSize -totalKB $monthlyCapacityKB
						} else {
							$monthlyCapacity="-"
						}
					} else {
						$fieldname="$nameofdate (GB)"
						if ($monthlyCapacityKB)
						{						
							$monthlyCapacity=$("{0:N2}" -f $($monthlyCapacityKB/1024/1024))
						} else {
							$monthlyCapacity="-"
						} 
					}
					$tmpDataTableObj | Add-Member -MemberType NoteProperty -Name "$fieldname" -Value $monthlyCapacity
					# always show as MB
					$tmpDataTableChartObj | Add-Member -MemberType NoteProperty -Name "$nameofdate (GB)" -Value $("{0:N2}" -f $($monthlyCapacityKB/1024/1024))
					$monthIndex--
				}
			}		
			
			# Show for all the days in this month		
			$firstDayOfMonth = forThisdayGetFirstDayOfTheMonth($today)
			$nameofdate = "Total for the last $(daysSoFarInThisMonth($today)) Days"
			#logthis -msg "Processing capacity for month of $nameofdate ($firstDayOfMonth-$today)"
			$monthlyCapacityKB=0
			$monthlyCapacityKB=($thisClientBackups | ?{$(get-date $_."Backup Date") -ge $firstDayOfMonth -and $(get-date $_."Backup Date") -le $today } | measure Kilobytes -Sum).Sum
			if ($showUnitsWithValues) 
			{
				$fieldname="$nameofdate"
				if ($monthlyCapacityKB)
				{
					$monthlyCapacity=getSize -totalKB $monthlyCapacityKB
				} else {
					$monthlyCapacity="-"
				}
			} else {
				$fieldname="$nameofdate (GB)"
				if ($monthlyCapacityKB)
				{						
					$monthlyCapacity=$("{0:N2}" -f $($monthlyCapacityKB/1024/1024))
				} else {
					$monthlyCapacity="-"
				} 
			}
			$tmpDataTableObj | Add-Member -MemberType NoteProperty -Name "$fieldname" -Value $monthlyCapacity
			# always show as MB
			$tmpDataTableChartObj | Add-Member -MemberType NoteProperty -Name "$nameofdate (GB)" -Value $("{0:N2}" -f $($monthlyCapacityKB/1024/1024))
			$index++
			
			$dataTableChart.Add($tmpDataTableChartObj)
			$dataTable.Add($tmpDataTableObj)
		}

		# Export Reports
		if ($dataTable)
		{						
			exportTable -table $dataTable -toThisFile "$global:logDir\ClientBackups-Summary.csv"
		}
		if ($dataTableChart)
		{
			exportTable -table $dataTableChart -toThisFile "$global:logDir\ClientBackups-Summary-MonthlyCapacityMB-chartable.csv"
		}
		logthis -msg " "
		
	}
	
	
	$showReport=$false
	if ($showReport)
	{
		$allclients = Import-Csv "$global:logDir\ClientBackups-Summary.csv"
		$dataTable = New-Object System.Object
		$dataTable=$allclients | %{get-date $_."First Backup for this Reporting Period" -Format "MM-yyyy"} | group  | Select Name,Count | sort Name | %{
			$row = New-Object System.Object
			$row | Add-Member -MemberType NoteProperty -Name "Month" -Value $(Get-date $_.Name -Format "MMM-yyyy")
			$row | Add-Member -MemberType NoteProperty -Name "Number of clients registering their first backup" -Value $_.Count
			$row
		}
		if ($dataTable)
		{						
			exportTable -table $dataTable -toThisFile "$global:logDir\ClientBackups-FirstTimeBackups.csv"
		}
	}
	
	############################################################################################################################################
	#
	# SHOW BACKUP TOTALS
	#
	############################################################################################################################################
	$showReport=$false
	if ($showReport)
	{
		logthis -msg  "Processing Totals Backup Capacity Summary for all Clients"
		$chartCol1Name=""
		
		$dataTable = New-Object System.Object
		$dataTableChart = New-Object System.Object

		#
		$firstDay = forThisdayGetFirstDayOfTheMonth ( $(Get-Date $today).AddMonths(-$previousMonths) )
		$lastDay = $today
		$nameofdate = getMonthYearColumnFormatted($firstDay)
		
		# Filter out all the irrelevant backups that don't fit within the reporting period (specified by $previousMonths)
		$clientBackups = $allClientBackups | ?{$(get-date $_."Backup Date") -ge $firstDay -and $(get-date $_."Backup Date") -le $lastDay }
		
		if ($clientBackups)
		{
			$dataTable | Add-Member -MemberType NoteProperty -Name "Total clients" -Value ($clientBackups.Client | sort -Unique).Count	
			$dataTable | Add-Member -MemberType NoteProperty -Name "Policies in use" -Value ($clientBackups.Policy | sort -Unique).Count
			$dataTable | Add-Member -MemberType NoteProperty -Name "Number of Backups since $nameofdate" -Value $clientBackups.Count
			$dataTable | Add-Member -MemberType NoteProperty -Name "Amount of Backups since $nameofdate" -Value "$(getSize -totalKB ($clientBackups.Kilobytes | measure -Sum).Sum)"
			
			# MONTH BY MONTH
			
			if ($previousMonths -gt 0)
			{
				$previousAmountGB=0
				$diffOnPreviousAmountGB=0
				$monthlyCapacityKB=0
				$monthIndex = $previousMonths
				$dataTableChart=while ($monthIndex -le $previousMonths -and $monthIndex -gt 0)
				{
					
					$firstDay = forThisdayGetFirstDayOfTheMonth ( $(Get-Date $today).AddMonths(-$monthIndex) )
					$lastDay = forThisdayGetLastDayOfTheMonth ( $(Get-Date $today).AddMonths(-$monthIndex) )			
					$nameofdate = getMonthYearColumnFormatted($firstDay)
					logthis -msg "`t-> Calculating the total capacity for $nameofdate ($firstDay-$lastDay)"
					#$tableColumnHeaders += $nameofdate
					$monthlyCapacityKB = ($clientBackups | ?{$(get-date $_."Backup Date") -ge $firstDay -and $(get-date $_."Backup Date") -le $lastDay } | measure Kilobytes -Sum).Sum
					if ($showUnitsWithValues) 
					{
						$fieldname="$nameofdate"
						if ($monthlyCapacityKB)
						{
							$monthlyCapacity=getSize -totalKB $monthlyCapacityKB
						} else {
							$monthlyCapacity="-"
						}
					} else {
						$fieldname="$nameofdate (GB)"
						if ($monthlyCapacityKB)
						{						
							$monthlyCapacity=$("{0:N2}" -f $($monthlyCapacityKB/1024/1024))
						} else {
							$monthlyCapacity="-"
						} 
					}
					$dataTable | Add-Member -MemberType NoteProperty -Name "Total Amount in $fieldname" -Value $monthlyCapacity
					
					# This is for the table that can be charted, it cannot have Units show in the fields and must be consistent in measure
					$tmpChartTable = New-Object System.Object
					$currrAmountGB=$monthlyCapacityKB/1024/1024
					if ($monthIndex -eq $previousMonths)
					{
						$diffOnPreviousAmountGB=0
					} else {
						$diffOnPreviousAmountGB=$currrAmountGB - $previousAmountGB
						
					}
					$previousAmountGB=$currrAmountGB
					$tmpChartTable | Add-Member -MemberType NoteProperty -Name "Month" -Value "$nameofdate"
					$tmpChartTable | Add-Member -MemberType NoteProperty -Name "Amount of backups (GB)" -Value $("{0:N2}" -f $currrAmountGB)
					$tmpChartTable | Add-Member -MemberType NoteProperty -Name "Difference on Previous Month (GB)" -Value $("{0:N2}" -f $diffOnPreviousAmountGB)
					Write-Output $tmpChartTable
					$monthIndex--
				}
			}

			
			# SHOW LAST DAYS IN THIS MONTH
			# note that $previousAmountGB is needed for this section, it should carry through from the last section
			if ($showThisIncompleteMonth)
			{
				$firstDay = forThisdayGetFirstDayOfTheMonth($today)
				$lastDay=$today
				$nameofdate = "Last $(daysSoFarInThisMonth($today)) Days"
				logthis -msg "`t-> Calculating the total capacity for $nameofdate ($firstDay-$lastDay)"
				$monthlyCapacityKB=0				
				$monthlyCapacityKB=($clientBackups | ?{$(get-date $_."Backup Date") -ge $firstDay -and $(get-date $_."Backup Date") -le $lastDay } | measure Kilobytes -Sum).Sum
				if ($showUnitsWithValues) 
				{
					$fieldname="$nameofdate"
					if ($monthlyCapacityKB)
					{
						$monthlyCapacity=getSize -totalKB $monthlyCapacityKB
					} else {
						$monthlyCapacity="-"
					}
				} else {
					$fieldname="$nameofdate (GB)"
					if ($monthlyCapacityKB)
					{						
						$monthlyCapacity=$("{0:N2}" -f $($monthlyCapacityKB/1024/1024))
					} else {
						$monthlyCapacity="-"
					} 
				}
				
				$dataTable | Add-Member -MemberType NoteProperty -Name "Total Amount for the $fieldname" -Value $monthlyCapacity
				# always show as MB
				[System.Collections.ArrayList]$dataTableChartArray=$dataTableChart
				$currrAmountGB=$monthlyCapacityKB/1024/1024
				$diffOnPreviousAmountGB=$currrAmountGB - $previousAmountGB
				$tmpChartTable = New-Object System.Object
				$tmpChartTable | Add-Member -MemberType NoteProperty -Name "Month" -Value "$nameofdate"
				$tmpChartTable | Add-Member -MemberType NoteProperty -Name "Amount of backups (GB)" -Value $("{0:N2}" -f $currrAmountGB)
				$tmpChartTable | Add-Member -MemberType NoteProperty -Name "Difference on Previous Month (GB)" -Value $("{0:N2}" -f $diffOnPreviousAmountGB)
				$dataTableChartArray.Add($tmpChartTable)				
				$dataTableChart=$dataTableChartArray

			}
			
			if ($dataTable)
			{
				exportTable -table $dataTable -toThisFile "$global:logDir\ClientBackups-Totals.csv"
			}
			if ($dataTableChart)
			{
				exportTable -table $dataTableChart -toThisFile "$global:logDir\ClientBackups-Totals-chartable.csv"
			}		
		} else {
			logthis -msg "-------------------------------------------------------"
			logthis -msg "|   No backups found for the last $previousMOnths      |"
			logthis -msg "-------------------------------------------------------"
		}		
	}
}


############################################################################################################################################
#
# EXPORT Storage Lifecycle Policies
#
############################################################################################################################################
$showReport=$false
if ($showReport)
{
	logthis -msg "Export Active Storage Lifecycle Policies"
	exportTable -table $storageLifeCyclePolicies -toThisFile "$global:logDir\Storage_Life_Cycle_Policies.csv"
	
	logthis -msg "Export Storage Lifecycle Policies Totals"
	$dataTable = New-Object System.Object
	$dataTable | Add-Member -MemberType NoteProperty -Name "Storage Lifecycle Policies" -Value $storageLifeCyclePolicies.Count
	$dataTable | Add-Member -MemberType NoteProperty -Name "Active" -Value $($storageLifeCyclePolicies | ?{$_.State -eq "yes"}).Count	
	$uniqueFields=($storageLifeCyclePolicies | select "*Usefor" | gm -MemberType NoteProperty).Name
	$uniqueActivities=(($storageLifeCyclePolicies | select "*Usefor" | gm -MemberType NoteProperty).Name | %{$storageLifeCyclePolicies.$_} | sort -Unique) -replace ".*\(" -replace "\).*"
	$tableActivities = [System.Collections.ArrayList]@()
	$tapeCount=0
	$ondiskCount=0
	$storageLifeCyclePolicies | %{
		$slp=$_
		$count += $uniqueActivities | %{
			$uniqueActivity=$_
			$uniqueFields | %{
				$uniqueField=$_
				#Write-Host "$($slp.Name)\$uniqueField\$uniqueActivity"
				if ($slp.$uniqueField -and $slp.$uniqueField.Contains($uniqueActivity))
				{
					(("HCART","Tape"), ("MSDP","Disk")) | %{						
						$media=$_[0]
						$mediaName=$_[1]
						$prefix=($uniqueField -split "-")[0..1] -join "-"
						if ($slp."$prefix-Storage".Contains($media))
						{
							$row = New-Object System.Object
							$row | Add-Member -MemberType NoteProperty -Name "Activity Type" -Value "$uniqueActivity to $mediaName"
							$row | Add-Member -MemberType NoteProperty -Name "Name" -Value $slp.Name
							$tableActivities.Add($row)
							#$slp.$uniqueActivities.Contains($_)
						}
					}
				}
			}
		}	
	}
	if ($tableActivities)
	{
		$tableActivities | group "Activity Type" | %{
			$dataTable | Add-Member -MemberType NoteProperty -Name "$($_.Name)" -Value $_.Count
		}
		
		$tableActivities | group "Activity Type" | %{
			$activityName=$_.Name			
			exportTable -table ($_.Group) -toThisFile "$global:logDir\Storage_Life_Cycle_Policies-$activityName.csv"
		}
	}
	
	# Determine the SLPs and their windows used
	$dataTable | Add-Member -MemberType NoteProperty -Name "Activity Windows" -Value $([string]$((($storageLifeCyclePolicies | select "*-WindowName") | gm -MemberType NoteProperty).Name | %{ $storageLifeCyclePolicies.$_ } | sort -Unique) -replace " ","," -replace "--","Any time")	
	exportTable -table $dataTable -toThisFile "$global:logDir\Storage_Life_Cycle_Policies-Capacity.csv"
}

############################################################################################################################################
## EXPORT Oracle, SQL and others Specific stuff
#
############################################################################################################################################
$showReport=$false
if ($showReport)
{
	"Oracle","SQL","Unix","Win" | %{
		$typeName=$_
		logthis -msg "Export Different Types of Schedules for $typeName Based Policies"
		# EXPORT Oracle Specific 
		$dataTable = $allschedules | ?{$_.Active -eq "yes" -and $_."Policy Name".contains("$typeName")} | select "Policy Name","Schedule Type" | group "Schedule Type" | sort Count -Descending | %{
			$row = New-Object System.Object
			$row | Add-Member -MemberType NoteProperty -Name "Schedule Type" -Value $($_.Name -replace "\(\w+\)")
			$row | Add-Member -MemberType NoteProperty -Name "Total Active Policies" -Value $($($_.Group."Policy Name") | sort -Unique).Count
			$row | Add-Member -MemberType NoteProperty -Name "Total Servers" -Value $_.Count
			$row | Add-Member -MemberType NoteProperty -Name "Client Type" -Value $typeName
			$row
		}
		#$dataTable
		exportTable -table $dataTable -toThisFile "$global:logDir\ScheduleTypes-$($typeName)Backups-.csv"
	}
}


$showReport=$false
if ($showReport)
{
	logthis -msg "Working out Schedules Names vs Schedule Types to see if there are mislabeled Schedules"
	$dataTable=$allpolicies_and_schedules | select "Schedule Name","Schedule Type" | group "Schedule Name" | %{
		$types=([string]($_.Group."Schedule Type" | sort -Unique) -replace " \(\w+\)",",") -replace ",$"
		$row = New-Object System.Object
		$row | Add-Member -MemberType NoteProperty -Name "Name" -Value $_.Name
		$row | Add-Member -MemberType NoteProperty -Name "Count" -Value $_.Count
		$row | Add-Member -MemberType NoteProperty -Name "Types" -Value $types
		$row
	}
	if ($dataTable)
	{
		exportTable -table $dataTable -toThisFile "$global:logDir\ScheduleNames_v_ScheduleTypes-.csv"
	}
}

# Process Logs
$showReport=$true
if ($showReport)
{
	# because of the large amount of data to process, recommend to analyse only 1 month worth of logs
	$numOfMonths=1
	logthis -msg "Collecting all logs for the past $numOfMonths Month(s)"
	[System.DateTime]$startDate = $today.AddMonths(-$numOfMonths)
	$dataTable = getNBLogs -startDate $startDate
	
	if ($dataTable)
	{
		# Export the results to file for further processing if needed
		logthis -msg "`t-> exporting results to file"
		exportTable -table $dataTable -toThisFile "$global:logDir\Logs-All.csv"
	
		# START THE LOG PROCESSING
		
		# Export Severity Summary
		logthis -msg "`t-> exporting severity summary"
		exportTable -table ($dataTable | group "Severity" | Select "Name","Count") -toThisFile "$global:logDir\Logs-Summary.csv"
		
		#######################
		#
		#  PROCESS ERRORS,WARNING, and CRITICAL ERRORS only from here on
		#
		$dataTableErrorsOnly=$dataTable | ?{$_.Severity -eq "Warning" -or $_.Severity -eq "Error" -or $_.Severity -eq "Critical"}
		
		# For each Client, get the Errors
		"Client","Server","Job Category","Type" | %{
			$type=$_
			logthis -msg "`t-> exporting severity summary by $type"
			exportTable -table ( $dataTableErrorsOnly | ?{$_.$type -and $_.$type -ne "*NULL*" -and $_.$type -ne "NONE" -and } | group $type | %{
				$device=$_
				$row = New-Object System.Object
				$row | Add-Member -MemberType NoteProperty -Name "Device" -Value $device.Name
				$row | Add-Member -MemberType NoteProperty -Name "Warnings" -Value ($device.Group | ?{$_.Severity -eq "Warning"}).Count
				$row | Add-Member -MemberType NoteProperty -Name "Errors" -Value ($device.Group | ?{$_.Severity -eq "Error"}).Count
				$row | Add-Member -MemberType NoteProperty -Name "Critical Errors" -Value ($device.Group | ?{$_.Severity -eq "Critical"}).Count
				$row
			} )  -toThisFile "$global:logDir\Logs-Severity_Summary_By_$($type -replace '\s','_')s.csv"
		}
		
		# Report on specific errors based on 
		#,"Media", "Replication", "Backup", "Robot", "snapshot", "optimized duplication","client hostname could not be found","Server is down","backup window closed","error occurred on network socket"
		"vmware","frozen" | %{
			$issueName=$_
			Write-Host "`t-> Processing $issueName Issues only"
			#$tmptable=$dataTableErrorsOnly.Description | ?{$_.Contains("$issueName")} | %{ $_ -replace "^.*\(" -replace "\)$"} | group | sort Count -Descending | select Name,Count -First 20
			#| %{ ($_ -split '\s')[0,1,2,3,-3,-2,-1,-0]} 
			$tmptable=$dataTableErrorsOnly | ?{$_.Description -like "*$issueName*"} | select Description,Server,Client,Date | group Description | sort count -descending # | select -first 20
			$index=0
			exportTable -table ( $tmptable | %{
				$errorString=$_.Name
				$group=$_.group
				$row = New-Object System.Object
				$row | Add-Member -MemberType NoteProperty -Name "Issue" -Value $_.Name
				$row | Add-Member -MemberType NoteProperty -Name "Count" -Value $_.Count
				$row | Add-Member -MemberType NoteProperty -Name "Occurance" -Value "Between $(($group | group date | select -First 1 -Last 1 | Select Name).Name -join ' and ')"
				$row | Add-Member -MemberType NoteProperty -Name "Affected Servers" -Value "$((($group | select Server | sort -unique).Server) -join ' , ')"
				$row | Add-Member -MemberType NoteProperty -Name "Affected Clients" -Value "$((($group | ?{$_.Client -ne '*NULL*'} | select Client | sort -unique).Client) -join ' , ')"
				$row | Add-Member -MemberType NoteProperty -Name "Issue Number" -Value $index
				$row
				$index++
			} ) -toThisFile "$global:logDir\Logs-$($issueName -replace '\s','_')s_Errors.csv"
		}
	}
	
}