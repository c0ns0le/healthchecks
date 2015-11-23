# This script is intended to collect information from IBM Tivoli Storage Manager using built in dsmadm.
# Version: 0.3 - May 25th 2015
# maintainer: teiva.rodiere@gmail.com
# Syntax: .\tsm-checks.ps1 -logDir "C:\tsm-checks" -username admin -password "admin" -servers @("tsmserver1","tsmserver2")
# Syntax: .\tsm-checks.ps1 -logDir "C:\tsm-checks" -servers @("tsmserver","admin","password")
#
# Prerequisites:
# 1) Install the IBM Tivoli Storage Manager Client (ONLY THE Administrative CLI) on the system you are running this report from AND running the powershell scripts.
# 2) Make sure dsm.opt file is available locally in the same directory as this script.
#

param([string]$logDir="output",
	[string]$comment="",
	[bool]$verbose=$false,
	[bool]$openReportOnCompletion=$false,
	[System.Object][System.Object]$servers,
	[string]$username,
	[string]$password,
	[bool]$DEBUG=$false,
	[int]$reportPeriodDays=30,
	[int]$logsCount=100,
	[int]$topItemsOnly=10,
	$useThisTSMServerObject,
	[string]$dsmadm="C:\Program Files\Tivoli\TSM\baclient\dsmadmc.exe"
)
# This section will be replaced by content from the customer.ini file
$customerName="Customer A"
$itoContactName="ITO Guy"
$reportHeader ="TSM Health Check"
$reportIntro="This document presents a health check of IBM Tivoli Storage Manager infrasructure for $customerName, prepared by $itoContactName."

########################################################################
# Include this section with every script to accelerate and standardise the process for reporting
if ($global:reportIndex) { Remove-Variable reportIndex }
if ($reportIndex) { Remove-Variable reportIndex }
Write-Host "Importing Module genericModules.psm1 (force)"
Import-Module -Name ".\genericModules.psm1" -Force -PassThru
Import-Module -Name ".\ibmTsmModules.psm1" -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name reportIndex -Value "$logDir\index.txt" -Scope Global
Set-Variable -Name dsmadm -Value $dsmadm -Scope Global

echo "" | Out-file $reportIndex
InitialiseModule

###########################################################################################
#
# START COLLECTING THE NECESSARY CONTENT FROM TSM
#
if (!$useThisTSMServerObject)
{
	$deviceList = createDeviceList -servers $servers
	$tsmServers = @{}
	$tsmserverCountIndex=1
	$tsmServers = $deviceList | %{
		Write-Host "[$tsmserverCountIndex/$($deviceList.Count)] :- Processing $($_.Target)/$($_.Username)/$($_.Password)" -ForegroundColor Yellow
		$tsmserver = collectTSMInformation -server $_.Target -username $_.Username -password $_.Password -reportPeriodDays $reportPeriodDays -showRuntime $true
		$tsmserver.Add("Index",$tsmserverCountIndex)
		$tsmserver
		$tsmserverCountIndex++
	}
} else {
	$tsmServers = $useThisTSMServerObject
}
# If there are servers to process continue, otherwise exit
if ($tsmServers)
{

	Write-Host "Processing reports.." -ForegroundColor Yellow

	############################################################################################################
	# SHOW List of TSM Servers audit in this health check.
	$showAuditedServers=$true
	if ($showAuditedServers)
	{
		setSectionHeader -type "h1" -title "Audit"

		$tableHeader="Servers"
		logThis -msg "Processing $tableHeader Report"
		$tableData = $tsmServers | %{
			$tsmServer=$_
			$obj = New-Object System.Object
			$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value $tsmServer.Name
			$obj
		}
		if ($tableData)
		{
			export -title $tableHeader -dataTable $tableData -displayTableOrientation "List" -headerType "h2" -metaAnalytics "" -showTableCaption "false" -description ""
		}
	}

	############################################################################################################
	# SHOW SYSTEMS INFORMATION
	$showSystemsSummary=$true
	if ($showSystemsSummary)
	{
		setSectionHeader -type "h1" -title "Summary"
		#setSectionHeader -type "h1" -title "ITSM Server Configuration"

		$tableHeader="Server Information"
		logThis -msg "Processing $tableHeader Report"
		$tableData = $tsmServers | %{
			$tsmServer=$_
			$obj = New-Object System.Object
			if ($tsmservers.Name.Count -gt 1) {$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value "$($tsmServer.Name)"}
			$obj | Add-Member -MemberType NoteProperty -Name "Installation Type" -Value $tsmServer.Status.Platform
			$obj | Add-Member -MemberType NoteProperty -Name "Version" -Value "$($tsmServer.Status.Version).$($tsmServer.Status.Release).$($tsmServer.Status.Level).$($tsmServer.Status.Sublevel)"
			if ($tsmServer.Licenses.TSMEE_LIC -eq "Yes")
			{
				$installEdition = "TSM Extended Edition"
			} elseif ($tsmServer.Licenses.TSMBASIC_LIC -eq "Yes")
			{
				$installEdition = "TSM Basic Edition"
			}

			if ($tsmServer.Licenses.COMPLIANCE -eq "Valid")
			{
				$compliance = "Valid"
			} else {
				$compliance = "Not valid"
				$issuesRegister += "$($tsmServer.Name) has an invalid licence compliance"
			}

			# Check for Activated Licences to show later
			#Write-Host ">>>>>>> HERE <<<<<<<<"
			#$tsmServer.Licences.Values
			#Write-Host ">>>>>>> HERE <<<<<<<<"
			$licenceTypes = ($tsmServer.Licenses | Get-Member -MemberType NoteProperty | Select Name).Name | ?{$_.Contains("_ACT")} | %{
				if (
					((isNumeric -x $tsmServer.Licenses."$_") -and $tsmServer.Licenses."$_" -gt 0) -or
					(!(isNumeric -x $tsmServer.Licenses."$_") -and $tsmServer.Licenses."$_" -eq "Yes")
				)
				{
					if (-not $_.Contains("TSMBASIC") -and -not $_.Contains("TSMEE"))
					{
						#Write-Host ">> $_" -ForegroundColor Yellow
						$_ -replace "_ACT",""
					}
				}
			}
			if ($tsmServer.Licenses.DATARET_LIC -eq "Yes" -and $tsmServer.Licenses.DATARET_ACT -eq $tsmServer.Licenses.DATARET_LIC)
			{
				$issuesRegister += "$($tsmServer.Name) is licensed for DATARET_LIC but not activated"
			}

			# Check how long since the last License Audit
			Write-Host $tsmServer.Licenses.AUDIT_DATE
			$auditDate = Get-date $tsmServer.Licenses.AUDIT_DATE
			if ( ((get-date) - $auditDate).Days -gt 30 )
			{
				$issuesRegister += "$($tsmServer.Name)'s license was last audited more than 30 days ago"
			}

			$obj | Add-Member -MemberType NoteProperty -Name "Edition" -Value $installEdition
			$obj | Add-Member -MemberType NoteProperty -Name "License" -Value "$compliance as of $(get-date $auditDate -Format 'F')"
			$obj | Add-Member -MemberType NoteProperty -Name "Licensed agents" -Value "$([string]$licenceTypes -replace '\s',', ')"

			# Client count
            $filter="CLIENT_OS_LEVEL"
			$str=$tsmServer.Clients | group $filter | select Name,Count | %{
				if ($_.Name -eq 0)
				{
					$Name = "Other"
				} else {
					$Name = $_.Name
				}
				", $($_.Count) x $Name"
			}
			#$obj | Add-Member -MemberType NoteProperty -Name "Client nodes" -Value "$(($tsmServer.Clients | measure $filter).Count)" # $([string] $str)
			$obj | Add-Member -MemberType NoteProperty -Name "Client nodes" -Value "$($tsmServer.Clients.Count) total, $($($tsmserver.Clients | ?{$_.HYPERVISOR -ne 0} | measure ).Count) running on a Hypervisor" # $([string] $str)

			# Backup summary
            $successfullBackups=$tsmServers.Summary | ?{$_.ACTIVITY.Contains('BACKUP') -and $_.SUCCESSFUL -eq 'YES'} | group ACTIVITY
			$totalBackupsCount=$($tsmServers.Summary | ?{$_.ACTIVITY.Contains('BACKUP') -and $_.SUCCESSFUL -eq 'YES'}).Count
			$totalBackupsAmt=$(formatNumbers -deci 2 -value $($($tsmServers.Summary | ?{$_.ACTIVITY.Contains('BACKUP') -and $_.SUCCESSFUL -eq 'YES'} | measure BYTES -Sum).Sum/1024/1024/1024))
			$str=""
			$str="$totalBackupsCount backup operations; total amount backed up $totalBackupsAmt GB."
			$successfullBackups | %{
				$type=$_
				$totalBKP=$($type.Group.BYTES | measure -Average).Average/1024/1024/1024
				switch ($type.Name)
				{
					"BACKUP" {$Name="daily"}
					"INCR_DBBACKUP" {$Name="incremental"}
					"FULL_DBBACKUP" {$Name="full"}
					default {$Name=$type.Name}
				}
				$str +=" Average $Name backup size of $(formatNumbers -deci 2 -value $totalBKP) GB."
			}
			$obj | Add-Member -MemberType NoteProperty -Name "Backups" -Value $str

			#"Backup","Restore","Replication" | %{
			"Restore","Replication" | %{
				#$metric=$($_.ToUpper())
				$metric=(Get-Culture).TextInfo.ToTitleCase(($_ -replace "_"," ").ToLower())
				$obj | Add-Member -MemberType NoteProperty -Name "$($metric)s" -Value "$(($tsmServer.Summary | ?{$_.ACTIVITY -eq $metric}).Count) ($(($tsmServer.Summary | ?{$_.SUCCESSFUL -eq 'YES' -and $_.ACTIVITY -eq $metric}).Count) Successful, $(($tsmServer.Summary | ?{$_.SUCCESSFUL -eq 'NO' -and $_.ACTIVITY -eq $metric}).Count) Failed)"
			}
			$filter="NODEGROUP"
			$str=$tsmServer.Clients | group $filter | select Name,Count | %{
				if ($_.Name -eq 0)
				{
					$Name = "Other"
				} else {
					$Name = $_.Name
				}
				",$Name"
			}
			#$obj | Add-Member -MemberType NoteProperty -Name "Node Groups" -Value "$([string] $str)"

			# DATABASE SUMMARY
			$usedDBSpace=[Math]::Round([double]$tsmServer.Database.USED_DB_SPACE_MB / [double]$tsmServer.Database.TOT_FILE_SYSTEM_MB * 100,2)
			if ($usedDBSpace -gt 85) #if the usage is greater than 85% notify
			{
				$issuesRegister += "$($tsmServer.Name)'s database ($($tsmServer.Database.DATABASE_NAME)) is $usedDBSpace% used on TSM Server $($tsmserver.Name)"
			}
			$lastBackupDate = get-date $tsmServer.Database.LAST_BACKUP_DATE
			$obj | Add-Member -MemberType NoteProperty -Name "Database" -Value "$usedDBSpace% used, $(formatNumbers -deci 2 -value $([double]$tsmServer.Database.FREE_SPACE_MB / 1024)) GB disk free space. Last backup on $(get-date $lastBackupDate -Format 'F')"


			# TSM LOG SUMMARY
			$str = ""
			#$tsmlogs = ($tsmServer.Logs | Get-Member -MemberType NoteProperty).Name | ?{$_.Contains("_DIR")} | %{
			if ($tsmServer.Logs.ACTIVE_LOG_DIR -ne 0)
			{
				$str += "Active Log $([Math]::Round([double]$tsmServer.Logs.USED_SPACE_MB / [double]$tsmServer.Logs.TOTAL_SPACE_MB * 100,2)) % used"
				if ($([Math]::Round([double]$tsmServer.Logs.USED_SPACE_MB / [double]$tsmServer.Logs.TOTAL_SPACE_MB * 100,2)) -gt 85)
				{
					$issuesRegister += "$($tsmServer.Name)'s active log has exceeded the 85% usage threshold"
				}
			} else {
				$str += "No active log found"
			}
			if ($tsmServer.Logs.ARCH_LOG_DIR -ne 0)
			{
				$str += ", Archived logs $([Math]::Round([double]$tsmServer.Logs.ARCHLOG_USED_FS_MB / [double]$tsmServer.Logs.ARCHLOG_TOL_FS_MB * 100,2)) % used"
				if ($([Math]::Round([double]$tsmServer.Logs.ARCHLOG_USED_FS_MB / [double]$tsmServer.Logs.ARCHLOG_TOL_FS_MB * 100,2)) -gt 85)
				{
					$issuesRegister += "$($tsmServer.Name)'s archive logs have exceeded the 85% usage threshold"
				}
			} else {
				$str += ", No archived logs found"
			}
			if ($tsmServer.Logs.AFAILOVER_LOG_DIR -ne 0)
			{
				$str += ", Failover log $([Math]::Round([double]$tsmServer.Logs.AFAILOVER_USED_FS_MB / [double]$tsmServer.Logs.AFAILOVER_TOL_FS_MB * 100,2)) % used"
				if ($([Math]::Round([double]$tsmServer.Logs.AFAILOVER_USED_FS_MB / [double]$tsmServer.Logs.AFAILOVER_TOL_FS_MB * 100,2)) -gt 85)
				{
					$issuesRegister += "$($tsmServer.Name)'s failover log has exceeded the 85% usage threshold"
				}
			} else {
				$str += ", No failover log found"
			}
			if ($tsmServer.Logs.MIRROR_LOG_DIR -ne 0)
			{
				$str += ", Mirror log $([Math]::Round([double]$tsmServer.Logs.MIRLOG_USED_FS_MB / [double]$tsmServer.Logs.MIRLOG_TOL_FS_MB * 100,2)) % used."
				if ($([Math]::Round([double]$tsmServer.Logs.MIRLOG_USED_FS_MB / [double]$tsmServer.Logs.MIRLOG_TOL_FS_MB * 100,2)) -gt 85)
				{
					$issuesRegister += "$($tsmServer.Name)'s mirror log has exceeded the 85% usage threshold"
				}
			} else {
				$str += ", mirror log directory not configured."
			}
			$obj | Add-Member -MemberType NoteProperty -Name "Log" -Value $str

            # Libraries
			$obj | Add-Member -MemberType NoteProperty -Name "Libraries" -Value "$($tsmServer.Libraries.Count)"
			if ($tsmServer.Libraries.Count -gt 0)
			{
				#$obj | Add-Member -MemberType NoteProperty -Name "Tape Drives/Slots" -Value "$($tsmServer.Libraries.Slots) Slots in total ($($tsmServer.Libraries.Used_Slots) Used, $($tsmServer.Libraries.Free_Slots) Free)"
				$totalDrives=($tsmserver.Libraries.Values.Drives | measure -Sum).Sum
                $totalSlots=($tsmServer.Libraries.Values.SLOTS | measure -Sum).Sum
				$totalFreeSlots=($tsmServer.Libraries.Values.FREE_SLOTS | measure -Sum).Sum
				$totalUsedSlots=($tsmServer.Libraries.Values.USED_SLOTS | measure -Sum).Sum
				$obj | Add-Member -MemberType NoteProperty -Name "Tape Drives/Slots" -Value "$($totalDrives) drives, $($totalSlots) Slots in total ($($totalUsedSlots) Used, $($totalFreeSlots) Free)"
			}

			# Volumes SUMMARY
			$str=""
			if ($tsmserver.Volumes.Count -gt 0)
			{
				# $str="Total of $($tsmserver.Volumes.Count) volumes, $($($tsmserver.Volumes | ?{$_.SCRATCH -eq 'YES'} | measure SCRATCH).Count) scratch"
				$str="$($tsmserver.Volumes.Count) volumes total; "
				$errorsCount=$($($tsmserver.Volumes | ?{$_.READ_ERRORS -gt 0 -or $_.WRITE_ERRORS -gt 0 -or $_.ERROR_STATE -eq 'YES'} | measure).Count)
				$str +="$($($tsmserver.Volumes | ?{$_.READ_ERRORS -gt 0 -or $_.WRITE_ERRORS -gt 0 -or $_.ERROR_STATE -eq 'YES'} | measure).Count) with errors"
				if ($errorsCount)
				{
					$issuesRegister += ",$errorsCount volumes have errors on TSM Server $($tsmserver.Name)"
				}
				$tsmserver.Volumes | group ACCESS | select Name,Count | %{
					if ($_.Count)
					{
						$label=(Get-Culture).TextInfo.ToTitleCase(($_.name -replace "_"," ").ToLower())
						$str +=", $($_.Count) $label"
					}
				}

				$tsmserver.Volumes | group STATUS | select Name,Count | %{
					if ($_.Count)
					{
						$label=(Get-Culture).TextInfo.ToTitleCase(($_.name -replace "_"," ").ToLower())
						$str +=", $($_.Count) $label"
					}
				}
				$obj | Add-Member -MemberType NoteProperty -Name "Storage pool volumes" -Value "$str"
			}

			# Unsuccessful jobs
			$str = ""
			$failedJobs = $tsmServer.Summary | ?{$_.SUCCESSFUL -eq "NO"} | group ACTIVITY #| group ENTITY
			$failedJobs | %{
				if ($_.Name -eq 0)
				{
					$str += "$($_.Count) x Misc Failed Jobs"
				} else {
					$str += ", $($_.Count) x $($_.Name)"
				}
			}

			# $obj | Add-Member -MemberType NoteProperty -Name "Failed Jobs" -Value "$($failedJobs.Count) (" #Failed$str

			$str=""
			$tsmServer.Storage_Pools.STGPOOL_NAME | %{
				$str += ", $_"
			}

            # Pool count
			$obj | Add-Member -MemberType NoteProperty -Name "Storage Pools" -Value "$($tsmServer.Storage_Pools.Count)" # Pools$str

            # Schedule count
			$obj | Add-Member -MemberType NoteProperty -Name "Client Schedules" -Value "$($tsmServer.CSchedules.Count)" # Pools$str
            $obj | Add-Member -MemberType NoteProperty -Name "Admin Schedules" -Value "$($tsmServer.ASchedules.Count)"

            # Add entries for activity log, summary data and event data retention
            $obj | Add-Member -MemberType NoteProperty -Name "Activity Log retention" -Value "$($tsmServer.Status.Actlogretention) days"
            $obj | Add-Member -MemberType NoteProperty -Name "Summary data retention" -Value "$($tsmServer.Status.Summaryretention) days"
            $obj | Add-Member -MemberType NoteProperty -Name "Event data retention"   -Value "$($tsmServer.Status.Eventretention) days"

            # Data totals
			$obj | Add-Member -MemberType NoteProperty -Name "Total amount of backed-up data" -Value "$(formatNumbers -deci 2 -value $(($tsmServer.Auditocc.BACKUP_MB | measure -Sum).Sum/1024)) GB"
			$obj | Add-Member -MemberType NoteProperty -Name "Total amount of backed-up data in copypools" -Value "$(formatNumbers -deci 2 -value $(($tsmServer.Auditocc.BACKUP_COPY_MB | measure -Sum).Sum/1024)) GB"
			$obj | Add-Member -MemberType NoteProperty -Name "Total amount of archived data" -Value "$(formatNumbers -deci 2 -value $(($tsmServer.Auditocc.ARCHIVE_MB | measure -Sum).Sum/1024)) GB"
			$obj | Add-Member -MemberType NoteProperty -Name "Total amount of archived data in copypools" -Value "$(formatNumbers -deci 2 -value $(($tsmServer.Auditocc.ARCHIVE_COPY_MB | measure -Sum).Sum/1024)) GB"
			$obj | Add-Member -MemberType NoteProperty -Name "Total amount of data storage used by the TSM server" "$(formatNumbers -deci 2 -value $(($tsmServer.Auditocc.TOTAL_MB | measure -Sum).Sum/1024)) GB"

			#$obj | Add-Member -MemberType NoteProperty -Name "Total amount of backed-up data" -Value "$([math]::round(($tsmServer.Auditocc.BACKUP_MB | measure -Sum).Sum/1024,2)) GB"
			#$obj | Add-Member -MemberType NoteProperty -Name "Total amount of backed-up data in copypools" -Value "$([math]::round(($tsmServer.Auditocc.BACKUP_COPY_MB | measure -Sum).Sum/1024,2)) GB"
			#$obj | Add-Member -MemberType NoteProperty -Name "Total amount of archived data" -Value "$([math]::round(($tsmServer.Auditocc.ARCHIVE_MB | measure -Sum).Sum/1024,2)) GB"
			#$obj | Add-Member -MemberType NoteProperty -Name "Total amount of archived data in copypools" -Value "$([math]::round(($tsmServer.Auditocc.ARCHIVE_COPY_MB | measure -Sum).Sum/1024,2)) GB"
			#$obj | Add-Member -MemberType NoteProperty -Name "Total amount of data storage used by the TSM server" -Value "$([math]::round(($tsmServer.Auditocc.TOTAL_MB | measure -Sum).Sum/1024,2)) GB"

			$obj
		}

		if ($tableData)
		{
			export -title $tableHeader -dataTable $tableData -displayTableOrientation "List" -headerType "h2" -metaAnalytics "" -showTableCaption "false" -description "Presents a system summary of all TSM Servers assessed as part of this report."
		}
	}


	#########################
	# DATABASE & LOG
	#
	$showDBLogsReport=$true
	if($showDBLogsReport)
	{
		setSectionHeader -type "h1" -title "Database and Log"

		$tableHeader="Overview"
		logThis -msg "Processing $tableHeader Report"
		#$delimiter="," # ',' | '\t' To use to split strings into fields, used in this powershell script - not used when making TSM queries
		$tableData = $tsmServers | %{
			$tsmServer=$_
			$obj = New-Object System.Object
			#$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value "$($tsmServer.Name)"
			if ($tsmservers.Name.Count -gt 1) {$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value "$($tsmServer.Name)"}

			# Database
			$dbTotalFSGB=[Math]::Round([double]$tsmServer.Database.TOT_FILE_SYSTEM_MB / 1024,2)
			$dbUsedSpaceGB=[Math]::Round([double]$tsmServer.Database.USED_DB_SPACE_MB / 1024,2)
			#$dbUsedSpacePerc=[Math]::Round([double]$tsmServer.Database.USED_DB_SPACE_MB / [double]$tsmServer.Database.TOT_FILE_SYSTEM_MB * 100,2)
			$dbUsedSpacePerc=[double]$tsmServer.Database.USED_DB_SPACE_MB / [double]$tsmServer.Database.TOT_FILE_SYSTEM_MB
			if ($dbUsedSpacePerc -gt 85)
			{
            	$dbHealth="Critical!"
			} else {
            	$dbHealth="Good"
            }
			$obj | Add-Member -MemberType NoteProperty -Name "DB Filesystem size" -Value "$(formatNumbers -deci 2 -value $dbUsedSpaceGB) GB"
			$obj | Add-Member -MemberType NoteProperty -Name "DB Filesystem usage" -Value "$(formatNumbers -deci 2 -value $dbUsedSpacePerc -unit 'P')"
			$obj | Add-Member -MemberType NoteProperty -Name "Filesystem warning threshold" -Value "$(formatNumbers -deci 2 -value $($($tsmServer.Options | ?{$_.OPTION_NAME -eq 'FSUSEDTHRESHOLD'}).OPTION_VALUE)) %"
			$obj | Add-Member -MemberType NoteProperty -Name "DB Health" -Value $dbHealth

			# Logs
			#$logsTotalSizeGB= [Math]::Round(([double]$tsmServer.Logs.TOTAL_SPACE_MB + [double]$tsmServer.Logs.ARCHLOG_TOL_FS_MB + [double]$tsmServer.Logs.MIRLOG_TOL_FS_MB + [double]$tsmServer.Logs.AFAILOVER_TOL_FS_MB) / 1024,2)
			#$logsTotalUsedGB= [Math]::Round(([double]$tsmServer.Logs.USED_SPACE_MB + [double]$tsmServer.Logs.ARCHLOG_USED_FS_MB + [double]$tsmServer.Logs.MIRLOG_USED_FS_MB + [double]$tsmServer.Logs.AFAILOVER_USED_FS_MB) / 1024,2)
			$logsTotalSizeGB= [Math]::Round([double]$tsmServer.Logs.TOTAL_SPACE_MB / 1024,2)
			$logsTotalUsedGB= [Math]::Round([double]$tsmServer.Logs.USED_SPACE_MB / 1024,2)
			$logsUsedSpacePerc=[Math]::Round([double]$logsTotalUsedGB / [double]$logsTotalSizeGB,2)
			if ($logsUsedSpacePerc -gt 85)
            {
            	$logsHealth="Critical!"
            } else {
				$logsHealth="Good"
            }
			$obj | Add-Member -MemberType NoteProperty -Name "Log filesystem size" -Value "$(formatNumbers -deci 2 -value $logsTotalSizeGB) GB"
			$obj | Add-Member -MemberType NoteProperty -Name "Log filesystem usage" -Value "$(formatNumbers -deci 2 -value $logsUsedSpacePerc -unit P)"
			$obj | Add-Member -MemberType NoteProperty -Name "Archive log threshold" -Value "$(($tsmServer.Options | ?{$_.OPTION_NAME -eq 'ARCHLOGUSEDTHRESHOLD'}).OPTION_VALUE) %"
			$obj | Add-Member -MemberType NoteProperty -Name "Log health" -Value $logsHealth

			$obj
		}

		if ($tableData)
		{
			export -title $tableHeader -dataTable $tableData -displayTableOrientation "List" -headerType "h2" -metaAnalytics "" -showTableCaption "false" -description "The condition of the TSM database and log is detailed below. TSM is configured to automatically run a database backup and clear the archived logs at $(($tsmServer.Options | ?{$_.OPTION_NAME -eq 'ARCHLOGUSEDTHRESHOLD'}).OPTION_VALUE) % usage."
		}

		############################################################################################################
		# SHOW DATBASE DETAILS
		#
		$tableHeader="Database details"
		logThis -msg "Processing $tableHeader Report"
		$tableData = $tsmServers | %{
			$tsmServer = $_
			$obj = New-Object System.Object
			#$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value $tsmServer.Name
			if ($tsmservers.Name.Count -gt 1) {$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value "$($tsmServer.Name)"}
			$obj | Add-Member -MemberType NoteProperty -Name "Total filesystem space" -Value "$(formatNumbers -deci 2 -value $([double]$tsmServer.Database.TOT_FILE_SYSTEM_MB/1024)) GB"
			$obj | Add-Member -MemberType NoteProperty -Name "Used DB" -Value "$(formatNumbers -deci 2 -value $([double]$tsmServer.Database.USED_DB_SPACE_MB/1024)) GB"
			$obj | Add-Member -MemberType NoteProperty -Name "Free space" -Value "$(formatNumbers -deci 2 -value $([double]$tsmServer.Database.FREE_SPACE_MB/1024)) GB"
			$obj | Add-Member -MemberType NoteProperty -Name "Used" -Value "$([Math]::Round(([double]$tsmServer.Database.USED_DB_SPACE_MB / [double]$tsmServer.Database.TOT_FILE_SYSTEM_MB)*100,2)) %"
			$obj | Add-Member -MemberType NoteProperty -Name "Buffer hit ratio" -Value "$($tsmserver.Database.BUFF_HIT_RATIO) %"
			$obj | Add-Member -MemberType NoteProperty -Name "Last backup" -Value $(get-date $tsmServer.Database.LAST_BACKUP_DATE -Format "dddd, dd MMM yyyy, HH:mm:ss")
			$obj | Add-Member -MemberType NoteProperty -Name "Last reorg" -Value $(get-date $tsmServer.Database.LAST_REORG -Format "dddd, dd MMM yyyy, HH:mm:ss")
			$dbFullBackups=$tsmServer.Summary | ?{$_.ACTIVITY -eq "FULL_DBBACKUP" -and $_.SUCCESSFUL -eq "YES"}
			if($dbFullBackups)
			{
				$diffTimeFull  = ($dbFullBackups | select START_TIME,END_TIME | %{((Get-Date $_.END_TIME) - (Get-Date $_.START_TIME)).TotalSeconds} | measure -Average).Average
				$avgGBFull  =$([Math]::Round([double](($dbFullBackups).BYTES | Measure -Average).Average/1024/1024/1024,2))
				$timeTaken = New-TimeSpan -Seconds $diffTimeFull
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
				$obj | Add-Member -MemberType NoteProperty -Name "Average time for full database backup" -Value $timeTakenStr
				$obj | Add-Member -MemberType NoteProperty -Name "Average size of full database backup" -Value "$(formatNumbers -deci 2 -value $avgGBFull) GB"
			} else
			{
				#$obj | Add-Member -MemberType NoteProperty -Name "Full Database Backups" -Value "None"
			}

			$incrementalDBBackups = $tsmServer.Summary | ?{$_.ACTIVITY -eq "INCR_DBBACKUP" -and $_.SUCCESSFUL -eq "YES"}
			if ($incrementalDBBackups)
			{
				$diffTimeIncr  = ($incrementalDBBackups | select START_TIME,END_TIME | %{((Get-Date $_.END_TIME) - (Get-Date $_.START_TIME)).TotalSeconds} | measure -Average).Average
				$avgGBIncrGB  = formatNumbers -deci 2 -value $([Math]::Round([double](($incrementalDBBackups).BYTES | Measure -Average).Average/1024/1024/1024,2))
				$timeTakenIncr = New-TimeSpan -Seconds $diffTimeIncr
				$timeTakenIncrStr=""
				if ($timeTakenIncr.Days -gt 0)
				{
					$timeTakenIncrStr += "$($timeTakenIncr.days) days "
				}
				if ($timeTakenIncr.Hours -gt 0)
				{
					$timeTakenIncrStr += "$($timeTakenIncr.Hours) hrs "
				}
				if ($timeTakenIncr.Minutes -gt 0)
				{
					$timeTakenIncrStr += "$($timeTakenIncr.Minutes) min "
				}
				if ($timeTakenIncr.Seconds -gt 0)
				{
					$timeTakenStr += "$($timeTakenIncr.Seconds) sec "
				}
				$obj | Add-Member -MemberType NoteProperty -Name "Average time for incremental database backup" -Value $timeTakenIncrStr
				$obj | Add-Member -MemberType NoteProperty -Name "Average size of incremental database backup" -Value "$(formatNumbers -deci 2 -value $avgGBIncrGB) GB"
			} else {
				#$obj | Add-Member -MemberType NoteProperty -Name "Incremental Database Backups" -Value "None"
			}
			$obj
		}
		if ($tableData)
		{
			export -title $tableHeader -dataTable $tableData -displayTableOrientation "List" -headerType "h2" -metaAnalytics "" -showTableCaption "false" -description ""
		}

		############################################################################################################
		#
		# LOGS (COPY THIS ONE AS A TEMPLATE)
		#
		$tableHeader="Recovery log details"
		logThis -msg "Processing $tableHeader Report"
		$tableData = $tsmServers | %{
			$tsmServer = $_
			$obj = New-Object System.Object
			#$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value $tsmserver.Name
			if ($tsmservers.Name.Count -gt 1) {$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value "$($tsmServer.Name)"}
			#($tsmServer.Logs | Get-Member -MemberType NoteProperty).Name | %{
			$obj | Add-Member -MemberType NoteProperty -Name "Active log directory" -Value $tsmServer.Logs.ACTIVE_LOG_DIR
			$obj | Add-Member -MemberType NoteProperty -Name "Active log total space " -Value "$(formatNumbers -deci 2 -value $([double]$($tsmServer.Logs.TOTAL_SPACE_MB)/1024)) GB"
			$obj | Add-Member -MemberType NoteProperty -Name "Active log used space" -Value  "$(formatNumbers -deci 2 -value $([double]$($tsmServer.Logs.USED_SPACE_MB)/1024)) GB"
			$obj | Add-Member -MemberType NoteProperty -Name "Active log free space" -Value "$(formatNumbers -deci 2 -value $([double]$($tsmServer.Logs.FREE_SPACE_MB)/1024)) GB"
			$obj | Add-Member -MemberType NoteProperty -Name "Archive log directory" -Value $tsmServer.Logs.ARCH_LOG_DIR
			$obj | Add-Member -MemberType NoteProperty -Name "Archive log filesystem size" -Value "$(formatNumbers -deci 2 -value $([double]$($tsmServer.Logs.ARCHLOG_TOL_FS_MB)/1024)) GB"
			$obj | Add-Member -MemberType NoteProperty -Name "Archive log filesystem used" -Value "$(formatNumbers -deci 2 -value $([double]$($tsmServer.Logs.ARCHLOG_USED_FS_MB)/1024)) GB"
			$obj | Add-Member -MemberType NoteProperty -Name "Archive log filesystem free" -Value "$(formatNumbers -deci 2 -value $([double]$($tsmServer.Logs.ARCHLOG_FREE_FS_MB)/1024)) GB"
			$obj | Add-Member -MemberType NoteProperty -Name "Archive log compressed?" -Value $tsmServer.Logs.ARCH_LOG_COMPRESSED

			# Archive log failover location - not always set
			if ($tsmServer.Logs.AFAILOVER_LOG_DIR -eq 0)
			{
				$note = "Not configured"
			    $obj | Add-Member -MemberType NoteProperty -Name "Archive log failover directory" -Value $note
			    $obj | Add-Member -MemberType NoteProperty -Name "Archive log failover filesystem size" -Value "N/A"
			    $obj | Add-Member -MemberType NoteProperty -Name "Archive log failover filesystem used" -Value "N/A"
			    $obj | Add-Member -MemberType NoteProperty -Name "Archive log failover filesystem free" -Value "N/A"
			} else {
				$note = $tsmServer.Logs.AFAILOVER_LOG_DIR
			    $obj | Add-Member -MemberType NoteProperty -Name "Archive log failover directory" -Value $note
			    $obj | Add-Member -MemberType NoteProperty -Name "Archive log failover filesystem size" -Value "$(formatNumbers -deci 2 -value $([double]$($tsmServer.Logs.AFAILOVER_TOL_FS_MB)/1024)) GB"
			    $obj | Add-Member -MemberType NoteProperty -Name "Archive log failover filesystem used" -Value "$(formatNumbers -deci 2 -value $([double]$($tsmServer.Logs.AFAILOVER_USED_FS_MB)/1024)) GB"
			    $obj | Add-Member -MemberType NoteProperty -Name "Archive log failover filesystem free" -Value "$(formatNumbers -deci 2 -value $([double]$($tsmServer.Logs.AFAILOVER_FREE_FS_MB)/1024)) GB"
			}

            # Mirror log location - not always set
            if ($tsmServer.Logs.MIRROR_LOG_DIR -eq 0)
			{
				$note = "Not configured"
			    $obj | Add-Member -MemberType NoteProperty -Name "Mirror log directory" -Value $note
			    $obj | Add-Member -MemberType NoteProperty -Name "Mirror log filesystem size" -Value "N/A"
			    $obj | Add-Member -MemberType NoteProperty -Name "Mirror log filesystem used" -Value "N/A"
			    $obj | Add-Member -MemberType NoteProperty -Name "Mirror log filesystem free" -Value "N/A"

			} else {
				$note = $tsmServer.Logs.MIRROR_LOG_DIR
			    $obj | Add-Member -MemberType NoteProperty -Name "Mirror log directory" -Value $note
			    $obj | Add-Member -MemberType NoteProperty -Name "Mirror log filesystem size" -Value "$(formatNumbers -deci 2 -value $([double]$($tsmServer.Logs.MIRLOG_TOL_FS_MB)/1024)) GB"
			    $obj | Add-Member -MemberType NoteProperty -Name "Mirror log filesystem used" -Value "$(formatNumbers -deci 2 -value $([double]$($tsmServer.Logs.MIRLOG_USED_FS_MB)/1024)) GB"
			    $obj | Add-Member -MemberType NoteProperty -Name "Mirror log filesystem free" -Value "$(formatNumbers -deci 2 -value $([double]$($tsmServer.Logs.MIRLOG_FREE_FS_MB)/1024)) GB"
			}
            $obj
		}
		if ($tableData)
		{
			export -title $tableHeader -dataTable $tableData -displayTableOrientation "List" -headerType "h2" -metaAnalytics "" -showTableCaption "false" -description ""
		}


		############################################################################################################
		#
		$tableHeader="Database Spaces"
		logThis -msg "Processing $tableHeader Report"
		$tableData = $tsmServers | %{
			$tsmServer = $_
			$uniqueDriveLetters=$tsmServer.DBspace | %{ $driveLetter,$therest=$_.LOCATION -split '\\'; $driveLetter} | sort -Unique
			$uniqueDriveLetters | %{
				$driveLetter=$_
				$dbspace = $tsmServer.DBspace | ?{$_.LOCATION.Contains("$driveLetter\")} | Select -First 1
				$obj = New-Object System.Object
				#$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value $tsmserver.Name
				if ($tsmservers.Name.Count -gt 1) {$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value "$($tsmServer.Name)"}
				$obj | Add-Member -MemberType NoteProperty -Name "Volume" -Value "$driveLetter\"
				$obj | Add-Member -MemberType NoteProperty -Name "Size" -Value "$(formatNumbers -deci 2 -value $([double]$dbspace.TOTAL_FS_SIZE_MB / 1024)) GB"
				$obj | Add-Member -MemberType NoteProperty -Name "Used" -Value "$(formatNumbers -deci 2 -value $([double]$dbspace.USED_FS_SIZE_MB / 1024)) GB"
				$obj
			}
		}
		if ($tableData)
		{
			export -title $tableHeader -dataTable $tableData -displayTableOrientation "List" -headerType "h2" -metaAnalytics "" -showTableCaption "false" -description ""
		}
	}

	#########################
	# DEVICES SECTION
	#
	$showDevicesReport=$true
	if ($tsmServers.Libraries.Count -gt 0 -and $showDevicesReport)
	{
		$showDevicesReport=$true
	} else {
		$showDevicesReport=$false
	}
	if ($showDevicesReport)
	{
		setSectionHeader -type "h1" -title "Devices"

		# SHOW LIBRARY DETAILS
		$tableHeader="Libraries"
		logThis -msg "Processing $tableHeader Report"
		$tableData = $tsmServers | %{
			$tsmserver=$_
			$tsmserver.Libraries.Values | %{
				$library = $_
				$obj = New-Object System.Object
				if ($tsmservers.Name.Count -gt 1) {$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value "$($tsmServer.Name)"}
				#$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value $tsmserver.Name
				$obj | Add-Member -MemberType NoteProperty -Name "Name" -Value $library.LIBRARY_NAME
				$obj | Add-Member -MemberType NoteProperty -Name "Product ID" -Value $library.ProductID
				$obj | Add-Member -MemberType NoteProperty -Name "Drives" -Value $library.Drives
				$obj | Add-Member -MemberType NoteProperty -Name "Changers" -Value "$($library.Changers) ($($library.Device))"
                $obj | Add-Member -MemberType NoteProperty -Name "I/O Slots" -Value $library."Import/Exports"
				$obj | Add-Member -MemberType NoteProperty -Name "Used slots" -Value $library.Used_Slots
				$obj | Add-Member -MemberType NoteProperty -Name "Free slots" -Value $library.Free_Slots

				$obj | Add-Member -MemberType NoteProperty -Name "Total slots" -Value $library.Slots
				$library.Libvolumes | group STATUS | select Name,Count | %{
					$obj | Add-Member -MemberType NoteProperty -Name "$($_.Name) Tapes" -Value $_.Count
				}
				$obj
			}
		}
		if ($tableData)
		{
			export -title $tableHeader -dataTable $tableData -displayTableOrientation "List" -headerType "h2" -metaAnalytics "" -showTableCaption "false" -description ""
		}


		# SHOW LIB VOLUMES DETAILS
		#$tableHeader="Tapes Devices"
		#logThis -msg "Processing $tableHeader Report"
		#$tableData = $tsmServers | %{
			#$tsmserver=$_
			#$tsmserver.Libraries.Values | %{
				#$library = $_
				#$library.Libvolumes | %{
					#$tape = $_
					#$obj = New-Object System.Object
					#$obj | Add-Member -MemberType NoteProperty -Name "Tape" -Value $tape.VOLUME_NAME
					#$obj | Add-Member -MemberType NoteProperty -Name "Status" -Value $tape.STATUS
					#$obj | Add-Member -MemberType NoteProperty -Name "Library" -Value $library.LIBRARY_NAME
					##$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value $tsmserver.Name
					#if ($tsmservers.Name.Count -gt 1) {$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value "$($tsmServer.Name)"}
					#$obj
				#}
			#}
		#}
		#if ($tableData)
		#{
			#export -title $tableHeader -dataTable $tableData -displayTableOrientation "Table" -headerType "h2" -metaAnalytics "" -showTableCaption "false" -description ""
		#}

	}

	############################################################################################################
	# Disaster Recovery
	$showDRPLanst=$true
	if ($showDRPLanst)
	{
		setSectionHeader -type "h1" -title "Disaster Recovery"
		$tableData = $tsmServers | %{
			$tsmServer=$_
			if ($tsmServer.DRMStatus)
			{
				# Show DR plans
				$tableHeader="Disaster Recovery Manager"
				logThis -msg "Processing $tableHeader Report"
				$obj = New-Object System.Object
				#$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value $tsmServer.Name
				if ($tsmservers.Name.Count -gt 1) {$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value "$($tsmServer.Name)"}
				if ($tsmServer.DRMStatus.PLANPREFIX -eq "0")
				{
					$obj | Add-Member -MemberType NoteProperty -Name "DR plan files location" -Value "Not configured"
				} else {
					$obj | Add-Member -MemberType NoteProperty -Name "DR plan files location" -Value $tsmServer.DRMStatus.PLANPREFIX
				}
				if ($tsmServer.DRMStatus.INSTRPREFIX -eq "0")
				{
					$obj | Add-Member -MemberType NoteProperty -Name "DR plan instructions location" -Value "Not configured"
				} else {
					$obj | Add-Member -MemberType NoteProperty -Name "DR plan instructions location" -Value $tsmServer.DRMStatus.INSTRPREFIX
				}

                $obj | Add-Member -MemberType NoteProperty -Name "Offsite vault name" -Value $tsmServer.DRMStatus.VAULTNAME
                $obj | Add-Member -MemberType NoteProperty -Name "DB backup series expiry (days)" -Value $tsmServer.DRMStatus.DBBEXPIREDAYS
                $obj | Add-Member -MemberType NoteProperty -Name "Check tape labels on eject?" -Value $tsmServer.DRMStatus.CHECKLABEL
                $obj | Add-Member -MemberType NoteProperty -Name "Process FILE-based volumes?" -Value $tsmServer.DRMStatus.FILEPROCESS

                $tsmServer.DRMMedia | group STATE | Select Name,Count | %{
					$obj | Add-Member -MemberType NoteProperty -Name "$($_.Name) DR Media" -Value $_.Count
				}
				$obj | Add-Member -MemberType NoteProperty -Name "Total DR Media" -Value $tsmServer.DRMMedia.Count
				$obj
			}
		}
		if ($tableData)
		{
			export -title $tableHeader -dataTable $tableData -displayTableOrientation "List" -headerType "h2" -metaAnalytics "" -showTableCaption "false" -description ""
		}
	}




	############################################################################################################
	# SHOW ENVIRONMENT ACTIVITY SECTION
	#
	$showActivityReports=$true
	if ($showActivityReports)
	{
		setSectionHeader -type "h1" -title "Activity Summary"

		# SHOW ACTIVITY SUMMARY
		#$tableData = $tsmServers | %{
		#	$tsmserver=$_
			##$failedJobs = $tsmServer.Summary | ?{$_.SUCCESSFUL -eq "NO"} | group ACTIVITY | sort count -Descending | Select Count,Name
			#$tableHeader="Activities Summary"
			#logThis -msg "Processing $tableHeader Report for server $($tsmserver.name)"
			#$tableData = $tsmServer.Summary | group ACTIVITY | sort Count -Descending | %{
				#$activity=$_
				#$obj = New-Object System.Object
				#$obj | Add-Member -MemberType NoteProperty -Name "Activity" -Value $((Get-Culture).TextInfo.ToTitleCase(($activity.Name -replace "_"," " -replace "DB","Database ").ToLower()))
				#$obj | Add-Member -MemberType NoteProperty -Name "Count" -Value $activity.Count
				#$obj | Add-Member -MemberType NoteProperty -Name "Amount (MB)" -Value $(formatNumbers -deci 2 -value $([Math]::Round([double]($activity.Group.BYTES | measure -Sum).Sum/1024/1024,2)))
				#$obj
			#}
			#if ($tableData)
			#{
				#export -title $tableHeader -dataTable $tableData -displayTableOrientation "Table" -headerType "h2" -metaAnalytics "" -showTableCaption "false" -description ""
			#}
		#}

		############################################################################################################
		# SHOW FAILING JOBS
		$tableHeader="Failing Jobs"
		logThis -msg "Processing $tableHeader Report"
		$tableData = $tsmServers | %{
			$tsmserver=$_
			$obj = New-Object System.Object
			if ($tsmservers.Name.Count -gt 1) {$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value "$($tsmServer.Name)"}
			$activities=$tsmserver.Summary | ?{$_.SUCCESSFUL -eq "NO"} | group ACTIVITY | Sort Count -Descending | select Name,Count
			$activities | %{
				$activityName=$_.Name
				$label=(Get-Culture).TextInfo.ToTitleCase(($activityName -replace "_"," " -replace "DB","Database ").ToLower())
				#Write-Host "$($_.Name)"
				#$obj | Add-Member -MemberType NoteProperty -Name "Activity" -Value "$($label)s"
				#$obj | Add-Member -MemberType NoteProperty -Name "Count" -Value $(formatNumbers -value $_.Count)

				$totalCount=($tsmserver.Summary | ?{$_.ACTIVITY -eq $activityName }).Count
				if ($totalCount)
				{
					$perc="{0:P2}" -f $($_.Count/$totalCount)
				} else {
					$perc="100 %"
				}
				#$obj | Add-Member -MemberType NoteProperty -Name "Failure Rate" -Value $perc
				$obj | Add-Member -MemberType NoteProperty -Name "$($label)s" -Value "$(formatNumbers -value $_.Count) of $($totalCount) ($perc of $($label)s)"
				#$obj | Add-Member -MemberType NoteProperty -Name "$($label)s" -Value $(formatNumbers -value $_.Count)

			}
			$obj

		}
		if ($tableData)
		{
			$analytics=""
			#if ($tableData.Backups -gt
			#$analytics=" Note that $($tableData.Backups.Count) are failing. "
			export -title $tableHeader -dataTable $tableData -displayTableOrientation "List" -headerType "h2" -metaAnalytics $analytics -showTableCaption "false" -description "Table XXX below provides a summary of failing jobs for the preceding month. "
		}
	}

    # Show event status
	$tableHeader="Event completion summary"
	logThis -msg "Processing $tableHeader Report"
    # select @{Name="Version";Expression={$_."Name"}},Count
	$tableData = $tsmservers.Event_stat | select @{Name="Status";Expression={$_."STATUS"}},@{Name="Count";Expression={$_."Num"}} | %{
		$row=$_
		$row
	}
	if ($tableData)
	{
		export -title $tableHeader -dataTable $tableData -displayTableOrientation "Table" -headerType "h2" -metaAnalytics "" -showTableCaption "false" -description ""
	}

    ############################################################################################################
	# TSM Client/Nodes
	#
	$showTSMClientsReport=$true
	if ($showTSMClientsReport)
	{
		setSectionHeader -type "h1" -title "TSM Clients"

		# SHOW ALL CLIENT DETAILS - TABLE 1
		$tableHeader="TSM Client Details"
		logThis -msg "Processing $tableHeader Report"
		$tableData = $tsmServers | %{
			$tsmServer=$_
			$tsmServer.Clients | sort NODE_NAME | %{
				$tsmclient=$_
				$node_name=$_.Node_name;
				$obj = New-Object System.Object
				$obj | Add-Member -MemberType NoteProperty -Name "Node name" -Value $tsmclient.Node_name
				$obj | Add-Member -MemberType NoteProperty -Name "OS" -Value $($tsmclient.CLIENT_OS_NAME -replace "WIN:","")
				$obj | Add-Member -MemberType NoteProperty -Name "OS Level" -Value $tsmclient.CLIENT_OS_LEVEL
				if ($tsmclient.PLATFORM_NAME.Contains("TDP"))
				{
					$tdpClient=$tsmclient.PLATFORM_NAME
				} else
				{
					$tdpClient=""
				}
				$obj | Add-Member -MemberType NoteProperty -Name "TDP Agent" -Value $tdpClient
				$obj | Add-Member -MemberType NoteProperty -Name "TSM client version" -Value "$($tsmclient.CLIENT_VERSION).$($tsmclient.CLIENT_RELEASE).$($tsmclient.CLIENT_LEVEL).$($tsmclient.CLIENT_SUBLEVEL)" #$($tsmclient.PLATFORM_NAME) ()
				$obj | Add-Member -MemberType NoteProperty -Name "Days since last logon" -Value "$(($(get-date) - $(get-date $tsmclient.LASTACC_TIME)).Days)"
				$obj | Add-Member -MemberType NoteProperty -Name "Date of last logon" -Value "$(Get-date $($tsmclient.LASTACC_TIME) -format 'dd-MM-yyyy')"
				#$num="-"

				$num=[double](($tsmServer.Occupancy | ?{$_.NODE_NAME -eq $tsmclient.Node_name}) | measure NUM_FILES -sum).Sum
				if (!$num)
				{
					$num = 0
				}
				$obj | Add-Member -MemberType NoteProperty -Name "Total files stored" -Value "$(formatNumbers -value $num)"
				$sizeGB=([double](($tsmServer.Occupancy | ?{$_.NODE_NAME -eq $tsmclient.Node_name}) | measure LOGICAL_MB -sum).Sum/1024)
				if (!$sizeGB)
				{
					$sizeGB = 0
				}

				$obj | Add-Member -MemberType NoteProperty -Name "Total data stored (GB)" -Value "$(formatNumbers -deci 2 -value $sizeGB)"
				#$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value $tsmServer.NAME
				if ($tsmservers.Name.Count -gt 1) {$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value "$($tsmServer.Name)"}
				$obj
			}
		}
		if ($tableData)
		{
			export -title $tableHeader -dataTable $tableData -displayTableOrientation "Table" -headerType "h2" -metaAnalytics "" -showTableCaption "false" -description ""
		}


		# SHOW ALL CLIENT DETAILS - TABLE 2
		$tableHeader="TSM Client Backups"
		logThis -msg "Processing $tableHeader Report"
		# SHOW ALL CLIENT DETAILS
		$index=1
		$totalClients=$tsmServers.Clients.Count
		$tableData = $tsmServers | %{
			$tsmServer=$_
			#$tableHeader="Nodes on $($tsmServer.Name)"
			#logThis -msg "Processing $tableHeader Report"
			$tsmServer.Clients | sort NODE_NAME | %{
				$tsmclient=$_
				$node_name=$_.Node_name;
				Write-Progress -Activity "Creating $tableHeader Report" -status " $index/$totalClients :- Processing node $($node_name) - $([math]::round($index/$totalClients*100,2)) %" -percentComplete $($index/$totalClients*100)
				$obj = New-Object System.Object
				$obj | Add-Member -MemberType NoteProperty -Name "Node Name" -Value $node_name
				$obj | Add-Member -MemberType NoteProperty -Name "Date of last Logon" -Value "$(Get-date $($tsmclient.LASTACC_TIME) -format 'dd-MM-yyyy')"

				# Get the last backup
				$totalGB=[math]::round([double]($tsmServer.Summary | ?{$_.SUCCESSFUL -eq "Yes" -and $_.ACTIVITY -eq "BACKUP" -and $_.ENTITY -eq $node_name -and  !$_.ENTITY.Contains("($node_name)")} | sort START_TIME | Select -Last 1).BYTES/1024/1024/1024 ,2)
				$obj | Add-Member -MemberType NoteProperty -Name "Size of last backup (GB)" -Value "$(formatNumbers -deci 2 -value $totalGB)"

				# Get Amount of data backed up over the following days - comma delimited
				7,30 | %{
					$lastDays=$_
					$today=Get-Date
					$startDate=(Get-Date $today).AddDays(-$lastDays)
					#$allBackups = $tsmServer.Summary | ?{$_.SUCCESSFUL -eq "Yes" -and $_.ACTIVITY -eq "BACKUP" -and $_.ENTITY -eq $tsmclient.Node_Name  -and ($startDate -le (get-date $_.START_TIME))}
					#$allBackups = $tsmServer.Summary | ?{$_.SUCCESSFUL -eq "Yes" -and $_.ACTIVITY -eq "BACKUP" -and $_.ENTITY.Contains($node_name) -and  !$_.ENTITY.Contains("($node_name)") -and ($startDate -le $(get-date $_.START_TIME))}
					$totalGB=[math]::round([double]($tsmServer.Summary | ?{$_.SUCCESSFUL -eq "Yes" -and $_.ACTIVITY -eq "BACKUP" -and $_.ENTITY -eq $node_name -and  !$_.ENTITY.Contains("($node_name)") -and ($startDate -le $(get-date $_.START_TIME))} | measure BYTES -Sum).Sum / 1024 / 1024 / 1024,2)
					$obj | Add-Member -MemberType NoteProperty -Name "Data backed up in last $lastDays days (GB)" -Value "$(formatNumbers -deci 2 -value $totalGB)"
				}
				#$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value $tsmServer.NAME
				if ($tsmservers.Name.Count -gt 1) {$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value "$($tsmServer.Name)"}
				$obj
				$index++
			}

		}
		if ($tableData)
		{
			export -title $tableHeader -dataTable $tableData -displayTableOrientation "Table" -headerType "h2" -metaAnalytics "" -showTableCaption "false" -description ""
		}

		# SHOW PROXUP BACKUPS CLIENT DETAILS - TABLE 2
		$tableHeader="Proxy Backups"
		logThis -msg "Processing $tableHeader Report"
		# SHOW ALL CLIENT DETAILS
		$tableData = $tsmServers | %{
			$tsmServer=$_
			$proxyBackups=$($tsmServer.Summary | ?{($_.ENTITY.Contains("(") -and $_.ENTITY.Contains(")")) -and $_.SUCCESSFUL -eq "Yes" -and ($_.ACTIVITY -eq "BACKUP" -or $_.ACTIVITY -eq 'ARCHIVE')} | select ENTITY -Unique).ENTITY
			$proxyBackups | %{
				$node_name=$_;
				$obj = New-Object System.Object
				$obj | Add-Member -MemberType NoteProperty -Name "Entity" -Value $node_name
				# Get the last backup
				$totalGB=[math]::round([double]($tsmServer.Summary | ?{$_.SUCCESSFUL -eq "Yes" -and $_.ACTIVITY -eq "BACKUP" -and $_.ENTITY -eq $node_name -and  !$_.ENTITY.Contains("($node_name)")} | sort START_TIME | Select -Last 1).BYTES / 1024 / 1024 / 1024,2)
				$obj | Add-Member -MemberType NoteProperty -Name "Size of last backup (GB)" -Value "$(formatNumbers -deci 2 -value $totalGB)"

				# Get Amount of data backed up over the following days - comma delimited
				7,30 | %{
					$lastDays=$_
					$today=Get-Date
					$startDate=(Get-Date $today).AddDays(-$lastDays)
					#$allBackups = $tsmServer.Summary | ?{$_.SUCCESSFUL -eq "Yes" -and $_.ACTIVITY -eq "BACKUP" -and $_.ENTITY -eq $tsmclient.Node_Name  -and ($startDate -le (get-date $_.START_TIME))}
					#$allBackups = $tsmServer.Summary | ?{$_.SUCCESSFUL -eq "Yes" -and $_.ACTIVITY -eq "BACKUP" -and $_.ENTITY.Contains($node_name) -and  !$_.ENTITY.Contains("($node_name)") -and ($startDate -le $(get-date $_.START_TIME))}
					$totalGB=[math]::round([double]($tsmServer.Summary | ?{$_.SUCCESSFUL -eq "Yes" -and $_.ACTIVITY -eq "BACKUP" -and $_.ENTITY -eq $node_name -and  !$_.ENTITY.Contains("($node_name)") -and ($startDate -le $(get-date $_.START_TIME))} | measure BYTES -Sum).Sum / 1024 / 1024 / 1024,2)
					$obj | Add-Member -MemberType NoteProperty -Name "Data backed up in last $lastDays days (GB)" -Value "$(formatNumbers -deci 2 -value $totalGB)"
				}
				#$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value $tsmServer.NAME
				if ($tsmservers.Name.Count -gt 1) {$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value "$($tsmServer.Name)"}
				$obj
			}

		}
		if ($tableData)
		{
			export -title $tableHeader -dataTable $tableData -displayTableOrientation "Table" -headerType "h2" -metaAnalytics "" -showTableCaption "false" -description ""
		}


		# Show summary of "Nodes by Client Type Version 1
		$tableHeader="Nodes by Client Type"
		logThis -msg "Processing $tableHeader Report"
		#$tableData = $tsmServers.Clients | select NODE_NAME,CLIENT_OS_NAME | group CLIENT_OS_NAME | sort Count -Descending | select Name,Count
		$tableClient=$tsmServers | %{
			$tsmserver=$_
			$tsmserver.Clients | %{
				$tsmclient=$_
				$obj = New-Object System.Object
				$obj | Add-Member -MemberType NoteProperty -Name "Node Name" -Value $tsmclient.NODE_NAME
				if ($tsmclient.PROXY_AGENT -ne "0")
				{
					$platform_name=$tsmclient.PLATFORM_NAME
					#$exists=$tsmserver.License_Details | ?{$_.NODE_NAME -eq $tsmclient.NODE_NAME}
					$specialAgent=($tsmserver.License_Details | ?{$_.NODE_NAME -eq $tsmclient.NODE_NAME -and $_.LICENSE_NAME -ne "MGSYSLAN" -and $_.LICENSE_NAME -ne "MGSYSSAN"}).LICENSE_NAME
					if (!$specialAgent)
					{
						if ($platform_name.Contains("TDP"))
						{
							$obj | Add-Member -MemberType NoteProperty -Name "Agent Type" -Value "$($platform_name)"
						} else {
							$obj | Add-Member -MemberType NoteProperty -Name "Agent Type" -Value $tsmclient.CLIENT_OS_NAME
						}
					} else {
						if ($specialAgent.Contains("MSSQL"))
						{
							$newname="TDP for MS SQL"
						} elseif ($specialAgent.Contains("MSEXCH"))
						{
							$newname="TDP for Exchange"
						} else
						{
							$newname=$specialAgent
						}
						$obj | Add-Member -MemberType NoteProperty -Name "Agent Type" -Value  $($newname -replace "WIN:","")
					}

				} else {
					$obj | Add-Member -MemberType NoteProperty -Name "Agent Type" -Value $tsmclient.CLIENT_OS_NAME
				}
				$obj | Add-Member -MemberType NoteProperty -Name "CPU Count" -Value "$(formatNumbers -value $($tsmclient.PCOUNT))"

				$num=[double](($tsmServer.Occupancy | ?{$_.NODE_NAME -eq $tsmclient.Node_name}) | measure NUM_FILES -sum).Sum
				if (!$num)
				{
					$num = 0
				}
				$obj | Add-Member -MemberType NoteProperty -Name "File Count" -Value "$(formatNumbers -value $num)"

				$sizeGB=([double](($tsmServer.Occupancy | ?{$_.NODE_NAME -eq $tsmclient.Node_name}) | measure LOGICAL_MB -sum).Sum/1024)
				if (!$sizeGB)
				{
					$sizeGB = 0
				}
				$obj | Add-Member -MemberType NoteProperty -Name "Total data stored (GB)" -Value "$(formatNumbers -deci 2 -value $sizeGB)"

				$obj
			}
		}

		$tableData = $tableClient | group "Agent Type" | %{
			$row=$_
			$obj = New-Object System.Object
			$obj | Add-Member -MemberType NoteProperty -Name "Agent Type" -Value $($row.Name -replace "WIN:","")
			$obj | Add-Member -MemberType NoteProperty -Name "Node Count" -Value "$(formatNumbers -value $($row.Count))"
			$obj | Add-Member -MemberType NoteProperty -Name "CPU Count" -Value "$(formatNumbers -value $(($row.Group.'CPU Count' | measure -Sum).Sum))"
			$obj | Add-Member -MemberType NoteProperty -Name "File Count" -Value "$(formatNumbers -value $(($row.Group.'File Count' | measure -Sum).Sum))"
			$obj | Add-Member -MemberType NoteProperty -Name "Backup (GB)" -Value "$(formatNumbers -deci 2 -value $($row.Group.'Total data stored (GB)' | measure -Sum).Sum)"
			$obj | Add-Member -MemberType NoteProperty -Name "(DEBUG) Clients" -Value "$($row.Group.'Node Name')"
			$obj
		} | sort "Node Count" -Descending

		if ($tableData)
		{
			export -title $tableHeader -dataTable $tableData -displayTableOrientation "Table" -headerType "h2" -metaAnalytics "" -showTableCaption "false" -description ""
		}



		# Show summary of "Nodes by Client Type Version 2
		#$tableHeader="Nodes by Client Type (Version 2)"
		#logThis -msg "Processing $tableHeader Report"
		#$tableData = $tsmServers.Clients | select NODE_NAME,CLIENT_OS_NAME | group CLIENT_OS_NAME | sort Count -Descending | select Name,Count
		#$tableData=$tsmServers | %{
			#$tsmserver=$_
			#$tsmserver.License_Details | group LICENSE_NAME | %{
				#$row=$_
				##$tsmclient=$_
				#if ($row.Name.Contains("MGSYSLAN") -or $row.Name.Contains("MYSYSSAN"))
				#{
					##$obj | Add-Member -MemberType NoteProperty -Name "Node Name" -Value $tsmclient.NODE_NAME
					#$tsmclients=$row.Group | %{ $node_name=$_.NODE_NAME; $tsmserver.Clients | ?{$_.NODE_NAME -eq $node_name} }
					#$groups = $tsmclients | ?{$_.PROXY_AGENT -eq 0} | group PLATFORM_NAME
					#$groups | ?{$_.Name.Contains("TDP")} | %{
						#$row=$_
						#$agentType=$row.Name
						#$tsmSubClients=$row.Group
						#$pcount=($tsmSubClients.PCOUNT | Measure -Sum).Sum
						#$fileCount=($tsmSubClients | %{$tsmclient=$_; [double](($tsmServer.Occupancy | ?{$_.NODE_NAME -eq $tsmclient.Node_name}) | measure NUM_FILES -sum).Sum} | measure -Sum).Sum
						#if (!$fileCount)
						#{
							#$fileCount = 0
						#}
						#$sizeGB=($tsmSubClients | %{$tsmclient=$_; [double](($tsmServer.Occupancy | ?{$_.NODE_NAME -eq $tsmclient.Node_name}) | measure LOGICAL_MB -sum).Sum} | measure -Sum).Sum
						##([double](($tsmServer.Occupancy | ?{$_.NODE_NAME -eq $tsmclient.Node_name}) | measure LOGICAL_MB -sum).Sum/1024)
						#if (!$sizeGB)
						#{
						#	$sizeGB = 0
						#}
#
						#$obj = New-Object System.Object
						#$obj | Add-Member -MemberType NoteProperty -Name "Agent Type" -Value $agentType
						#$obj | Add-Member -MemberType NoteProperty -Name "Node Count" -Value $tsmSubClients.Count
						#$obj | Add-Member -MemberType NoteProperty -Name "CPU Count" -Value $pcount
						#$obj | Add-Member -MemberType NoteProperty -Name "File Count" -Value $(formatNumbers -value $fileCount)
						#$obj | Add-Member -MemberType NoteProperty -Name "Backup (GB)" -Value $(formatNumbers -deci 2 -value $sizeGB)
						#$obj | Add-Member -MemberType NoteProperty -Name "(DEBUG)Servers" -Value "$([string]$tsmSubClients.NODE_NAME)"
						#$obj
					#}
					## This should be for all WinNT platforms, process all WinNT platform names and use the CLIENT_OS_LEVEL instead, group by that
					#$groups | ?{!$_.Name.Contains("TDP")} | %{
						#$_.Group | group CLIENT_OS_NAME | %{
							#$agentType=$_.Name -replace "Win:"
							#$tsmSubClients = $_.Group
							#$pcount=($tsmSubClients.PCOUNT | Measure -Sum).Sum
							#$fileCount=($tsmSubClients | %{$tsmclient=$_; [double](($tsmServer.Occupancy | ?{$_.NODE_NAME -eq $tsmclient.Node_name}) | measure NUM_FILES -sum).Sum} | measure -Sum).Sum
							#if (!$fileCount)
							#{
								#$fileCount = 0
							#}
							#$sizeGB=($tsmSubClients | %{$tsmclient=$_; [double](($tsmServer.Occupancy | ?{$_.NODE_NAME -eq $tsmclient.Node_name}) | measure LOGICAL_MB -sum).Sum} | measure -Sum).Sum
							##([double](($tsmServer.Occupancy | ?{$_.NODE_NAME -eq $tsmclient.Node_name}) | measure LOGICAL_MB -sum).Sum/1024)
							#if (!$sizeGB)
							#{
								#$sizeGB = 0
							#}
#
							#$obj = New-Object System.Object
							#$obj | Add-Member -MemberType NoteProperty -Name "Agent Type" -Value $agentType
							#$obj | Add-Member -MemberType NoteProperty -Name "Node Count" -Value $tsmSubClients.Count
							#$obj | Add-Member -MemberType NoteProperty -Name "CPU Count" -Value $pcount
							#$obj | Add-Member -MemberType NoteProperty -Name "File Count" -Value $(formatNumbers -value $fileCount)
							#$obj | Add-Member -MemberType NoteProperty -Name "Backup (GB)" -Value $(formatNumbers -deci 2 -value $sizeGB)
							#$obj | Add-Member -MemberType NoteProperty -Name "(DEBUG)Servers" -Value "$([string]$tsmSubClients.NODE_NAME)"
							#$obj
						#}
					#}
				#} else {
					#if ($row.Name.Contains("MSSQL"))
					#{
						#$agentType="TDP for Microsoft SQL"
					#} elseif ($row.Name.Contains("MSEXCH"))
					#{
						#$agentType="TDP for Exchange"
					#} else
					#{
						## else catch whatever else is not correctly handled, such as difference agent types
						#$agentType=$row.Name
					#}
					## Calculate the rest of the information needed for this table.
					#$tsmclients=$row.Group | %{ $node_name=$_.NODE_NAME; $tsmserver.Clients | ?{$_.NODE_NAME -eq $node_name} }
					#$pcount=($tsmclients.PCOUNT | Measure -Sum).Sum
					#$fileCount=($tsmclients | %{$tsmclient=$_; [double](($tsmServer.Occupancy | ?{$_.NODE_NAME -eq $tsmclient.Node_name}) | measure NUM_FILES -sum).Sum} | measure -Sum).Sum
					#if (!$fileCount)
					#{
						#$fileCount = 0
#					}
					#$sizeGB=($tsmclients | %{$tsmclient=$_; [double](($tsmServer.Occupancy | ?{$_.NODE_NAME -eq $tsmclient.Node_name}) | measure LOGICAL_MB -sum).Sum} | measure -Sum).Sum
					##([double](($tsmServer.Occupancy | ?{$_.NODE_NAME -eq $tsmclient.Node_name}) | measure LOGICAL_MB -sum).Sum/1024)
					#if (!$sizeGB)
					#{
						#$sizeGB = 0
					#}
#
					#$obj = New-Object System.Object
					#$obj | Add-Member -MemberType NoteProperty -Name "Agent Type" -Value $agentType
					#$obj | Add-Member -MemberType NoteProperty -Name "Node Count" -Value $tsmclients.Count
					#$obj | Add-Member -MemberType NoteProperty -Name "CPU Count" -Value $pcount
					#$obj | Add-Member -MemberType NoteProperty -Name "File Count" -Value $(formatNumbers -value $fileCount)
					#$obj | Add-Member -MemberType NoteProperty -Name "Backup (GB)" -Value $(formatNumbers -deci 2 -value $sizeGB)
					#$obj | Add-Member -MemberType NoteProperty -Name "(DEBUG)Servers" -Value "$([string]$tsmclients.NODE_NAME)"
					#$obj
				#}
			#}
		#}
		#if ($tableData)
		#{
			#export -title $tableHeader -dataTable $tableData -displayTableOrientation "Table" -headerType "h2" -metaAnalytics "" -showTableCaption "false" -description ""
		#}



		# SHOW summary of Nodes By Client Versions
		$tableHeader="Nodes By Client Version"
		logThis -msg "Processing $tableHeader Report"
		$tableData = $tsmservers.Clients | %{ "$($_.CLIENT_VERSION).$($_.CLIENT_RELEASE).$($_.CLIENT_LEVEL).$($_.CLIENT_SUBLEVEL)" } | group | select @{Name="Version";Expression={$_."Name"}},Count | Sort Count -Descending | %{
			$row=$_
			#if ($row.Name -ne "0.0.0")
			#{
				$row
			#}
		}
		if ($tableData)
		{
			export -title $tableHeader -dataTable $tableData -displayTableOrientation "Table" -headerType "h2" -metaAnalytics "" -showTableCaption "false" -description ""
		}

		# SHOW summary by Nodes definitions with Proxy
		$tableHeader="Nodes backed up via proxy agents"
		logThis -msg "Processing $tableHeader Report"
		$tableData = $tsmservers | %{
			$tsmserver=$_
			#$tsmserver.Clients | ?{$_.PROXY_TARGET -ne 0} | group PROXY_TARGET | select Name,Count | sort Count -Descending
			$tsmserver.Clients  | ?{$_.PROXY_AGENT -ne 0}  | Select NODE_NAME,PROXY_AGENT | sort NODE_NAME | %{
				$obj = New-Object System.Object
				$obj | Add-Member -MemberType NoteProperty -Name "Node Name" -Value "$($_.NODE_NAME)"
				$obj | Add-Member -MemberType NoteProperty -Name "Proxy Agent" -Value "$($_.PROXY_AGENT)"
				#$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value "$($tsmserver.Name)"
				if ($tsmservers.Name.Count -gt 1) {$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value "$($tsmServer.Name)"}

			}
		}
		if ($tableData)
		{
			export -title $tableHeader -dataTable $tableData -displayTableOrientation "Table" -headerType "h2" -metaAnalytics "" -showTableCaption "false" -description ""
		}


		# SHOW Top $topItemsOnly Consumers of Physical space
		$tableHeader="Top $topItemsOnly space consumers"
		logThis -msg "Processing $tableHeader Report"
		$tableData = $tsmServers |%{
			$tsmserver=$_
			$tsmserver.Occupancy  | ?{$_.NODE_NAME -ne "DELETED"} | group NODE_NAME | %{
				$row=$_
				$obj = New-Object System.Object
				$obj | Add-Member -MemberType NoteProperty -Name "Node Name" -Value "$($row.Name)"
				$obj | Add-Member -MemberType NoteProperty -Name "Amount (MB)" -Value $(formatNumbers -deci 2 -value $($row.Group | measure LOGICAL_MB -sum).Sum)
				#$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value "$($tsmserver.Name)"
				if ($tsmservers.Name.Count -gt 1) {$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value "$($tsmServer.Name)"}
				$obj
			}
		} | Sort-Object {[decimal]$_."Amount (MB)"} -Descending | Select -First $topItemsOnly
		if ($tableData)
		{
			export -title $tableHeader -dataTable $tableData -displayTableOrientation "Table" -headerType "h2" -metaAnalytics "" -showTableCaption "false" -description ""
		}


		# SHOW daily backups per day for the last 30 days
		$tableHeader="Daily backup totals"
		logThis -msg "Processing $tableHeader Report"
		$uniqueDates=($tsmServers.Summary | ?{$_.ACTIVITY -eq "BACKUP"}).START_TIME | Sort -Descending #Get-date  -F 'D' | Sort -Unique -Descending

		$dailyBackups=$tsmservers | %{
			$tsmserver=$_
			$tsmServer.Summary | ?{$_.ACTIVITY -eq "BACKUP"} | Sort START_TIME | %{
				$date=$_.START_TIME | Get-date -f 'dd-MM-yyy';
				$obj = New-Object System.Object
				$obj | Add-Member -MemberType NoteProperty -Name "Date" -Value $date
				$obj | Add-Member -MemberType NoteProperty -Name "Amt" -Value $_.BYTES
				$obj
			}
		} | group "Date"

		$lastDateOfReporting =  $dailyBackups.NAME | Get-date | sort -Descending | select -First 1
		$firstDateOfReporting = (Get-Date $lastDateOfReporting).AddDays('-30')
		$day=0
		$tableData = $dailyBackups | %{
			$dailyBackup=$_
			$firstDateOfReporting = (get-date $firstDateOfReporting).AddDays(+$day)
			$obj = New-Object System.Object
			$sum=([double]($dailyBackup.Group | Measure Amt -Sum).Sum/1024/1024/1024)
			$obj | Add-Member -MemberType NoteProperty -Name "Day" -Value $dailyBackup.Name
			$obj | Add-Member -MemberType NoteProperty -Name "Amount (GB)" -Value $(formatNumbers -deci 2 -value $sum)
			Write-Host "Name=$($dailyBackup.Name), sum=$sum"
			$obj
			$day++
		}
		if ($tableData)
		{
			export -title $tableHeader -dataTable $tableData -displayTableOrientation "Table" -headerType "h2" -metaAnalytics "" -showTableCaption "false" -description "Total backups for each day of the past month."
		}



	}

	$showStoragePools=$true
	if ($showStoragePools)
	{
		# Show storage pools capacity
		$tableHeader="Storage Pools"
		logThis -msg "Processing $tableHeader Report"
		$tableData = $tsmServers |%{
			$tsmserver=$_
			# $tsmServer.Storage_Pools | ?{$_.DEVCLASS -eq "DISK"} | select STGPOOL_NAME,est_capacity_mb,pct_utilized | %{
            $tsmServer.Storage_Pools | select STGPOOL_NAME,DEVCLASS,est_capacity_mb,pct_utilized | %{
				$pool=$_
			 	$obj = New-Object System.Object
				$obj | Add-Member -MemberType NoteProperty -Name "Pool name" -Value $pool.STGPOOL_NAME
                $obj | Add-Member -MemberType NoteProperty -Name "Device type" -Value $pool.DEVCLASS
				# $obj | Add-Member -MemberType NoteProperty -Name "Estimated Capacity MB" -Value  $(formatNumbers -deci 2 -value $([Math]::round([double]$pool.Est_capacity_mb/102.4+0.5/10))) #"$(formatNumbers -deci 2 -value $((([double]$pool.Est_capacity_mb)/1024+0.5)/10))"
                $obj | Add-Member -MemberType NoteProperty -Name "Estimated capacity MB" -Value  $(formatNumbers -deci 1 -value $($pool.Est_capacity_mb))
				$obj | Add-Member -MemberType NoteProperty -Name "% Used" -Value  "$(formatNumbers -deci 1 -value $($pool.pct_utilized))"
				if ($tsmservers.Name.Count -gt 1) {$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value "$($tsmServer.Name)"}
				$obj
			}
		}  | Sort-Object {[decimal]$_."Estimated capacity MB"} -Descending

		if ($tableData)
		{
			export -title $tableHeader -dataTable $tableData -displayTableOrientation "Table" -headerType "h2" -metaAnalytics "" -showTableCaption "false" -description ""
		}

		# Show Volumes with Errors ony Storage Pools capacity
		$tableHeader="Storage pool volumes with errors or non-writable volumes"
		logThis -msg "Processing $tableHeader Report"
		$tableData = $tsmServers |%{
			$tsmserver=$_
			$tsmserver.Volumes | ?{($_.READ_ERRORS -gt 0) -or ($_.WRITE_ERRORS -gt 0) -or ($_.ERROR_STATE -eq "YES") -or ($_.ACCESS -ne "READWRITE" -and $_.ACCESS -ne "OFFSITE")} | %{
				$vol=$_
				$obj = New-Object System.Object
				#"select volume_name,stgpool_name,access,error_state,write_errors,read_errors from volumes where error_state='YES' or write_errors >= 1 or read_errors >= 1 or access <> 'READWRITE'"
				$obj | Add-Member -MemberType NoteProperty -Name "Name" -Value $vol.Volume_Name
				$obj | Add-Member -MemberType NoteProperty -Name "Storage pool" -Value $vol.stgpool_name
				$obj | Add-Member -MemberType NoteProperty -Name "Access" -Value $vol.access
				$obj | Add-Member -MemberType NoteProperty -Name "Error state" -Value $vol.ERROR_STATE
				$obj | Add-Member -MemberType NoteProperty -Name "Write errors" -Value $(formatNumbers -value $vol.write_errors)
				$obj | Add-Member -MemberType NoteProperty -Name "Read errors" -Value $(formatNumbers -value $vol.read_errors)
				if ($tsmservers.Name.Count -gt 1) {$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value "$($tsmServer.Name)"}
				$obj
			}
		}
		if ($tableData)
		{
			export -title $tableHeader -dataTable $tableData -displayTableOrientation "Table" -headerType "h2" -metaAnalytics "" -showTableCaption "false" -description ""
		}

		# SHOW Storage Pool Usage
		#$tableHeader="Storage Pool File Usage"
		#logThis -msg "Processing $tableHeader Report"
		#$tableData = $tsmServers |%{
			#$tsmserver=$_
			#$stgPrimaryPools = ($tsmServer.Storage_Pools | ?{$_.POOLTYPE -eq "PRIMARY"}| select STGPOOL_NAME).STGPOOL_NAME
		 	#$tsmServer.Occupancy  | group NODE_NAME | sort NAME | %{
				#$obj = New-Object System.Object
				#$obj | Add-Member -MemberType NoteProperty -Name "Node Name" $_.Name
				#$group=$_.group
				#$stgPrimaryPools | %{
					#$poolName=$_
					#$instances = ($group | ?{$_.STGPOOL_NAME -eq $poolName} | measure NUM_FILES -Sum).Sum
					#$obj | Add-Member -MemberType NoteProperty -Name "Number of Files in $poolName" $instances
				#}
				#if ($tsmservers.Name.Count -gt 1) {$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value "$($tsmServer.Name)"}
				#$obj
			#}
		#}
		#if ($tableData)
		#{
			#export -title $tableHeader -dataTable $tableData -displayTableOrientation "Table" -headerType "h2" -metaAnalytics "" -showTableCaption "false" -description ""
		#}
	}

	# Need to use the second collection (collectTSMInformation2) method to use this function -- This function is in Work In Progress mode
	# This section should display the Runtime table for each TSM Server queried and give out Runtime Time stats for each query to determine if the change in queries
	# make a difference in the collection time
	$showRuntimeFigures=$false
	if ($showRuntimeFigures)
	{
		$tableHeader="Script Runtime"
		logThis -msg "Processing $tableHeader Report"
		$tableData = $tsmServers |%{
			$tsmserver=$_
			$tsmserver | %{
				$obj = New-Object System.Object
				$obj = $_.Runtime
				if ($tsmservers.Name.Count -gt 1) {$obj | Add-Member -MemberType NoteProperty -Name "TSM Server" -Value "$($tsmServer.Name)"}
				$obj
			}
		}
		if ($tableData)
		{
			export -title $tableHeader -dataTable $tableData -displayTableOrientation "Table" -headerType "h2" -metaAnalytics "" -showTableCaption "false" -description ""
		}
	}

	############################################################################################################
	# List of Issues found throughout this report
	#$tableHeader="Issues Report"
	#logThis -msg "Processing $tableHeader Report (Coming soon)"
	#$issuesRegister

	# GENERATE THE REPORT
	# Now all the individuals TABLES are exported + the NFO Files, call the report generator against them to create the HTML Report.
	$generateHTMLReport=$true
	if ($generateHTMLReport)
	{
		.\generateInfrastructureReports.ps1 -inDir $logDir -logDir $logDir -reportHeader $reportHeader -reportIntro $reportIntro -farmName $customerName -openReportOnCompletion $openReportOnCompletion -createHTMLFile $true -emailReport $false -verbose $false -itoContactName $itoContactName
	}
} else {
	Write-Host "`n`nNo suitable TSM Servers to query. Exiting..." -ForegroundColor Yellow
}