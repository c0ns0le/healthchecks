param
(
	[int]$showLastMonths=10,
	[string]$logDir="C:\admin\scripts",
	[string]$dateFormat="MMM-yyyy",
	[bool]$verbose=$false,
	[bool]$showErrors=$true,
	[bool]$launchReport=$false,
	[bool]$xmlOutput=$true,
	[bool]$csvOutput=$true,
	[bool]$chartFriendly=$false
)
#region Import-Modules
Add-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name dateFormat -Value $dateFormat -Scope Global
$global:logfile
$global:outputCSV
$global:backupSpecs=$null
$global:backupSessions=$null
#endregion

#region Functions
#############################################################################################################################
#
# 				F	U	N	C	T	I	O	N	S
#
#############################################################################################################################
############################################################################################################################# - OK
function logThis ([string]$msg)
{
	Write-Host $msg
}

############################################################################################################################# - OK
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

############################################################################################################################# - OK
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
		#logThis -msg  $bytes
    	 	$value = "{0:N} PB" -f $($bytes/1PB) # TeraBytes 
    }
	return $value
}

############################################################################################################################# - OK
function get-backupSpecs()
{	
	if ($global:backupSpecs)
	{
		logThis -msg "`t`t-> Re-using existing collection of backup specs"
		return $global:backupSpecs
	} else {	
		logThis -msg "`t`t-> First time collection of backup specs"
		Set-Variable -Scope "Global" -Name "backupSpecs" -Value $(Get-VBRBackup)
		return $global:backupSpecs
	}
}
############################################################################################################################# - OK
function get-individualsessions([bool]$refresh=$false,[int]$lastMonths=6)
{
	if ($global:veeamtasks -and !$refresh)
	{
		logThis -msg "`t`t-> Re-using existing collection of individual job sessions tasks"
		return $global:veeamtasks
	} else {
		logThis -msg "`t`t-> First time collection of individual job session tasks"
		$sessions = Get-VBRBackupSession | Get-VBRTaskSession | Sort Name
		$sessionsIndex=1
		$report = $sessions | %{
			Write-Progress -Activity "Processing Each Backup sessions [get-individualsessions]" -Id 1 -Status "$sessionsIndex/$($sessions.Count) :- $($_.Name)..." -PercentComplete  (($sessionsIndex/$($sessions.Count))*100)
			$job_session = $_
			$obj = New-Object System.Object
			# Size of the VM object
			$obj | Add-Member -MemberType NoteProperty -Name "Name" -Value $job_session.Name
			$obj | Add-Member -MemberType NoteProperty -Name "Status" -Value $job_session.Status
			$obj | Add-Member -MemberType NoteProperty -Name "Job Name" -Value $job_session.JobName
			$obj | Add-Member -MemberType NoteProperty -Name "Client Size (GB)" -Value ([Math]::Round($job_session.Progress.ProcessedSize / 1gb,2))
			$obj | Add-Member -MemberType NoteProperty -Name "Data Read Size (GB)" -Value ([Math]::Round($job_session.Progress.ReadSize /1gb,2))
			$obj | Add-Member -MemberType NoteProperty -Name "Data Transfered Size (GB)" -Value ([Math]::Round($job_session.Progress.TransferedSize / 1gb, 2))
			$obj | Add-Member -MemberType NoteProperty -Name "Start Time" -Value $job_session.Progress.StartTime
			$obj | Add-Member -MemberType NoteProperty -Name "Stop Time" -Value $job_session.Progress.StopTime
			$obj | Add-Member -MemberType NoteProperty -Name "Queue Time" -Value $job_session.Info.QueuedTime
			if ($job_session.Progress.StopTime -gt $job_session.Progress.StartTime) 			{
				$totalTimeInSeconds = $(($job_session.Progress.StopTime - $job_session.Progress.StartTime).TotalSeconds)
			} else {
				$totalTimeInSeconds =  0				
			}
#			$obj | Add-Member -MemberType NoteProperty -Name "Duration" -Value $job_session.Progress.Duration
			$obj | Add-Member -MemberType NoteProperty -Name "Duration (Seconds)" -Value $totalTimeInSeconds
			$obj | Add-Member -MemberType NoteProperty -Name "Backup Type" -Value $job_session.JobSess.Info.JobAlgorithm
			$obj | Add-Member -MemberType NoteProperty -Name "Directory" -Value (Get-BackupRepoNameById -repoId $job_session.WorkDetails.RepositoryId)
			$obj
			$sessionsIndex++
		}
		if ($report)
		{
			Set-Variable -Scope "Global" -Name "veeamtasks" -Value $report
			return $global:veeamtasks
		} else {
			return $null
		}
	}
}
#$sessions=get-individualsessions -refresh $true
#$sessions=get-individualsessions -refresh $false

############################################################################################################################# - OK
function get-backupsessions([bool]$refresh=$false)
{
	if ($global:backupSessions -and !$refresh)
	{
		logThis -msg "`t`t-> Re-using existing collection of backup sessions"
		return $global:backupSessions
	} else {	
		logThis -msg "`t`t-> First time collection of backup sessions"		
		$backups = get-backupSpecs
		$backupSessions = Get-VBRBackupSession
		$sessionIndex=1
		$report = $backupSessions | sort Name | %{
			Write-Progress -Activity "Processing Backup sessions [Get-VeeamBackupSessions]" -Id 1 -Status "$sessionIndex/$($backupSessions.Count) :- $($_.Name)..." -PercentComplete  (($sessionIndex/$($backupSessions.Count))*100)
			#$backupSessions = $backupSessions | ?{$_.Jobname -eq "Pronto Backup"} | %{
			$backupSession = $_
			$sessionInfo = $_.Info 
			
			$obj = New-Object System.Object
			$obj | Add-Member -MemberType NoteProperty -Name "Backup Name" -Value $sessionInfo.JobName
			$obj | Add-Member -MemberType NoteProperty -Name "Internal Name" -Value $backupSession.Name
			$obj | Add-Member -MemberType NoteProperty -Name "Type" -Value $sessionInfo.JobAlgorithm
			$obj | Add-Member -MemberType NoteProperty -Name "Count" -Value $backupSession.Count
			$obj | Add-Member -MemberType NoteProperty -Name "Result" -Value $sessionInfo.Result
			$obj | Add-Member -MemberType NoteProperty -Name "Creation Time" -Value $sessionInfo.CreationTime
			$obj | Add-Member -MemberType NoteProperty -Name "End Time"  -Value $sessionInfo.EndTime
			if ($sessionInfo.EndTime -gt $sessionInfo.CreationTime)
			{
				$totalTimeInSeconds = $(($sessionInfo.EndTime - $sessionInfo.CreationTime).TotalSeconds)
			} else {
				$totalTimeInSeconds =  0
				
			}
			$obj | Add-Member -MemberType NoteProperty -Name "Month" -Value (get-date $sessionInfo.CreationTime -Format "MMM-yyyy")
			$obj | Add-Member -MemberType NoteProperty -Name "Duration (Seconds)"  -Value $totalTimeInSeconds
			$obj | Add-Member -MemberType NoteProperty -Name "Data Read (GB)"  -Value ([Math]::Round($sessionInfo.BackedUpSize / 1GB,2))
			$obj | Add-Member -MemberType NoteProperty -Name "Transferred (GB)"  -Value ([Math]::Round($sessionInfo.BackupTotalSize / 1GB,2))			
			$obj | Add-Member -MemberType NoteProperty -Name "Target Path" -Value ($backups | ?{$_.JobId -eq $sessionInfo.JobId}).DirPath
			$obj
			$sessionIndex++
		}
		if ($report)
		{
			Set-Variable -Scope "Global" -Name "backupSessions" -Value $report
			return $global:backupSessions
		} else {
			return $null
		}
	}
}

############################################################################################################################# - OK
# test using this
function Get-VeeamBackupSessions ([bool]$chartFriendly=$false)
{	
	if ($chartFriendly)
	{
		return get-backupsessions
	} else {
		$backupSessions = get-backupsessions
		#logThis -msg  "`t-> Collecting Backup History [Get-VeeamBackupSessions]"
		logThis -msg "`t`t-> Converting RAW to Friendly..."
		$report = $backupSessions  | %{	
			$sessionInfo=$_
			
			$obj = New-Object System.Object
			$obj | Add-Member -MemberType NoteProperty -Name "Backup Name" -Value $sessionInfo."Backup Name"
			$obj | Add-Member -MemberType NoteProperty -Name "Internal Name" -Value $sessionInfo."Internal Name"
			$obj | Add-Member -MemberType NoteProperty -Name "Type" -Value $sessionInfo.Type
			$obj | Add-Member -MemberType NoteProperty -Name "Count" -Value $sessionInfo.Count
			$obj | Add-Member -MemberType NoteProperty -Name "Result" -Value $sessionInfo.Result
			$obj | Add-Member -MemberType NoteProperty -Name "Creation Time" -Value $sessionInfo."Creation Time"
			$obj | Add-Member -MemberType NoteProperty -Name "End Time"  -Value $sessionInfo."End Time"
			$obj | Add-Member -MemberType NoteProperty -Name "Month" -Value $sessionInfo.Month
			$obj | Add-Member -MemberType NoteProperty -Name "Duration"  -Value $(getTimeSpanFormatted -timespan (New-Timespan -Seconds ($sessionInfo."Duration (Seconds)")))
			$obj | Add-Member -MemberType NoteProperty -Name "Data Read"  -Value $(getSize -unit "GB" -val ($sessionInfo."Data Read (GB)"))
			$obj | Add-Member -MemberType NoteProperty -Name "Transferred"  -Value $(getSize -unit "GB" -val ($sessionInfo."Transferred (GB)"))
			$obj | Add-Member -MemberType NoteProperty -Name "Target Path" -Value $sessionInfo."Target Path"
			$obj
		}
		return $report
	}	
}

############################################################################################################################# - OK
# The input for this function should be with variable $backupSessions which you can obtain it by running get-backupsessions
function Get-VeeamClientBackups ([bool]$chartFriendly=$false)
{
	if ($chartFriendly)
	{
		return get-individualsessions
	} else {	
		$backupSessions = get-individualsessions
		logThis -msg "`t`t-> Converting RAW to Friendly..."		
		$report = $backupSessions | %{
			$job_session = $_
			$obj = New-Object System.Object
			# Size of the VM object
			$obj | Add-Member -MemberType NoteProperty -Name "Name" -Value $job_session.Name
			$obj | Add-Member -MemberType NoteProperty -Name "Status" -Value $job_session.Status
			$obj | Add-Member -MemberType NoteProperty -Name "Job Name" -Value $job_session."Job Name"
			$obj | Add-Member -MemberType NoteProperty -Name "Client Size" -Value $(getSize -unit "GB" -val ($job_session."Client Size (GB)"))
			$obj | Add-Member -MemberType NoteProperty -Name "Data Read Size" -Value $(getSize -unit "GB" -val ($job_session."Data Read Size (GB)" ))
			$obj | Add-Member -MemberType NoteProperty -Name "Data Transfered Size" -Value $(getSize -unit "GB" -val ($job_session."Data Transfered Size (GB)"))
			$obj | Add-Member -MemberType NoteProperty -Name "Start Time" -Value $job_session."Start Time"
			$obj | Add-Member -MemberType NoteProperty -Name "Stop Time" -Value $job_session."Stop Time"
			$obj | Add-Member -MemberType NoteProperty -Name "Queue Time" -Value $job_session."Queue Time"
			$obj | Add-Member -MemberType NoteProperty -Name "Duration (Seconds)" -Value $(getTimeSpanFormatted -timespan (New-Timespan -Seconds $job_session."Duration (Seconds)"))
			$obj | Add-Member -MemberType NoteProperty -Name "Backup Type" -Value $job_session."Backup Type"
			$obj
		}
	}	
	return $report
}
#$sessions=get-individualsessions -refresh $true
#$report = Get-VeeamClientBackups -chartFriendly $true ; $report[0]
#$report = Get-VeeamClientBackups -chartFriendly $false ; $report[0]

############################################################################################################################# - OK
function Get-VeeamClientBackupsSummary-ClientInfrastructureSize([bool]$chartFriendly=$false,[object]$reportingMonths)
{
	$clientBackupsChartFriendly=Get-VeeamClientBackups -chartFriendly $true | group Name
	$clientBackupsChartFriendlyIndex=1
	#$clients = $clientBackupsChartFriendly 
	logThis -msg "`t`t-> Generating report ..."	
	$report =  $clientBackupsChartFriendly | %{
		Write-Progress -Activity "Processing Individual Backups [Get-VeeamClientBackupsSummary-ClientInfrastructureSize]" -Id 1 -Status "$clientBackupsChartFriendlyIndex/$($clientBackupsChartFriendly.Count) :- $($_.Name)..." -PercentComplete  (($clientBackupsChartFriendlyIndex/$($clientBackupsChartFriendly.Count))*100)
		$client=$_
		$allBackupInstances = $client.Group
		#$allBackupInstances[0]
		#ause
		$obj = New-Object System.Object
		# Size of the VM object
		$obj | Add-Member -MemberType NoteProperty -Name "Name" -Value $client.Name
		$successRate = [Math]::Round(($allBackupInstances.Status | ?{$_ -eq "Success"}).Count/$allBackupInstances.count*100,2)
		if ($chartFriendly)
		{
			$obj | Add-Member -MemberType NoteProperty -Name "Success rate (%)" -Value $successRate
		} else {
			$obj | Add-Member -MemberType NoteProperty -Name "Success rate" -Value $("{0:N2} %" -f $successRate)
		}
		
		# Give the Max size of Client for that month
		$parameters="Client Size (GB)"
		
		$parameters | %{
			$parameterName=$_
			$columnLabelPrefix=$($parameterName -replace "\(bytes\)").Trim()
			#$totalForThisBackupJobGB=0
			$reportingMonths | %{
				$monthName=$_
				$sizeGB=$($allBackupInstances | select "Start Time","$parameterName" | Sort "Start Time" | ?{(get-date $_."Start Time" -Format $global:dateFormat) -eq $monthName} | Sort -Descending $parameterName | Select -First 1).$parameterName
				if ($chartFriendly)
				{
					$obj | Add-Member -MemberType NoteProperty -Name "$monthName (GB)" -Value $sizeGB
				} else {
					$obj | Add-Member -MemberType NoteProperty -Name "$monthName" -Value $(getSize -unit "GB" -val $sizeGB)
				}
				#$totalForThisBackupJobGB += $biggestSizeGBThisMonth
			}
		}		
		
		$obj
		$clientBackupsChartFriendlyIndex++
	}
	return $report
}
############################################################################################################################# - OK
function Get-VeeamClientBackupsSummary-ChangeRate([bool]$chartFriendly=$false,[object]$reportingMonths)
{
	$clientBackupsChartFriendly=Get-VeeamClientBackups -chartFriendly $true | group Name
	$clientBackupsChartFriendlyIndex=1
	#$clients = $clientBackupsChartFriendly 
	logThis -msg "`t`t-> Generating report ..."	
	$report =  $clientBackupsChartFriendly | %{
		Write-Progress -Activity "Processing Individual Backups [Get-VeeamClientBackupsSummary-ChangeRate]" -Id 1 -Status "$clientBackupsChartFriendlyIndex/$($clientBackupsChartFriendly.Count) :- $($_.Name)..." -PercentComplete  (($clientBackupsChartFriendlyIndex/$($clientBackupsChartFriendly.Count))*100)
		$client=$_
		$allBackupInstances = $client.Group
		#$allBackupInstances[0]
		#ause
		$obj = New-Object System.Object
		# Size of the VM object
		$obj | Add-Member -MemberType NoteProperty -Name "Name" -Value $client.Name
		$successRate = [Math]::Round(($allBackupInstances.Status | ?{$_ -eq "Success"}).Count/$allBackupInstances.count*100,2)
		if ($chartFriendly)
		{
			$obj | Add-Member -MemberType NoteProperty -Name "Success rate (%)" -Value $successRate
		} else {
			$obj | Add-Member -MemberType NoteProperty -Name "Success rate" -Value $("{0:N2} %" -f $successRate)
		}
				
		# Give the Max size of Client for that month
		$nameOfLastMonth=$reportingMonths | select -Last 1
		$parameters="Data Read Size (GB)"
		$parameters | %{
			$parameterName=$_
			$columnLabelPrefix=$($parameterName -replace "Size \(bytes\)").Trim()
			$totalForThisBackupJobGB=0
			$reportingMonths | %{
				$monthName=$_
				$monthlyBackupInstances = $allBackupInstances | select "Status","Start Time","$parameterName" | Sort "Start Time" | ?{(get-date $_."Start Time" -Format $global:dateFormat) -eq $monthName}
				$backupSizeGB = ($monthlyBackupInstances.$parameterName | Measure -Sum).Sum
				#Write-Host $sizeBytes
				#pause

				if ($chartFriendly)
				{
					$obj | Add-Member -MemberType NoteProperty -Name "$monthName (GB)" -Value $backupSizeGB
				} else {
					$obj | Add-Member -MemberType NoteProperty -Name "$monthName" -Value $(getSize -unit "GB" -val $backupSizeGB)
				}				
				
				# get the average rate for this last month only.
				
				if ($nameOfLastMonth -eq $monthName)
				{
					$allBackupInstances."Backup Type" | sort -Unique | %{
						$typeName = $_
						$avgbackupSizeGB = [Math]::Round(($monthlyBackupInstances | ?{$_.Status -eq "Success" -and $_."Backup Type" -eq $typeName -and $_.$parameterName -gt 0} | measure $parameterName -Average).Average,2)
						$maxbackupSizeGB = [Math]::Round(($monthlyBackupInstances | ?{$_.Status -eq "Success" -and $_."Backup Type" -eq $typeName -and $_.$parameterName -gt 0} | measure $parameterName -Maximum).Maximum,2)
						if ($chartFriendly)
						{
							$obj | Add-Member -MemberType NoteProperty -Name "Average $typeName for $monthName (GB)" -Value $avgbackupSizeGB
							$obj | Add-Member -MemberType NoteProperty -Name "Largest $typeName for $monthName (GB)" -Value $maxbackupSizeGB
						} else {
							$obj | Add-Member -MemberType NoteProperty -Name "Average $typeName for $monthName" -Value $(getSize -unit "GB" -val $avgbackupSizeGB)
							$obj | Add-Member -MemberType NoteProperty -Name "Largest $typeName for $monthName" -Value $(getSize -unit "GB" -val $maxbackupSizeGB)
						}
					}
				}
				
				$totalForThisBackupJobGB += $backupSizeGB
			}
			if ($chartFriendly)
			{
				$obj | Add-Member -MemberType NoteProperty -Name "Total for past $($reportingMonths.Count) months (GB)" -Value $totalForThisBackupJobGB
			} else {
				$obj | Add-Member -MemberType NoteProperty -Name "Total for past $($reportingMonths.Count) months " -Value $(getSize -unit "GB" -val $totalForThisBackupJobGB)
			}
			
		}
		
		$obj
		$clientBackupsChartFriendlyIndex++
	}
	return $report
}
############################################################################################################################# - OK
function Get-VeeamClientBackupsSummary-DataIngested([bool]$chartFriendly=$false,[object]$reportingMonths)
{
	$clientBackupsChartFriendly=Get-VeeamClientBackups -chartFriendly $true | group Name
	$clientBackupsChartFriendlyIndex=1
	#$clients = $clientBackupsChartFriendly 
	logThis -msg "`t`t-> Generating report ..."	
	$report =  $clientBackupsChartFriendly | %{
		Write-Progress -Activity "Processing Individual Backups [Get-VeeamClientBackupsSummary-DataIngested]" -Id 1 -Status "$clientBackupsChartFriendlyIndex/$($clientBackupsChartFriendly.Count) :- $($_.Name)..." -PercentComplete  (($clientBackupsChartFriendlyIndex/$($clientBackupsChartFriendly.Count))*100)
		$client=$_
		$allBackupInstances = $client.Group
		#$allBackupInstances[0]
		#ause
		$obj = New-Object System.Object
		# Size of the VM object
		$obj | Add-Member -MemberType NoteProperty -Name "Name" -Value $client.Name
		$successRate = [Math]::Round(($allBackupInstances.Status | ?{$_ -eq "Success"}).Count/$allBackupInstances.count*100,2)
		if ($chartFriendly)
		{
			$obj | Add-Member -MemberType NoteProperty -Name "Success rate (%)" -Value $successRate
		} else {
			$obj | Add-Member -MemberType NoteProperty -Name "Success rate" -Value $("{0:N2} %" -f $successRate)
		}
				
		# Give the Max size of Client for that month
		$nameOfLastMonth=$reportingMonths | select -Last 1
		$parameters="Data Transfered Size (GB)"
		$parameters | %{
			$parameterName=$_
			$columnLabelPrefix=$($parameterName -replace "Size \(bytes\)").Trim()
			$totalForThisBackupJobGB=0
			$reportingMonths | %{
				$monthName=$_
				$monthlyBackupInstances = $allBackupInstances | select "Status","Start Time","$parameterName" | Sort "Start Time" | ?{(get-date $_."Start Time" -Format $global:dateFormat) -eq $monthName}
				$backupSizeGB = ($monthlyBackupInstances.$parameterName | Measure -Sum).Sum
				#Write-Host $sizeBytes
				#pause

				if ($chartFriendly)
				{
					$obj | Add-Member -MemberType NoteProperty -Name "$monthName (GB)" -Value $backupSizeGB
				} else {
					$obj | Add-Member -MemberType NoteProperty -Name "$monthName" -Value $(getSize -unit "GB" -val $backupSizeGB)
				}
				# get the average rate for this last month only.
				if ($nameOfLastMonth -eq $monthName)
				{
					$allBackupInstances."Backup Type" | sort -Unique | %{
						$typeName = $_
						$avgbackupSizeGB = [Math]::Round(($monthlyBackupInstances | ?{$_.Status -eq "Success" -and $_."Backup Type" -eq $typeName -and $_.$parameterName -gt 0} | measure $parameterName -Average).Average,2)
						$maxbackupSizeGB = [Math]::Round(($monthlyBackupInstances | ?{$_.Status -eq "Success" -and $_."Backup Type" -eq $typeName -and $_.$parameterName -gt 0} | measure $parameterName -Maximum).Maximum,2)
						if ($chartFriendly)
						{
							$obj | Add-Member -MemberType NoteProperty -Name "Average $typeName for $monthName (GB)" -Value $avgbackupSizeGB
							$obj | Add-Member -MemberType NoteProperty -Name "Largest $typeName for $monthName (GB)" -Value $maxbackupSizeGB
						} else {
							$obj | Add-Member -MemberType NoteProperty -Name "Average $typeName for $monthName" -Value $(getSize -unit "GB" -val $avgbackupSizeGB)
							$obj | Add-Member -MemberType NoteProperty -Name "Largest $typeName for $monthName" -Value $(getSize -unit "GB" -val $maxbackupSizeGB)
						}
					}
				}				
				$totalForThisBackupJobGB += $backupSizeGB
			}
			if ($chartFriendly)
			{
				$obj | Add-Member -MemberType NoteProperty -Name "Total for past $($reportingMonths.Count) months (GB)" -Value $totalForThisBackupJobGB
			} else {
				$obj | Add-Member -MemberType NoteProperty -Name "Total for past $($reportingMonths.Count) months " -Value $(getSize -unit "GB" -val $totalForThisBackupJobGB)
			}
		}
		
		$obj
		$clientBackupsChartFriendlyIndex++
	}
	return $report
}

############################################################################################################################# - OK
function Get-BackupRepoNameById ([string]$repoId)
{
	return ($global:backupRepositories | ?{$_.Id -eq $repoId}).Path
}


############################################################################################################################# - OK
function Get-VeeamBackupRepositoryies ([bool]$chartFriendly=$false,[bool]$refresh=$false)
{
	Write-Host
	if ($global:backupRepositories -and !$refresh)
	{
		logThis -msg "`t`t-> Re-using existing collection of backup Repositories"
		return $global:backupRepositories
	} else {	
		logThis -msg "`t`t-> First time collection of Backup Repositories"
		$report = Get-VBRBackupRepository
		if ($report)
		{	
			$global:backupRepositories = $report
			return $global:backupRepositories
		} else {
			return $global:backupRepositories
		}
	}
}


############################################################################################################################# - OK
# The input for this function should be with variable $backupSessions which you can obtain it by running Get-VeeamBackupSessions
function Get-BackupJobsSummary ([bool]$chartFriendly=$false,[object]$reportingMonths)
{
	# Proposed Output 
	# Job Name, First Backup,Most Recent Backup, Total backups, Percentage of Failed backups
	#logThis -msg  "`t-> Creating Per Backup Job Capacity Summary [Get-BackupJobsSummary]"
	$backupSessions = Get-VeeamBackupSessions -chartFriendly $true	
	$sessionIndex=1
	logThis -msg "`t`t-> Processing..."
	$report = $backupSessions | group "Backup Name" | %{
		Write-Progress -Activity "Processing Sanitised Backup sessions Information [Get-BackupJobsSummary]" -Id 1 -Status "$sessionIndex/$($backupSessions.Count) :- $($_.Name)..." -PercentComplete  (($sessionIndex/$($backupSessions.Count))*100)
		$backupJob = $_
		$allBackupInstances = $backupJob.Group
		$obj = New-Object System.Object
		$obj | Add-Member -MemberType NoteProperty -Name "Backup Name" -Value $backupJob.Name	
		$obj | Add-Member -MemberType NoteProperty -Name "Type" -Value (($allBackupInstances | group JobName)[0].group.Type | select -unique)
		$obj | Add-Member -MemberType NoteProperty -Name "Oldest Backup" -Value ($allBackupInstances."Creation Time" | sort | select -First 1)
		$obj | Add-Member -MemberType NoteProperty -Name "Most Recent Backup" -Value ($allBackupInstances."Creation Time" | sort -Descending | select -First 1)
		$obj | Add-Member -MemberType NoteProperty -Name "Total Number of Backups" -Value ($allBackupInstances.result | measure).Count	
		if ($chartFriendly)
		{
			$obj | Add-Member -MemberType NoteProperty -Name "Avg Duration (Seconds)" -Value ($allBackupInstances."Duration (Seconds)" | ?{$_ -gt 0} | measure -Average).Average
			$obj | Add-Member -MemberType NoteProperty -Name "Max Duration (Seconds)" -Value ($allBackupInstances."Duration (Seconds)" | ?{$_ -gt 0} | measure -Maximum).Maximum
			$obj | Add-Member -MemberType NoteProperty -Name "Perc. Failed Backups (%)" ([Math]::Round(($allBackupInstances.result | ?{$_ -eq "Failed"} | measure).Count / ($allBackupInstances | measure).Count * 100,2))
			$obj | Add-Member -MemberType NoteProperty -Name "Avg Size INCR (GB)" -Value  ($allBackupInstances | ?{$_.Type -eq "Incremental"} |  measure -Property "Transferred (GB)" -Average).Average
			$obj | Add-Member -MemberType NoteProperty -Name "Max Size INCR (GB)" -Value  ($allBackupInstances | ?{$_.Type -eq "Incremental"} |  measure -Property "Transferred (GB)" -Maximum).Maximum
			
		} else {
			$obj | Add-Member -MemberType NoteProperty -Name "Avg Duration" -Value $(getTimeSpanFormatted -timespan (New-Timespan -Seconds ($allBackupInstances."Duration (Seconds)" | ?{$_ -gt 0} | measure -Average).Average))
			$obj | Add-Member -MemberType NoteProperty -Name "Max Duration" -Value $(getTimeSpanFormatted -timespan (New-Timespan -Seconds ($allBackupInstances."Duration (Seconds)" | ?{$_ -gt 0} | measure -Maximum).Maximum))
			$obj | Add-Member -MemberType NoteProperty -Name "Perc. Failed Backups" -Value $("{0:N2} %" -f ([Math]::Round(($allBackupInstances.result | ?{$_ -eq "Failed"} | measure).Count / ($allBackupInstances | measure).Count * 100,2)))
			$obj | Add-Member -MemberType NoteProperty -Name "Avg Size INCR" -Value  $(getSize -unit "GB" -val ($allBackupInstances | ?{$_.Type -eq "Incremental"} |  measure -Property "Transferred (GB)" -Average).Average)
			$obj | Add-Member -MemberType NoteProperty -Name "Max Size INCR" -Value  $(getSize -unit "GB" -val ($allBackupInstances | ?{$_.Type -eq "Incremental"} |  measure -Property "Transferred (GB)" -Maximum).Maximum)	
		}

		# for each day, get the size
		$totalForThisBackupJobGB=0
		$reportingMonths | %{
			$monthName=$_
			$monthlyBackupInstances = $allBackupInstances | select "Creation Time","Transferred (GB)" | Sort "Creation Time" | ?{(get-date $_."Creation Time" -Format $global:dateFormat) -eq $monthName}
			$backupSizeGB = $([Math]::Round(($monthlyBackupInstances."Transferred (GB)" | Measure -Sum).Sum,2))
			if ($chartFriendly)
			{
				$obj | Add-Member -MemberType NoteProperty -Name "$monthName (GB)" -Value $backupSizeGB
			} else {
				$obj | Add-Member -MemberType NoteProperty -Name "$monthName" -Value $(getSize -unit "GB" -val $backupSizeGB)
			}
			$totalForThisBackupJobGB += $backupSizeGB
		}
		if ($chartFriendly)
		{
			$obj | Add-Member -MemberType NoteProperty -Name "Total (GB)" $totalForThisBackupJobGB
		} else {
			$obj | Add-Member -MemberType NoteProperty -Name "Total" $(getSize -unit "GB" -val $totalForThisBackupJobGB)
		}
		#$obj | Add-Member -MemberType NoteProperty -Name "Target Paths" -Value (($allBackupInstances | group "Target Path")[0].group.Type | select -unique)
		$obj 
		$sessionIndex++
	}

	return $report
}

#############################################################################################################################- OK
function Get-MonthlyBackupCapacity ([bool]$chartFriendly=$false,[object]$reportingMonths)
{
	$backupSessions = Get-VeeamBackupSessions -chartFriendly $true
	$clientBackupsChartFriendly = Get-VeeamClientBackups -chartFriendly $true
	#$backupsGroupedByClients = $clientBackupsChartFriendly
	$monthIndex=1
	logThis -msg "`t`t-> Processing..."
	$report = $reportingMonths | %{		
		$monthName=$_
		Write-Progress -Activity "Processing Monthly Capacity [Get-MonthlyBackupCapacity]" -Id 1 -Status "$monthIndex/$($reportingMonths.Count) :- $monthName..." -PercentComplete  (($monthIndex/$($reportingMonths.Count))*100)
		$obj = New-Object System.Object
		$obj | Add-Member -MemberType NoteProperty -Name "Month" -Value $monthName
		# Give the Max size of Client for that month$report
		
		$all_client_backups_for_this_month = $clientBackupsChartFriendly | Sort "Start Time" | ?{(get-date $_."Start Time" -Format $global:dateFormat) -eq $monthName}
		##########
		

		$parameterName="Client Size (GB)"
		$columnLabelPrefix="Size of Infrastructure To Backup"
		$totalForThisBackupJobGB=0
		$all_client_backups_for_this_month | group Name | %{
			$client_backups_for_this_month =$_.Group
			$totalForThisBackupJobGB +=$($client_backups_for_this_month | select "Start Time","$parameterName" | Sort -Descending $parameterName | Select -First 1).$parameterName			
		}
		
		if ($chartFriendly)
		{
			$obj | Add-Member -MemberType NoteProperty -Name "$columnLabelPrefix (GB)" -Value $totalForThisBackupJobGB
		} else {
			$obj | Add-Member -MemberType NoteProperty -Name "$columnLabelPrefix" -Value $(getSize -unit "GB" -val $totalForThisBackupJobGB)
		}
		
		# Give the Max size of Client for that month
		$parameterName="Data Read Size (GB)"
		$columnLabelPrefix="Amount of Data changed Identified by VMware CBT (Rate of change)"
		#$monthlyBackupInstances = $all_client_backups_for_this_month | Sort "Start Time" | ?{(get-date $_."Start Time" -Format $global:dateFormat) -eq $monthName}
		$backupSizeGB = (($all_client_backups_for_this_month | select "Start Time","$parameterName").$parameterName | measure -Sum).Sum
		if ($chartFriendly)
		{
			$obj | Add-Member -MemberType NoteProperty -Name "$columnLabelPrefix (GB)" -Value $backupSizeGB
		} else {
			$obj | Add-Member -MemberType NoteProperty -Name "$columnLabelPrefix" -Value $(getSize -unit "GB" -val $backupSizeGB)
		}	
		
		# Give the Max size of Client for that month
		$parameterName="Data Transfered Size (GB)"
		$columnLabelPrefix="Amount of Data Transferred to Veeam"
		#$monthlyBackupInstances = $all_client_backups_for_this_month | Sort "Start Time" | ?{(get-date $_."Start Time" -Format $global:dateFormat) -eq $monthName}
		$backupSizeGB = (($all_client_backups_for_this_month | select "Start Time","$parameterName").$parameterName | measure -Sum).Sum
		if ($chartFriendly)
		{
			$obj | Add-Member -MemberType NoteProperty -Name "$columnLabelPrefix (GB)" -Value $backupSizeGB
		} else {
			$obj | Add-Member -MemberType NoteProperty -Name "$columnLabelPrefix" -Value $(getSize -unit "GB" -val $backupSizeGB)
		}	
		
		$obj	
		$monthIndex++
	}
	return $report
}
#############################################################################################################################- NOT OK
function get-ondiskBackups()
{
	$backupDirectories = (get-backupSpecs).DirPath | sort -Unique
	$report = $backupDirectories | %{
		$directory = $_
		if (Test-Path -Path $directory)
		{
			$obj = New-Object System.Object			
			$obj | Add-Member -MemberType NoteProperty -Name "Name" -Value $directory		
			$obj
		}
	}
}
#endregion

#region Main Routine
#############################################################################################################################
#
# 				M	A	I	N			C	O	U	R	S	E
#
#############################################################################################################################
logThis -msg  "Being @ $(Get-date)"
$reportDate = Get-Date -Format "dd-MM-yy"
$veeamServer=Get-VBRLocalhost

$node=@{}
$node["Name"]= $veeamServer.RealName
$node["Report Properties"]=@{}
$node["Report Properties"]["Report Ran on"]=$reportDate
$node["Server Information"]=$veeamServer
$node["Reporting Period (Months)"] = $showLastMonths
logThis -msg  "`t-> Collecting Backup Repository Information"
$node["Repositories"] = Get-VeeamBackupRepositoryies -chartFriendly $chartFriendly
logThis -msg  "`t-> Collecting Backup Sessions"
$node["Backup Sessions"] = Get-VeeamBackupSessions -chartFriendly $chartFriendly
logThis -msg  "`t-> Collecting Individual Backup Tasks"
$node["Backups by Clients"] = Get-VeeamClientBackups -chartFriendly $chartFriendly

# Get first day, last day
$firstRecordedBackupDay = $node["Backup Sessions"]."Creation Time" | sort |  select -First 1
$node["Report Properties"]["Sample Start Date"]=$firstRecordedBackupDay
$lastRecordedBackupDay = $node["Backup Sessions"]."Creation Time" | sort | select -Last 1
$thisDate=(Get-Date -Format $dateFormat)

$node["Report Properties"]["Sample End Date"]=$lastRecordedBackupDay
$reportingMonths = $node["Backup Sessions"].Month | %{ get-date $_ } | Select -Unique | Sort | %{ get-date $_ -format $dateFormat } | ?{$_ -ne $thisDate} | Select -Last $node["Reporting Period (Months)"]
logThis -msg  "`t-> Creating Backup Jobs Summary"
$node["Jobs Summary"] = Get-BackupJobsSummary -chartFriendly $chartFriendly -reportingMonths $reportingMonths

logThis -msg  "`t->Client Sizes"
$node["Client Sizes"] = Get-VeeamClientBackupsSummary-ClientInfrastructureSize -chartFriendly $chartFriendly -reportingMonths $reportingMonths

logThis -msg  "`t->Data Change Rate"
$node["Data Change Rate"] = Get-VeeamClientBackupsSummary-ChangeRate -chartFriendly $chartFriendly -reportingMonths $reportingMonths

logThis -msg  "`t->Data Transfered"
$node["Data Transfered"] = Get-VeeamClientBackupsSummary-DataIngested -chartFriendly $chartFriendly -reportingMonths $reportingMonths

logThis -msg  "`t-> Creating Monthly Capacity Summary"
$node["Monthly Capacity"] = Get-MonthlyBackupCapacity -chartFriendly $chartFriendly -reportingMonths $reportingMonths

logThis -msg "Writing Report to Disks @ $logDir"
#$prefix="$logDir\$reportDate-$($node['Name'])"
$prefix="$logDir"
if ($xmlOutput)
{
	$node | Export-Clixml "$logDir\$reportDate-$($node['Name']).xml"
}
if ($csvOutput)
{
	"Server Information","Repositories","Backup Sessions","Backups by Clients","Jobs Summary","Client Sizes","Data Change Rate","Data Transfered","Monthly Capacity" | %{
		$lable=$_
		$node[$lable]  | Export-Csv -NoTypeInformation "$prefix\$lable.csv"
		#$node[$lable]  | Export-Csv -NoTypeInformation "$lable.csv"
	}
}
logThis -msg  "Completed @ $(Get-date)"
#endregion
