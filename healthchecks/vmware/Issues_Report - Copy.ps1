# This scripts is intended to be a quick Issues & health check report for vmware environments.
# Last updated: 20 Feb 2015
# Author: teiva.rodiere-at-gmail.com
#
# Goal for this script is to report on
# - Cluster Health
# - VM Errors, Warning
# - Host Errors, Warnings
# - Active Snapshots, Snapshots older than 24hrs
# - Filesystem Alarms, Errors
# - FS Volumes less than 10% of Free space
# - VMs without VMware tools, Errors
#
# ..and create Active Remediation tasks
#
#
param(
	[object]$srvConnection,
	[string]$logDir="output",
	[string]$comment="",
	[bool]$showDate=$false,
	[bool]$openReportOnCompletion=$true,
	[string]$saveReportToDirectory,
	[Parameter(Mandatory=$true)][string]$reportHeader,
	[Parameter(Mandatory=$true)][string]$reportIntro,
	[Parameter(Mandatory=$true)][int]$headerType=1,
	[int]$maxsamples = [int]::MaxValue,
	[int]$performanceLastDays=7,
	[string]$vmDateFieldsToCheck,
	[int]$showPastMonths=1,
	[string]$lastDayOfReportOveride,	
	[object]$vmsToCheck,
	[bool]$excludeThinDisks=$false,
	#Future proofing
	[string]$vmsToExclude,
	[string]$vmhostsToCheck,
	[string]$vmhostsToExclude,
	[string]$clustersToCheck,
	[string]$clustersToExclude,
	[string]$datastoresToCheck,
	[string]$datastoresToExclude
	#[Parameter(Mandatory=$true)][string]$farmName
)
Write-Host "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global

Set-Variable -Name reportIndex -Value "$logDir\index.txt" -Scope Global



# Want to initialise the module and blurb using this 1 function


# function
 # get-ld.ps1 (Levenshtein Distance)
# Levenshtein Distance is the # of edits it takes to get from 1 string to another
# This is one way of measuring the "similarity" of 2 strings
# Many useful purposes that can help in determining if 2 strings are similar possibly
# with different punctuation or misspellings/typos.
#
# Putting this as first non comment or empty line declares the parameters
# the script accepts
###########
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
 
function get-events([Parameter(Mandatory=$true)][Object]$obj,[Parameter(Mandatory=$true)][Object]$myvCenter,[DateTime]$startPeriod,[DateTime]$endPeriod)
{
	$events = Get-MyEvents -obj $obj -vCenterObj $myvCenter -startPeriod $startPeriod -endPeriod $endPeriod
	$issues=""
	$issuesCount=0
	$timeSpanText = getTimeSpanFormatted -timespan $($endPeriod - $startPeriod)
	if ($events)
	{
		# Filter on alarms first
		
		# filter on "EventTypeId"
		(($events | ?{$_.Source -and $_.To -eq "red"} | group FullformattedMessage)) | %{
			$event=$_
			if ($event.Count -gt 1)
			{
				$text="times"
			} else {
				$text="time"
			}
								
			$alarm = Get-AlarmDefinition -Name $event.Group[0].Alarm.Name -Server $myvCenter
			
			if ($alarm -like "*usage*")
			{
				$alarmThreshhold = "{0:N2} %" -f $([int]$alarm.ExtensionData.Info.Expression[0].Expression.Red / 100)
			} else {
				$alarmThreshhold = $alarm.ExtensionData.Info.Expression[0].Expression.Red
			}
			
			$issues += "$($alarm.Name) exceeded the alarm threshhold of $alarmThreshhold, at least $($event.Count) $text in the last $timeSpanText.`n"
			$issuesCount++
		}
		
		#$events | ?{$_.FullFOrmattedMessage -like "*unreachable*" -or $_.FullFOrmattedMessage -like "*error*" -or $_.FullFOrmattedMessage -like "*fault*" -or $_.FullFOrmattedMessage -like "*warning*" -or $_.FullFOrmattedMessage -like "*latency*"}
		$events | ?{$_.EventTypeId -like "*failure*" -or $_.EventTypeId -like "*error*" -or $_.EventTypeId -like "*fault*" -or $_.EventTypeId -like "*high"} | group EventTypeId | %{
			$event = $_
			#$name = $
			#$_.Number
			#$_.Group | %{
			if ($event.Count -gt 1)
			{
				$text="counts"
			} else {
				$text="count"
			}
			
			$issues += "$($event.Count) $text of Event ""$($event.Name)"".`n"
			$issuesCount++
			#}
		}
	}
	
	return $issues,$issuesCount
	
}
# Main Start ---------

if ($saveReportToDirectory)
{
	$outputFile = $saveReportToDirectory + "\" + ($($MyInvocation.MyCommand.Name)).Replace('.ps1','.html')
} else {
	$outputFile = $logDir+"\"+$runtime+"-"+($($MyInvocation.MyCommand.Name)).Replace('.ps1','.html')
}

#Declare the page
if ($srvconnection -and $srvconnection.Count -gt 1)
{
	$htmlTableHeader = "<table><th>Name</th><th>Issues/Actions</th><th>vCenter</th>"
} else {
	$htmlTableHeader = "<table><th>Name</th><th>Issues/Actions</th>"
}

$vmtoolsMatrix = getVMwareToolsVersionMatrix

# define all the Devices to query
$objectsArray = @(
	@($srvConnection | %{ $vcenterName=$_.Name; get-cluster * -server $_ | %{ $obj=$_; $obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenterName; $obj} }),
	@($srvConnection | %{ $vcenterName=$_.Name; get-vmhost * -server $_ | %{ $obj=$_; $obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenterName; $obj} }),
	@($srvConnection | %{ 
		$vcenterName=$_.Name; 
		$targetVMs = get-vm * -server $_ 
		$targetVMs | %{ $obj=$_; $obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenterName; 		
			if ($vmsToCheck)
			{
				if ($vmsToCheck.Contains($obj.Name))
				{
					$obj
				}
			} else {
				$obj 
			}
		}
	}),
	@($srvConnection | %{ $vcenterName=$_.Name; get-datacenter * -server $_ | %{ $obj=$_; $obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenterName; $obj} }),
	@($srvConnection | %{ $vcenterName=$_.Name; get-datastore * -server $_ | %{ $obj=$_; $obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenterName; $obj} })
)

# Get-stat variables

#$intervalsSecs = 5

if ($lastDayOfReportOveride)
{
	$performanceEndPeriod=Get-Date $lastDayOfReportOveride
} else {
	$performanceEndPeriod=Get-Date 
}
$performanceStartPeriod = $performanceEndPeriod.AddDays(-$performanceLastDays)
$eventsEndPeriod = $performanceEndPeriod
$eventsStartPeriod = $performanceEndPeriod.AddMOnths(-$showPastMonths)

#$objectsArray = @(@(get-cluster * -server $srvConnection), @(get-datastore * -Server $srvConnection))
$metaInfo = @()
$metaInfo +="tableHeader=Issues Report"
$metaInfo +="introduction=This report presents the findings."
$metaInfo +="chartable=false"
$metaInfo +="titleHeaderType=h$($headerType)"
$metaInfo +="showTableCaption=false"
$metaInfo +="displayTableOrientation=Table" # options are List or Table
ExportMetaData -metadata $metaInfo
updateReportIndexer -string $global:scriptName

$enable = $true
if ($enable)
{ 
	logThis -msg "######################################################################" -ForegroundColor $global:colours.Highlight
	logThis -msg "Checking OverallSatus of all systems..."  -ForegroundColor $global:colours.Highlight
	$title="Overall System Status"
	$description = "Quick health Check"
	$objMetaInfo = @()
	$objMetaInfo +="tableHeader=$title"
	$objMetaInfo +="introduction=$description. "
	$objMetaInfo +="chartable=false"
	$objMetaInfo +="titleHeaderType=h$($headerType+1)"
	$objMetaInfo +="showTableCaption=false"
	$objMetaInfo +="displayTableOrientation=Table" # options are List or Table

	$deviceTypeIndex=1
	$dataTable = $objectsArray | %{
		$objArray = $_		
		$type = $objArray[0].GetType().Name.Replace("Impl","")
		$row = New-Object System.Object
		$row | Add-Member -MemberType NoteProperty -Name "Name" -Value $type
		
		Write-Progress -Activity "Checking Overall Status" -Id 1 -Status "$deviceTypeIndex/$($objectsArray.Count) :- $type..." -PercentComplete  (($deviceTypeIndex/$($objectsArray.Count))*100)
		logThis -msg "[$type]" -ForegroundColor $global:colours.Highlight -NoNewLine $true
		$index=0; 
		$statusColours = [string]($objArray.ExtensionData.OverallStatus | Sort -Unique)
		if ($statusColours -like "*red*")
		{
			$colour="red"
		} elseif ($statusColours -like "*yellow*")
		{
			$colour="yellow"
		} else {
			$colour="green"
		}
		$row | Add-Member -MemberType NoteProperty -Name "Status" -Value $colour
		logThis -msg " - $colour" -ForegroundColor $global:colours.Highlight
		Write-Output $row
		$deviceTypeIndex++
	}
	
	if ($dataTable)
	{
		$metricCSVFilename = "$logdir\$($title -replace '\s','_').csv"
		$metricNFOFilename = "$logdir\$($title -replace '\s','_').nfo"
		ExportCSV -table $dataTable -thisFileInstead $metricCSVFilename 
		ExportMetaData -metadata $objMetaInfo -thisFileInstead $metricNFOFilename
		updateReportIndexer -string "$(split-path -path $metricCSVFilename -leaf)"
	}
}

$enable = $true
if ($enable)
{
	logThis -msg "######################################################################" -ForegroundColor $global:colours.Highlight
	logThis -msg "Checking Individual Systems / component issues and action items"  -ForegroundColor $global:colours.Highlight
	$title= "Systems Issues and Actions"
	#$htmlPage += "$(header2 $title)"
	$deviceTypeIndex=1
	$objectsArray | %{
		$objArray = $_
		$firstObj = $objArray | select -First 1
		$type = $firstObj.GetType().Name.Replace("Impl","")
		logthis -msg ">>>>>>>>>>>>>>>>>>>>>>>>>>>>   $type    >>>>>>>>>>>>>>>>>>>>>>>>>>>>" -ForegroundColor $global:colours.Information
		Write-Progress -Activity "Processing report" -Id 1 -Status "$deviceTypeIndex/$($objectsArray.Count) :- $type..." -PercentComplete  (($deviceTypeIndex/$($objectsArray.Count))*100)
		$index=0;
		logThis -msg "[`t`t$type`t`t]" -ForegroundColor $global:colours.Highlight
		switch($type)
		{
			"VirtualMachine" {	
				$title = "Virtual Machines"
				$friendlyName="VM"
				$description = "This section reports on $title related issues such as Active Alarms, Snapshots, Configuration and Runtime issues."
				logThis -msg $description
				$totalIssues = 0
				$deviceIndex=1
				$dataTable = $objArray | sort Name | %{
					$obj = $_
					$myvCenter=$srvConnection | ?{$_.Name -eq $obj.vCenter}
					$intervalsSecs = (Get-StatInterval -Server $myvCenter | ?{$_.Name -eq "Past Day"}).SamplingPeriodSecs
					Write-Progress -Activity "$title" -Id 2 -ParentId 1 -Status "$deviceIndex/$($objArray.Count) :- $($myvCenter.Name)\$($obj.Name)..." -PercentComplete (($deviceIndex/$($objArray.Count))*100)
					logthis -msg "`t-$($myvCenter.Name)\$($obj.Name)"
					$objectIssues = 0; $objectIssuesRegister = ""
					$clear = $false # use to disable the incomplete if statements below	
					$row = New-Object System.Object
					if ($srvConnection.Count -gt 1)
					{
						$row | Add-Member -MemberType NoteProperty -Name "Name" -Value "$($myvCenter.Name.ToUpper())\$($obj.Name.ToUpper())"
					} else {
						$row | Add-Member -MemberType NoteProperty -Name "Name" -Value $obj.Name.ToUpper()
					}
					if ($obj.ExtensionData.Runtime.ConnectionState -ne "connected")
					{
						$objectIssuesRegister += "Appears disconnected from within the vCenter inventory.`n"
						$objectIssues++
					}
					# Check if VM does not have Alarm Actions enabled 				
					if (!$obj.ExtensionData.AlarmActionsEnabled)
					{
						$objectIssuesRegister += "Is not monitored by vCenter because its ""Alarms Actions"" were manualy disabled. Re-enable as soon as possible.`n"
						$objectIssues++
					}
					# Check if Question mark. Warn if it is
					if ($obj.ExtensionData.Runtime.Question)
					{
						$objectIssuesRegister += "Is awaiting manual intervention by an administrator.`n"
						$objectIssues++
					}
					
					# Check if VM has alarms
					$hasAlarm = $($obj.ExtensionData.OverallStatus -eq "red")
					if ($hasAlarm)
					{
						$alarmCount = 0
						$alarmCount = $($obj.ExtensionData.TriggeredAlarmState.Alarm).Count
						$obj.ExtensionData.TriggeredAlarmState | %{
							$triggeredAlarmState = $_
							$definitionname = $(Get-AlarmDefinition -id $triggeredAlarmState.Alarm -Server $myvCenter).Name
							$objectIssuesRegister += "Is reporting a ""$definitionname"" alarm on $(get-date ($triggeredAlarmState.Time)).`n"
							$objectIssues++
						}
						
						if ($hasAlarm) {Remove-Variable hasAlarm}
						if ($alarmCount) { Remove-Variable alarmCount}
					}
					
					
					$objwareToolsNotRunning = $obj.ExtensionData.Guest.ToolsRunningStatus -eq "guestToolsRunning"
					if ($objwareToolsNotRunning)
					{	
						#logThis -msg "VM Name = $($obj.Name.ToUpper())"
						#$domainName = [string]$obj.ExtensionData.Guest.Net.DnsConfig.DomainName
						$guestName = ($obj.ExtensionData.Guest.HostName -split "\.")[0] #$($obj.ExtensionData.Guest.HostName -replace "\.$domainName",'')
						#logThis -msg "VM Guest Name = $guestName"
						if ($obj.Name.ToUpper() -ne $guestName.ToUpper())
						{
							$objectIssuesRegister += "The current guest name ""$guestName"" does not match the virtual machine name ""$($obj.Name)"".`n"
							$objectIssues++
						} 
					}
					# Check if tool installer is mounted. Warn if it is
					if ($obj.ExtensionData.Runtime.ToolsInstallerMounted)
					{
						$objectIssuesRegister += "Has its CD-ROM connected to the VMware Tools Installer. Disconnect it as soon possible to allow DRS to work effectively.`n"
						$objectIssues++
					}

					# Check for VMware Tools Running
					$objwareToolsNotRunning = $obj.ExtensionData.Guest.ToolsRunningStatus -ne "guestToolsRunning"
					if ($objwareToolsNotRunning)
					{
						$objectIssuesRegister += "Its VMware Tools are not running, check the in Guest.`n"
						$objectIssues++
					}
					# Check for VMware Tools installed
					$objwareToolssNotInstalled = $obj.ExtensionData.Guest.ToolsVersionStatus -eq "guestToolsNotInstalled" -or $obj.ExtensionData.Guest.ToolsVersionStatus -eq "guestToolsNeedUpgrade"
					if ($objwareToolsNotInstalled)
					{						
						$objectIssuesRegister += "Install or upgrade the VMware Tools because they are either not installed or too old.`n"
						$objectIssues++
					} else {
						if ( ([int]$($obj.Version -replace 'v') + 0) -le 4 ) {
							$objectIssuesRegister += "The VM hardware version does not support VMware VDAP which will impact Backups.`n"
							$objectIssues++
						}
					}
					# check file system space
					if ($obj.ExtensionData.Guest.ToolsRunningStatus -eq "guestToolsRunning")
					{
						$obj.ExtensionData.Guest.Disk | %{
							$freeGB = "{0:N2} GB" -f $($_.FreeSpace / 1gb)
							$usedPerc = 100 - ($_.FreeSpace / $_.Capacity * 100)
							if ($usedPerc -gt 95)
							{
								$objectIssuesRegister += "Volume ""$($_.DiskPath)"" is " + $("{0:N2} %" -f $usedPerc) +" used ($freeGB free).`n"
								$objectIssues++ 
							}
						}
					}
					
					# Check for snapshots
					$objhasSnapshot = $obj.ExtensionData.Snapshot
					if ($objhasSnapshot)
					{
						$snapshots = Get-Snapshot -VM $obj -Server $myvCenter
						#$objectIssuesRegister += "This VM has $($snapshots.Count) VM Snapshots. Please delete as soon as possible.`n"
						#$objectIssuesRegister += "<table><th>Snapshot Name</th><th>Description</th><th>Age</th><th>SizeGB</th><th>Taken by</th><th>PowerState Before Snapshot</th><th>Active One</th>"
						$snapshots | %{
								$Snapshot = $_
								$TaskMgr = Get-View TaskManager -Server $myvCenter
						        $Filter = New-Object VMware.Vim.TaskFilterSpec
						        $Filter.Time = New-Object VMware.Vim.TaskFilterSpecByTime
						        $Filter.Time.beginTime = ((($Snapshot.Created).AddSeconds(-5)).ToUniversalTime())
						        $Filter.Time.timeType = "startedTime"
						        $Filter.Time.EndTime = ((($Snapshot.Created).AddSeconds(5)).ToUniversalTime())
						        $Filter.State = "success"
						        $Filter.Entity = New-Object VMware.Vim.TaskFilterSpecByEntity
						        $Filter.Entity.recursion = "self"
						        $Filter.Entity.entity = (Get-Vm -Name $Snapshot.VM.Name -Server $myvCenter).Extensiondata.MoRef
						        $TaskCollector = Get-View ($TaskMgr.CreateCollectorForTasks($Filter)) #-Server $myvCenter
						        $TaskCollector.RewindCollector | Out-Null
						        $Tasks = $TaskCollector.ReadNextTasks(100)
						        FOREACH ($Task in $Tasks)
						        {
						          $GuestName = $Snapshot.VM
						          $Task = $Task | where {$_.DescriptionId -eq "VirtualMachine.createSnapshot" -and $_.State -eq "success" -and $_.EntityName -eq $GuestName}
						          IF ($Task -ne $null)
						          {
						              $SnapUser = $Task.Reason.UserName
						          }
						        }
						        $TaskCollector.DestroyCollector()
						        $Snapshot | Add-Member -MemberType NoteProperty -Name "CreatedBy" -Value $SnapUser
								$mydatestring = new-timespan -End (get-date) -Start (get-date $_.Created) 								
								$objectIssuesRegister += "`tA snapshot called ""$($snapshot.Name)"" taken $($mydatestring.Days) days $($mydatestring.hours) hours ago by ""$SnapUser"" is still active. It is consuming $([math]::round($snapshot.SizeGB,2)) GB.`n"
						       #Write-Output $Snapshots
						}
						#$objectIssuesRegister += "<ul>`n"
						if ($snapshots) {Remove-Variable snapshots }
						if ($objhasSnapshot) {	Remove-Variable objhasSnapshot }
						$objectIssues++
					}
					
					
					# Check VMs with Thin disks
					if ($excludeThinDisks)
					{
					} else {
						$hasThinDisks = $obj.ExtensionData.Config.Hardware.Device | ?{$_.ControllerKey -eq "1000"} | ?{$_.Backing.ThinProvisioned -eq $true}
						if ($hasThinDisks)
						{
							$objectIssuesRegister += "This VM has $($hasThinDisks.Count) thinly deployed disks. Reconsider using Thick disks instead.`n"
							$objectIssues++
						}
					}

					
					# CHECK HW Version
					$hwvMatrix = Import-csv .\packages.vmware.com.vmw.hardware.versions.csv
					$hostMajorVersion,$hostMinorVersion,$other = $(get-vmhost -VM $obj -Server $myvCenter).Version.Split('.')
					$latestVMHardwareVersion = ($hwvMatrix | ?{$_.ESXVersion -eq "$hostMajorVersion.$hostMinorVersion"}).VMHardware
					$withOldHardware = $obj.Version -ne $latestVMHardwareVersion
					
					if ($withOldHardware)
					{
						$objectIssuesRegister += "Is running an old $friendlyName Hardware Version ""$($obj.Version)"". The latest supported version by the host is ""$latestVMHardwareVersion"".`n"
						$objectIssues++
					}
					# Check VMs with memory balooning
					if ($obj.PowerState -eq "PoweredOn")
					{
						# Check performance
						"mem.vmmemctl.average","mem.usage.average","cpu.usage.average","mem.swapped.average" | %{
							$statName=$_
							$warningThreshold=70
							$objStats = $obj | Get-Stat -Server $myvCenter -Stat $statName -Start $performanceStartPeriod -Finish $performanceEndPeriod -MaxSamples $maxsamples -IntervalSecs $intervalsSecs
							if ($objStats)
							{
								$unit=$objStats[0].Unit
								$unitName = $objStats[0].MetricId -split '.',1
								if ($statName -eq "mem.vmmemctl.average")
								{
									$whatIsBeenUpTo="balooning"
								} else {
									$whatIsBeenUpTo="consuming"
								}
								$performance = $objStats | measure -Property Value -Average -Maximum					
								$peaks = $objStats | ?{$_.Value -ge $warningThreshold}
								if ($peaks) 
								{ 
									$percExceeds=$peaks.Count/$objStats.count*100
									if ((($performance.Average -ge $warningThreshold) -or ($performance.Maximum -ge $warningThreshold)) -and $percExceeds -gt 5)
									{
										
										$objectIssuesRegister += "Could be suffering from $((($objStats[0].MetricId) -split '\.')[0].ToUpper()) performance issues. It as been $whatIsBeenUpTo on average $([math]::round($performance.Average,2)) $unit of its entitlements over the past $performanceLastDays days with peaks exceeding the warning threashold of $warningThreshold%, $('{0:N2} %' -f $($peaks.Count/$objStats.count*100)) of the time. The highest peak recorded was $([math]::round($performance.Maximum,2))%.`n"
										$objectIssues++
									}
								}
							}
						}
						
						
						# Check for MAC address missmatch between the adapter and guest
						#
						$obj.ExtensionData.Guest.Net | %{
							#$_.DeviceConfigId
							#$obj.Id
							if ($_.DeviceConfigId)
							{
								$guestAdapater=$_.DeviceConfigId
							
								$idToMatch="$($obj.Id)/$guestAdapater"
								#$idToMatch
								$adapter=$obj.NetworkAdapters | ?{$_.id -eq $idToMatch }
								$adapterMAC=$adapter.MacAddress.ToUpper()
								$guestMAC=$($_.MacAddress.ToUpper())
								#logThis -msg "GuestMAC=$guestMAC, AdapterMAC=$adapterMAC"
								if ($guestMAC -ne $adapterMAC) {
									$objectIssuesRegister += """$($adapter.Name)""'s MAC Address ""$adapterMAC"" differs from the Guest MAC address ""$guestMAC"".`n"
									$objectIssues++
								}
							}
						}
					}

					# Check VMs with MemMB Reservations
					$objHasResourceLimits = $obj.ExtensionData.ResourceConfig.MemoryAllocation.Limit -lt ( $obj.MemoryMB + ($obj.ExtensionData.Runtime.MemoryOverhead / 1024 / 1024) )
					if ($objHasResourceLimits -and ($objHasResourceLimits -ne "-1"))
					{
						$objectIssuesRegister += "Has a Hard Memory Limits placed on it. It is allocated $($obj.MemoryMB)MB whilst hard limited to $($obj.ExtensionData.ResourceConfig.MemoryAllocation.Limit) MB. It could eventually cause it to swap.`n"
						$objectIssues++
					}
					
					# If the VM has reservations that exceed the requirement of the VM itself (memory MB)
					$objHasResourceReservations = $obj.ExtensionData.ResourceConfig.MemoryAllocation.Reservation -gt ( $obj.MemoryMB + ($obj.ExtensionData.Runtime.MemoryOverhead / 1024 / 1024) )
					if ($objHasResourceReservations -and ($objHasResourceReservations -ne "-1"))
					{
						$value = ($obj.MemoryMB + ($obj.ExtensionData.Runtime.MemoryOverhead / 1024 / 1024)) - $obj.ExtensionData.ResourceConfig.MemoryAllocation.Reservation
						if ($value -lt 0)
						{
							$objectIssuesRegister += "Has a memory reservation that exceeds its allocation, essentially wasting reserve memory. It is allocated $($obj.MemoryMB) MB and reserved $value MB.`n"
							$objectIssues++
							
						}
						Remove-Variable value
						Remove-Variable objHasResourceReservations
					}
					
					
					if ($vmDateFieldsToCheck)
					{
						logThis -msg "`t`tChecking for $vmDateFieldsToCheck"
						$vmDateFieldsToCheck | %{
							$attributeName=$_
							$attibute = Get-CustomAttribute -Name $attributeName -Server $myvCenter
							if ($attibute)
							{
								$value = ($obj.CustomFields | ?{$_.Key -eq $($attibute.Name)}).Value
								if (!$value)
								{
									$objectIssuesRegister += "The date in field ""$attributeName"" is empty.`n"
									$objectIssues++
								} else {
									$lastBackupDate=get-date (($obj.CustomFields | ?{$_.Key -eq $($attibute.Name)}).Value)
									if ($lastBackupDate -lt $performanceStartPeriod)
									{
										#$lastBackupDate
										$objectIssuesRegister += "The date in field ""$attributeName"" of $lastBackupDate and is older than $performanceLastDays days.`n"
										$objectIssues++
									}
								}
								
							}
						}
					}
					
					#teiva
					$issuesList,$issuesCount = Get-events -obj $obj -myvCenter $myvCenter -startPeriod $eventsStartPeriod -endPeriod $eventsEndPeriod
					$objectIssuesRegister += $issuesList
					$objectIssues += $issuesCount
					
					$row | Add-Member -MemberType NoteProperty -Name "Issues" -Value "$objectIssuesRegister"
					
					if ($objectIssues -and $objectIssues -gt 0) 
					{
						
						Write-Output $row
						$totalIssues += $objectIssues
						
					}
					$deviceIndex++
				}
				if ($dataTable)
				{
					$description += " A total of $totalIssues issues were recorded.`n"
					$objMetaInfo = @()
					$objMetaInfo +="tableHeader=$title"
					$objMetaInfo +="introduction=$description. "
					$objMetaInfo +="chartable=false"
					$objMetaInfo +="titleHeaderType=h$($headerType+1)"
					$objMetaInfo +="showTableCaption=false"
					$objMetaInfo +="displayTableOrientation=Table" # options are List or Table
					$metricCSVFilename = "$logdir\$($title -replace '\s','_').csv"
					$metricNFOFilename = "$logdir\$($title -replace '\s','_').nfo"
					ExportCSV -table $dataTable -thisFileInstead $metricCSVFilename 
					ExportMetaData -metadata $objMetaInfo -thisFileInstead $metricNFOFilename
					updateReportIndexer -string "$(split-path -path $metricCSVFilename -leaf)"
				}				
			}

			"VMHost" {
				#if ($objectIssuesRegister) { Remove-Variable objectIssuesHTMLText }
				#if ($sectionIssuesHTMLText) { Remove-Variable sectionIssuesHTMLText }
				$title = "VMware Hypervisors"
				$description = "This section reports on $title issues. Specifically, the report looks finds Active Alarms, usage issues, vCPU Count allocations, Memory Pressures."
				$friendlyName="VMware Hypervisor"
				logThis -msg $description
				$sectionIssuesHTMLText = $htmlTableHeader
				$totalIssues = 0
				$deviceIndex=1
				$dataTable = $objArray | sort Name | %{		
					$obj = $_
					$myvCenter=$srvConnection | ?{$_.Name -eq $obj.vCenter}
					Write-Progress -Activity "$title" -Id 2 -ParentId 1 -Status "$deviceIndex/$($objArray.Count) :- $($myvCenter.Name)\$($obj.Name)..." -PercentComplete (($deviceIndex/$($objArray.Count))*100)
					logthis -msg "`t-$($myvCenter.Name)\$($obj.Name)"
					$objectIssues = 0; $objectIssuesRegister = ""
					$clear = $false # use to disable the incomplete if statements below				
					$row = New-Object System.Object
					if ($srvConnection.Count -gt 1)
					{
						$row | Add-Member -MemberType NoteProperty -Name "Name" -Value "$($myvCenter.Name.ToUpper())\$($obj.Name.ToUpper())"
					} else {
						$row | Add-Member -MemberType NoteProperty -Name "Name" -Value $obj.Name.ToUpper()
					}
					

					# Check if VM has alarms
					$hasAlarm = $($obj.ExtensionData.OverallStatus -eq "red")
					if ($hasAlarm)
					{
						$alarmCount = 0
						$alarmCount = $($obj.ExtensionData.TriggeredAlarmState.Alarm).Count
						$obj.ExtensionData.TriggeredAlarmState | %{
							$triggeredAlarmState = $_
							$definitionname = $(Get-AlarmDefinition -id $triggeredAlarmState.Alarm -Server $myvCenter).Name
							$objectIssuesRegister += "It reported a ""$definitionname"" alarm on $(get-date ($triggeredAlarmState.Time)).`n"
							$objectIssues++
						}
						if ($hasAlarm) {Remove-Variable hasAlarm}
						if ($alarmCount) { Remove-Variable alarmCount}
					}
					
					# Perf State 1
					("mem.usage.average > 70","cpu.usage.average > 70") | %{
						$statName,$measure,$warningThreshold=$_ -split "\s"
						$objStats = $obj | Get-Stat -Server $myvCenter -Stat $statName -Start $performanceStartPeriod -Finish $performanceEndPeriod -MaxSamples $maxsamples -IntervalSecs $intervalsSecs
						if ($objStats)
						{
							$unit=$objStats[0].Unit
							$unitName = $objStats[0].MetricId -split '.',1
							
							$performance = $objStats | measure -Property Value -Average -Maximum					
							$peaks = $objStats | ?{$_.Value -ge $([int]$warningThreshold)}
							if ($peaks) 
							{ 
								$percExceeds=$peaks.Count/$objStats.count*100
								
								if ($measure -eq ">")
								{
									$isTrue=(($performance.Average -ge $([int]$warningThreshold)) -or ($performance.Maximum -ge $([int]$warningThreshold))) -and $percExceeds -gt 5
								} elseif ($measure -eq "<") {
									$isTrue=(($performance.Average -le $([int]$warningThreshold)) -or ($performance.Maximum -le $([int]$warningThreshold))) -and $percExceeds -gt 5
								}
								
								if ($isTrue)
								{
									$percExceeds=$peaks.Count/$objStats.count*100
									#$objectIssuesRegister += "Over the past $performanceLastDays days, this $friendlyName has using on average $([math]::round($performance.Average,2)) $unit of its $((($objStats[0].MetricId) -split '\.')[0].ToUpper()) entitlements, with peaks exceeding $warningThreshold% usage $('{0:N2} %' -f $($peaks.Count/$objStats.count*100)) of the time. The highest peak recorded is $([math]::round($performance.Maximum,2)) %. If these peaks increase in frequency, consider adding more resources to this $friendlyName. "
									if ($statName -eq "mem.vmmemctl.average")
									{
										$whatIsBeenUpTo="balooning"
									} else {
										$whatIsBeenUpTo="consuming"
									}
									$objectIssuesRegister += "Could be suffering from $((($objStats[0].MetricId) -split '\.')[0].ToUpper()) performance issues. It as been $whatIsBeenUpTo on average $([math]::round($performance.Average,2)) $unit of its entitlements over the past $performanceLastDays days with peaks exceeding the warning threashold of $warningThreshold%, $('{0:N2} %' -f $($peaks.Count/$objStats.count*100)) of the time. The highest peak recorded was $([math]::round($performance.Maximum,2))%.`n"
									$objectIssues++
								}
							}
						}
					}
					
					# Check to see if the number of datastores is the same on all hosts in the same cluster	
					$parent =  $obj.Parent #Get-View $obj.Parent -Server $myvCenter
					#if ($parent.GetType().Name -eq 'ClusterComputeResource')
					if ($parent.GetType().Name -like "*Cluster*")
					{
						# The parent resource is a cluster.
						$clusterNodes = get-vmhost -Location $parent.Name -Server $myvCenter 
						#logThis -msg "Parent Object: $($parent.Name)" -ForegroundColor $global:colours.Information -BackgroundColor $global:colours.Error
						#logThis -msg "Cluster nodes: $($clusterNodes.Count)" -ForegroundColor $global:colours.Information -BackgroundColor $global:colours.Error
						# Check to see if the ESX servers in the same cluster have the same amount of datastores that the cluster has 
						$datastoreCount = (get-datastore -VMHost $clusterNodes -Server $myvCenter).Count
						if ($obj.DatastoreIdList.Count -ne $datastoreCount)
						{
							$objectIssuesRegister += "This host belongs to a cluster ""$($parent.Name)"" which has a total of $datastoreCount datastores but this server only has $($obj.DatastoreIdList.Count) datastores mapped to it.`n"
							$objectIssues++
							Remove-Variable datastoreCount
						}
						
						$stdClustersVSwitchesCount = ($clusterNodes | Get-VirtualSwitch  -Server $myvCenter | select Name -unique).Count
						$stdVSwitchesCount = ($obj | Get-VirtualSwitch  -Server $myvCenter | select Name -unique).Count
						if ($stdVSwitchesCount -ne $stdClustersVSwitchesCount)
						{
							$objectIssuesRegister += "This host belongs to a cluster ""$($parent.Name)"" which has a total of $stdClustersVSwitchesCount Switches but this server only has $stdVSwitchesCount Switches mapped to it.`n"
							$objectIssues++
							Remove-Variable stdClustersVSwitches
							Remove-Variable  stdVSwitches
						}
						
						# Check the same port group count
						$stdClusterVPGCount = ($clusterNodes | Get-VirtualPortGroup  -Server $myvCenter| select Name -unique).Count
						$stdVPGCount = ($obj | Get-VirtualPortGroup  -Server $myvCenter| select Name -unique).Count
						if ($stdVPGCount -ne $stdClusterVPGCount)
						{
							$objectIssuesRegister += "This host belongs to a cluster ""$($parent.Name)"" which has a total of $stdClusterVPGCount Port Groups but this server only has $stdVPGCount Port Group mapped to it.`n"
							$objectIssues++
							Remove-Variable stdClusterVPGCount
							Remove-Variable  stdVPGCount
						}
						
						
						# Check that all Hosts have the same cards in the dvSwitches
						
						#$nics  = 
						$vmkernelNics = $obj | Get-VMHostNetworkAdapter  -Server $myvCenter | ?{$_.GetType().Name.Contains("HostVMKernelVirtualNicImpl")}
						if ($vmkernelNics)
						{
							$vmkernelNics| %{
								if ($vmkernelNics.ManagementTrafficEnabled -and $_.VMotionEnabled)
								{
									$objectIssuesRegister += "This host uses the same VMkernel Interface ""$($_.Name)"" for Hypervisor Management and VMotion. It is recommended to separate the roles onto dedicated interfaces.`n"
									$objectIssues++
								}
								if ($vmkernelNics.ManagementTrafficEnabled -and $_.FaultToleranceLoggingEnabled)
								{
									$objectIssuesRegister += "This host uses the same VMkernel Interface ""$($_.Name)"" for Hypervisor Management and Fault Tolerance Traffic. It is recommended to separate the roles onto dedicated interfaces.`n"
									$objectIssues++
								}
								if ($vmkernelNics.ManagementTrafficEnabled -and $_.VsanTrafficEnabled)
								{
									$objectIssuesRegister += "This host uses the same VMkernel Interface ""$($_.Name)"" for Hypervisor Management and VSAN Traffic. It is recommended to separate the roles onto dedicated interfaces.`n"
									$objectIssues++
								}
							}
							#Remove-Variable nics
							Remove-Variable vmkernelNics
						}
						
						#
						# Check to see if the number of NICs are the same on all hosts in the same cluster
					}
					
					# Check if VM Network on the same vSwitch as Out of band mgmt vmkernel ports
					
					
					# Check if best EVC mode is chosen 
					if ($obj.ExtensionData.Summary.$MaxEVCModeKey -ne $obj.ExtensionData.Summary.CurrentEVCModeKey)
					{
						$objectIssuesRegister += "This host supports a higher EVC mode ($($obj.ExtensionData.Summary.MaxEVCModeKey) than the cluster is currently enabled for ($($obj.ExtensionData.Summary.CurrentEVCModeKey)).`n"
						$objectIssues++
					}
					
					# Check if a reboot is required
					if ($obj.ExtensionData.Summary.RebootRequired)
					{
						$objectIssuesRegister += "This server is pending a reboot.`n"
						$objectIssues++
					}
					
					#check if the alarm actions are enabled on this device
					if (!$obj.ExtensionData.AlarmActionsEnabled)
					{
						$objectIssuesRegister += "The alarm actions on this system are disabled. No alarms will be generated for this system as a result. Consider re-enabling it.`n"
						$objectIssues++
					}
					
									
					$issuesList,$issuesCount = Get-events -obj $obj -myvCenter $myvCenter -startPeriod $eventsStartPeriod -endPeriod $eventsEndPeriod
					$objectIssuesRegister += $issuesList
					$objectIssues += $issuesCount

					
					$row | Add-Member -MemberType NoteProperty -Name "Issues" -Value "$objectIssuesRegister"
					
					if ($objectIssues -and $objectIssues -gt 0) 
					{
						
						Write-Output $row
						$totalIssues += $objectIssues
					}
					$deviceIndex++
				}
				if ($dataTable)
				{
					$description += " A total of $totalIssues issues were recorded.`n"
					$objMetaInfo = @()
					$objMetaInfo +="tableHeader=$title"
					$objMetaInfo +="introduction=$description. "
					$objMetaInfo +="chartable=false"
					$objMetaInfo +="titleHeaderType=h$($headerType+1)"
					$objMetaInfo +="showTableCaption=false"
					$objMetaInfo +="displayTableOrientation=Table" # options are List or Table
					$metricCSVFilename = "$logdir\$($title -replace '\s','_').csv"
					$metricNFOFilename = "$logdir\$($title -replace '\s','_').nfo"
					ExportCSV -table $dataTable -thisFileInstead $metricCSVFilename 
					ExportMetaData -metadata $objMetaInfo -thisFileInstead $metricNFOFilename
					updateReportIndexer -string "$(split-path -path $metricCSVFilename -leaf)"
				}		
			}
			
			"VmfsDatastore" {
				#if ($objectIssuesRegister) { Remove-Variable objectIssuesHTMLText }
				#if ($sectionIssuesHTMLText) { Remove-Variable sectionIssuesHTMLText }
				$title = "VMFS Datastores"
				$description = "This section reports on $title related issues."	
				$objMetaInfo = @()
				$objMetaInfo +="tableHeader=$title"
				$objMetaInfo +="introduction=$description. "
				$objMetaInfo +="chartable=false"
				$objMetaInfo +="titleHeaderType=h$($headerType+1)"
				$objMetaInfo +="showTableCaption=false"
				$objMetaInfo +="displayTableOrientation=Table" # options are List or Table
				logThis -msg $description
				$htmlPage += "<a id=""$type"">$(header3 $title)</a>"
				$htmlPage += "<p>$description</p>"
				$sectionIssuesHTMLText = $htmlTableHeader
				$totalIssues = 0
				$deviceIndex=1
				$dataTable = $objArray | sort Name | %{
					$obj = $_
					$myvCenter=$srvConnection | ?{$_.Name -eq $obj.vCenter}
					Write-Progress -Activity "$title" -Id 2 -ParentId 1 -Status "$deviceIndex/$($objArray.Count) :- $($myvCenter.Name)\$($obj.Name)..." -PercentComplete (($deviceIndex/$($objArray.Count))*100)
					logthis -msg "`t-$($myvCenter.Name)\$($obj.Name)"
					$objectIssues = 0; $objectIssuesRegister = ""		
					$clear = $false # use to disable the incomplete if statements below	
					$row = New-Object System.Object
					$row | Add-Member -MemberType NoteProperty -Name "Name" -Value $obj.Name.ToUpper()
					
					# Check if VM has alarms
					$hasAlarm = $($obj.ExtensionData.OverallStatus -eq "red")
					if ($hasAlarm)
					{
						$alarmCount = 0
						$alarmCount = $($obj.ExtensionData.TriggeredAlarmState.Alarm).Count
						$objectIssuesRegister += "The Datastore is reporting having $alarmCount active alarm(s). <ul><u>Alarms</u>`n"
						$obj.ExtensionData.TriggeredAlarmState | %{
							$triggeredAlarmState = $_
							$definitionname = $(Get-AlarmDefinition -id $triggeredAlarmState.Alarm  -Server $myvCenter).Name
							$objectIssuesRegister += "<i><u>Name:</u> $definitionname, <u>Date:</u> $(get-date ($triggeredAlarmState.Time)).</i>`n"
							$objectIssues++
						}
						
						if ($hasAlarm) {Remove-Variable hasAlarm}
						if ($alarmCount) { Remove-Variable alarmCount}
					}
					
					# Check capacity Free space 
					$minSpaceFreePerc = 5 # In Percentage
					$minSpaceFreeSizeGB = 10
					$freeSpaceGB = [math]::round($obj.FreeSpaceMB / 1024,2)
					#$freeSpacePerc = 100 - [math]::round($obj.FreeSpaceMB / $obj.CapacityMb * 100,2)
					$freeSpacePerc = [math]::round($obj.FreeSpaceMB / $obj.CapacityMb * 100,2)
					if (($freeSpacePerc -le $minSpaceFreePerc) -and ($freeSpaceGB -le $minSpaceFreeSizeGB))
					{
						$objectIssuesRegister += "There is only $freeSpacePerc % of freesace ($freeSpaceGB GB) on this datastore `n"
						$objectIssues++
					}					
					# Check if there are Non VMFS 5 Volumes
					
					# Check for growth
					$dataTable = .\Datastore_Usage_Report.ps1 -srvConnection $srvconnection  -includeThisMonthEvenIfNotFinished $false -showPastMonths $showPastMonths -returnTableOnly $true -datastore $obj -vcenter $myvCenter
					
					# Check for Orphaned Disks on Datastores
					# -- Collected a list of assigned/used disks
					$arrUsedDisks = Get-View -ViewType VirtualMachine -Server $myvCenter | % {$_.Layout} | % {$_.Disk} | % {$_.DiskFile}
					$dsView = Get-View $obj.Id  -Server $myvCenter
					$fileQueryFlags = New-Object VMware.Vim.FileQueryFlags
					$fileQueryFlags.FileSize = $true
					$fileQueryFlags.FileType = $true
					$fileQueryFlags.Modification = $true
					$searchSpec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
					$searchSpec.details = $fileQueryFlags
					$searchSpec.matchPattern = "*.vmdk"
					$searchSpec.sortFoldersFirst = $true
					$dsBrowser = Get-View $dsView.browser -Server $myvCenter
					$rootPath = "[" + $dsView.Name + "]"
					$searchResult = $dsBrowser.SearchDatastoreSubFolders($rootPath, $searchSpec)
					
					if ($orphanDisksOutput) { Remove-variable orphanDisksOutput }
					$orphanDisksOutput = @()
					foreach ($folder in $searchResult)
					{
						foreach ($fileResult in $folder.File)
						{
							if ($fileResult.Path)
							{
								$pathAsString = out-string -InputObject $FileResult.Path
								if (-not ($arrUsedDisks -contains ($folder.FolderPath + $fileResult.Path)))
								{
									# Changed Black Tracking creates ctk.vmdk files that are not referenced in the VMX.  This prevents them from showing as false positives.
									if (-not ($pathAsString.toLower().contains("-ctk.vmdk")))
									{
										$row = "" | Select "Path", "File", "SizeGB", "Last Modified"
										#$row.Datastore = $strDatastore.Name
										$row.Path = $folder.FolderPath
										$row.File = $fileResult.Path
										$row.SizeGB = [math]::round($fileResult.FileSize / 1gb,2)
										$row."Last Modified" = $fileResult.Modification
										logThis -msg $row
										$orphanDisksOutput += $row
										$objectIssues++
									}
								}
							}
						}
					}

					if ($orphanDisksOutput)
					{
						logThis -msg "------------" -ForegroundColor $global:colours.ChangeMade
						#logThis -msg $orphanDisksOutput	 -ForegroundColor $global:colours.ChangeMade
						$orphanDisksTotalSizeGB = $($orphanDisksOutput | measure -Property SizeGB -Sum).Sum
						if ($orphanDisksOutput.Count -eq 1)
						{
							$themTxt="- There is 1 orphan VMDK on this datastore consuming $($orphanDisksTotalSizeGB) GB. Consider removing it."
						} else {
							$themTxt="- There is $($orphanDisksOutput.Count) orphan VMDKs on this datastore consuming $($orphanDisksTotalSizeGB)GB. Consider removing them."
						}
						$objectIssuesRegister += "$themTxt`n"
						$objectIssuesRegister += $orphanDisksOutput | ConvertTo-Html -Fragment
						$objectIssues++
						#logThis -msg "$objectIssuesRegister" -ForegroundColor $global:colours.ChangeMade
					}
					
					if ($obj.ExtensionData.Summary.MaintenanceMode -ne "normal")
					{
						$objectIssuesRegister += "This datastore is in maintenance mode and cannot be used by $types until it is removed from Maintenance Mode.`n"
						$objectIssues++
					}
					
					if (-not $obj.ExtensionData.Summary.Accessible)
					{
						$objectIssuesRegister += "This datastore is reporting being inaccessible. Ensure it is correctly presented to this environment.`n"
						$objectIssues++
					}
					#check if the alarm actions are enabled on this device
					if (!$obj.ExtensionData.AlarmActionsEnabled)
					{
						$objectIssuesRegister += "The alarm actions on this datastore are disabled. No alarms will be generated for this datastore as a result. Consider re-enabling it.`n"
						$objectIssues++
					}
					
					# is vmfs upgradable
					if ($obj.ExtensionData.info.Vmfs.VmfsUpgradable)
					{
						$objectIssuesRegister += "This datastore is too old ($( $obj.ExtensionData.info.Vmfs.Version)) and upgradable for your environment. Consider upgrading to the latest required version.`n"
						$objectIssues++
					}
			
					$issuesList,$issuesCount = Get-events -obj $obj -myvCenter $myvCenter -startPeriod $eventsStartPeriod -endPeriod $eventsEndPeriod
					$objectIssuesRegister += $issuesList
					$objectIssues += $issuesCount

					
					
					$row | Add-Member -MemberType NoteProperty -Name "Issues" -Value "$objectIssuesRegister"
					
					if ($objectIssues -and $objectIssues -gt 0) 
					{
						
						Write-Output $row
						$totalIssues += $objectIssues
					}
					$deviceIndex++
				}
				if ($dataTable)
				{
					$description += " A total of $totalIssues issues were recorded.`n"					
					$objMetaInfo = @()
					$objMetaInfo +="tableHeader=$title"
					$objMetaInfo +="introduction=$description. "
					$objMetaInfo +="chartable=false"
					$objMetaInfo +="titleHeaderType=h$($headerType+1)"
					$objMetaInfo +="showTableCaption=false"
					$objMetaInfo +="displayTableOrientation=Table" # options are List or Table
					$metricCSVFilename = "$logdir\$($title -replace '\s','_').csv"
					$metricNFOFilename = "$logdir\$($title -replace '\s','_').nfo"
					ExportCSV -table $dataTable -thisFileInstead $metricCSVFilename 
					ExportMetaData -metadata $objMetaInfo -thisFileInstead $metricNFOFilename
					updateReportIndexer -string "$(split-path -path $metricCSVFilename -leaf)"
				}		
			}
			
			"Cluster" {
				#if ($objectIssuesRegister) { Remove-Variable objectIssuesHTMLText }
				#if ($sectionIssuesHTMLText) { Remove-Variable sectionIssuesHTMLText }
				$title = "Clusters"
				$description = "This section reports on $title related issues."	
				$objMetaInfo = @()
				$objMetaInfo +="tableHeader=$title"
				$objMetaInfo +="introduction=$description. "
				$objMetaInfo +="chartable=false"
				$objMetaInfo +="titleHeaderType=h$($headerType+1)"
				$objMetaInfo +="showTableCaption=false"
				$objMetaInfo +="displayTableOrientation=Table" # options are List or Table
				logThis -msg $description
				
				$sectionIssuesHTMLText = $htmlTableHeader
				$totalIssues = 0
				$deviceIndex=1
				$dataTable = $objArray | sort Name | %{
					$obj = $_
					$myvCenter=$srvConnection | ?{$_.Name -eq $obj.vCenter}
					$intervalsSecs = (Get-StatInterval -Server $myvCenter | ?{$_.Name -eq "Past Day"}).SamplingPeriodSecs
					Write-Progress -Activity "$title" -Id 2 -ParentId 1 -Status "$deviceIndex/$($objArray.Count) :- $($myvCenter.Name)\$($obj.Name)..." -PercentComplete (($deviceIndex/$($objArray.Count))*100)
					logthis -msg "`t-$($myvCenter.Name)\$($obj.Name)"
					$objectIssues = 0; $objectIssuesRegister = ""		
					$clear = $false # use to disable the incomplete if statements below	
					$row = New-Object System.Object
					$row | Add-Member -MemberType NoteProperty -Name "Name" -Value $obj.Name.ToUpper()
					$objectIssuesRegister = ""
					$vmhosts = Get-VMHost -Location $obj -Server $myvCenter
					
					# Check if VM has alarms
					$hasAlarm = $($obj.ExtensionData.OverallStatus -eq "red")
					if ($hasAlarm)
					{
						$alarmCount = 0
						$alarmCount = $($obj.ExtensionData.TriggeredAlarmState.Alarm).Count
						$objectIssuesRegister += "The Cluster is reporting having $alarmCount active alarm(s). <ul><u>Alarms</u>`n"
						$obj.ExtensionData.TriggeredAlarmState | %{
							$triggeredAlarmState = $_
							$definitionname = $(Get-AlarmDefinition -id $triggeredAlarmState.Alarm -Server $myvCenter).Name
							$objectIssuesRegister += "<i><u>Name:</u> $definitionname, <u>Date:</u> $(get-date ($triggeredAlarmState.Time)).</i>`n"
							$objectIssues++
						}
						
						if ($hasAlarm) {Remove-Variable hasAlarm}
						if ($alarmCount) { Remove-Variable alarmCount}
					}
					
					if (!$vmhosts)
					{
						$objectIssuesRegister += "Your cluster is empty. Please delete all clusters without ESX Hypervisors.`n"
						$objectIssues++
					}
					
					# Check if HAFailoverLevel is less than 1
					if($obj.HAFailoverLevel -lt 1)
					{					
						$objectIssuesRegister += "Your HA Failover Levels are less than 1 (actual $obj.HAFailoverLevel). You do not have enough resources to cope for a single host failure.`n"
						$objectIssues++
					}
					
					# Check number of HA Slots left (less than 10% left
					if ($obj.HAEnabled)
					{
						$minHaSlotsBeforeScreaming = 10 # Count
						$availalableHASlots = [math]::round($obj.HAAvailableSlots / $obj.HATotalSlots * 100)
						if($availalableHASlots -lt $minHaSlotsBeforeScreaming)
						{					
							$objectIssuesRegister += "Less than $minHaSlotsBeforeScreaming% of your HA Slots are available (actual availability is $availalableHASlots%). You need to review your resource allocation or add another hosts`n"
							$objectIssues++
						}
					}
					
					# IF there are ESX servers, there will be NumCpuCores and other summary information. Calculate the thresholds
					if ($obj.ExtensionData.Host) 
					{						
						# Check number of vCPU if it exceeds 4vCPU per 1Core
						$maxVCPUPerCor = 4
						$totalClusterCores = $obj.ExtensionData.Summary.NumCpuCores * $maxVCPUPerCor
						$totalAllocatvCPU = $(get-vm -Location $obj  -Server $myvCenter | measure -Property "NumCPU" -Sum).Sum
						$threadhold = 90 # Percent
						if ( ($($totalAllocatvCPU / $totalClusterCores * 100) -gt $threadhold) -and ($($totalAllocatvCPU / $totalClusterCores * 100) -lt 100)) # 90% allocation
						{
							$objectIssuesRegister += "Warning, the allocation ration of vCPU is currently at $($totalAllocatvCPU / $totalClusterCores * 100)%. $($totalAllocatvCPU)vCPUs are currently allocated of a recommended maximum of $($totalClusterCores)vCPUs. This leaves a recommended total of $($totalClusterCores - $totalAllocatvCPU)vCPUs left for use. "
							$objectIssuesRegister += "Consider the following course of actions:<ul>- Reduce the number of allocated $types vCPU,<br>- Add more Physical Processors into your existing ESX servers<br>- Add an additional physical server of the same specifications than your current systems.<br></ul>`n"
							$objectIssues++
						} elseif( $($totalAllocatvCPU / $totalClusterCores * 100) -ge 100) # 100% allocation
						{
							$objectIssuesRegister += "Warning, this cluster's allocation of vCPU is has exceeded the recommendation for this Cluster. Your allocation is over by $($totalAllocatvCPU - $totalClusterCores)vCPUs. "
							$objectIssuesRegister += "Consider the following course of actions:<ul>- Reduce the number of allocated $types vCPU,<br>- Add more Physical Processors into your existing ESX servers<br>- Add an additional physical server of the same specifications than your current systems.<br></ul>`n"
							$objectIssues++
						}
					}
					
					# Check if HA Capable but HA is Disabled TO BE COMEPLET
					if (!$obj.HAEnabled -and ($obj.ExtensionData.Host.Count -gt 1))
					{
						$objectIssuesRegister += "VMware HA is Disabled on this cluster despite having $($obj.ExtensionData.Host.Count) ESX Hosts in it. Consider enable it as soon as possible.`n"
						$objectIssues++
					}
					
					# Check if Admission Control is disabled
					if ($obj.HAEnabled -and !$obj.HAAdmissionControlEnabled)
					{
						$objectIssuesRegister += "Although HA is Enabled on this cluster, Admission Control is disabled. Consider re-enabling.`n"
						$objectIssues++
					}
					# Check if Reservations and Limits are set
					$vms = Get-VM * -Location $obj  -Server $myvCenter
					if ($vms)
					{
						$memReservationTotalGB = [Math]::Round($($vms| %{$_.ExtensionData.Config.MemoryAllocation.Reservation} | measure -Sum).Sum,2)
						$cpuReservationsTotalGHz = [Math]::Round($($vms | %{$_.ExtensionData.Config.CpuAllocation.Reservation} | measure -Sum).Sum,2)
						if ($memReservationTotalGB -or $cpuReservationsTotalGHz)
						{
							$allVms = $($vms | ?{$_.ExtensionData.Config.MemoryAllocation.Reservation -ne 0} | Select "Name") + $($vms | ?{$_.ExtensionData.Config.CpuAllocation.Reservation -ne 0} | Select "Name") | select -Property Name -Unique | sort Name
							$objectIssuesRegister += "There are $($allVms.Count) $types in this cluster with some form of Reservation of CPU [$cpuReservationsTotalGHz GHz] and Memory [$memReservationTotalGB GB]. The affected servers are: "
							$objectIssuesRegister += $allVms | ConvertTo-Html -Fragment
							$objectIssuesRegister += "`n"
							$objectIssues++
						}
					}
					# More than 1 host in cluser but check if system has VMotion Enabled
					if ($obj.ExtensionData.Host.Count -gt 1)
					{
						#$vmhosts = get-vmhost * -Location $obj  -Server $myvCenter
						$count = $($vmhosts | %{$_.ExtensionData.Summary.Config.VmotionEnabled} | select -Unique).count
						if ( $count -gt 1)
						{
							$vmhostsWithVMOTIonDisabled = $($vmhosts | ?{$_.ExtensionData.Summary.Config.VmotionEnabled -eq $false})
							$objectIssuesRegister += "$count hosts in this cluster are configured with VMotion disabled. The affected servers are: "
							$indexAffectHosts=0
							$vmhostsWithVMOTIonDisabled | %{
								if ($indexAffectHosts -gt 0)
								{
									$objectIssuesRegister += ", $($_.Name)"
								} else {
									$objectIssuesRegister += "$($_.Name)"
								}
								$indexAffectHosts++
							}
							$objectIssuesRegister += "`n"
							$objectIssues++
						}
					}
					# Chech if NumEffectiveHosts < NumHosts
					if ($obj.ExtensionData.Summary.NumEffectiveHosts -lt $obj.ExtensionData.Summary.NumHosts)
					{					
						$objectIssuesRegister += "Only $($obj.ExtensionData.Summary.NumEffectiveHosts) out of $($obj.ExtensionData.Summary.NumHosts) are active and effective cluster nodes. It means that only $($obj.ExtensionData.Summary.NumHosts - $obj.ExtensionData.Summary.NumEffectiveHosts) are capable of running $types.`n"
						$objectIssues++
					}
					
					# Check if DRS capable Cluster has DRS disabled or set to manual
					
					# Check if memory avg utilisation exceeds 75% and peak utilisation also exceeds 75%
					if ($performance) {Remove-variable performance}
					
					"mem.usage.average","cpu.usage.average" | %{
						$statName=$_
						$warningThreshold=70
						$objStats = $obj | Get-Stat -Server $myvCenter -Stat $statName -Start $performanceStartPeriod -Finish $performanceEndPeriod -MaxSamples $maxsamples -IntervalSecs $intervalsSecs
						if ($objStats)
						{
							$unit=$objStats[0].Unit
							$unitName = $objStats[0].MetricId -split '.',1
							
							$performance = $objStats | measure -Property Value -Average -Maximum					
							$peaks = $objStats | ?{$_.Value -ge $warningThreshold}
							
							if ($peaks) 
							{ 
								$percExceeds=$peaks.Count/$objStats.count*100
								if ((($performance.Average -ge $warningThreshold) -or ($performance.Maximum -ge $warningThreshold)) -and $percExceeds -gt 5)
								{
									$percExceeds=$peaks.Count/$objStats.count*100
									#$objectIssuesRegister += "Over the past $performanceLastDays days, this $type has using on average $([math]::round($performance.Average,2)) $unit of its $((($objStats[0].MetricId) -split '\.')[0].ToUpper()) entitlements, with peaks exceeding $warningThreshold% usage $('{0:N2} %' -f $($peaks.Count/$objStats.count*100)) of the time. The highest peak recorded is $([math]::round($performance.Maximum,2)) %. If these peaks increase in frequency, consider adding more Compute to this cluster. "
									$objectIssuesRegister += "Over the past $performanceLastDays days, this $type has consumed on average $([math]::round($performance.Average,2)) $unit of its resources, with peaks exceeding the warning threashold of $warningThreshold%, $('{0:N2} %' -f $($peaks.Count/$objStats.count*100)) of the time. The highest peak recorded was $([math]::round($performance.Maximum,2)) %. If these peaks increase in frequency, consider adding more resources to this Cluster.`n"
									$objectIssues++
								}
							}
						}
					}
					
					# Check Datastore Counts on each ESX server and compare with the Cluster required number					
					$clusterDSCount = $obj.ExtensionData.Datastore.Count
					if ($clusterDSCount)
					{
						Get-VMHost * -Location $obj  -Server $myvCenter | %{
							if ( $($_.ExtensionData.Datastore + $obj.ExtensionData.Datastore | select -Unique Value).Count -ne $clusterDSCount)
							{								
								$vmhostNames += $_
							}
						}
						if ($vmhostNames)
						{
							$objectIssuesRegister += "The following ESX servers do not have the same number of expected datastores. Verify that all servers are configured the same way. `n"
							$vmhostNames | sort Name | %{
								$objectIssuesRegister += "$_"	
							}
						}
					}
					
					#check if the alarm actions are enabled on this device
					if (!$obj.ExtensionData.AlarmActionsEnabled)
					{
						$objectIssuesRegister += "The alarm actions on this cluster are disabled. No alarms will be generated for this cluster as a result. Consider re-enabling it.`n"
						$objectIssues++
					}
					$issuesList,$issuesCount = Get-events -obj $obj -myvCenter $myvCenter -startPeriod $eventsStartPeriod -endPeriod $eventsEndPeriod
					$objectIssuesRegister += $issuesList
					$objectIssues += $issuesCount

					
					$row | Add-Member -MemberType NoteProperty -Name "Issues" -Value "$objectIssuesRegister"
					
					if ($objectIssues -and $objectIssues -gt 0) 
					{
						
						Write-Output $row
						$totalIssues += $objectIssues
						
					}
					$deviceIndex++
				}
				if ($dataTable)
				{
					$description += " A total of $totalIssues issues were recorded.`n"
					$objMetaInfo = @()
					$objMetaInfo +="tableHeader=$title"
					$objMetaInfo +="introduction=$description. "
					$objMetaInfo +="chartable=false"
					$objMetaInfo +="titleHeaderType=h$($headerType+1)"
					$objMetaInfo +="showTableCaption=false"
					$objMetaInfo +="displayTableOrientation=Table" # options are List or Table
					$metricCSVFilename = "$logdir\$($title -replace '\s','_').csv"
					$metricNFOFilename = "$logdir\$($title -replace '\s','_').nfo"
					ExportCSV -table $dataTable -thisFileInstead $metricCSVFilename 
					ExportMetaData -metadata $objMetaInfo -thisFileInstead $metricNFOFilename
					updateReportIndexer -string "$(split-path -path $metricCSVFilename -leaf)"
				}		
			}
			"Datacenter" {
				$title = "Datacenters"
				$description = "This section reports on $title related issues."				
				$totalIssues = 0
				$deviceIndex=1
				$sectionIssuesHTMLText = $htmlTableHeader
				$dataTable = $objArray | sort Name | %{
					$obj = $_
					$myvCenter=$srvConnection | ?{$_.Name -eq $obj.vCenter}
					Write-Progress -Activity "$title" -Id 2 -ParentId 1 -Status "$deviceIndex/$($objArray.Count) :- $($myvCenter.Name)\$($obj.Name)..." -PercentComplete (($deviceIndex/$($objArray.Count))*100)
					logthis -msg "`t-$($myvCenter.Name)\$($obj.Name)"
					$objectIssues = 0; $objectIssuesRegister = ""
					$clear = $false # use to disable the incomplete if statements below						
					$row = New-Object System.Object
					if ($srvConnection.Count -gt 1)
					{
						$row | Add-Member -MemberType NoteProperty -Name "Name" -Value "$($myvCenter.Name.ToUpper())\$($obj.Name.ToUpper())"
					} else {
						$row | Add-Member -MemberType NoteProperty -Name "Name" -Value $obj.Name.ToUpper()
					}
					
					# Check if VM has alarms
					$hasAlarm = $($obj.ExtensionData.OverallStatus -eq "red")
					if ($hasAlarm)
					{
						$alarmCount = 0
						$alarmCount = $($obj.ExtensionData.TriggeredAlarmState.Alarm).Count
						$obj.ExtensionData.TriggeredAlarmState | %{
							$triggeredAlarmState = $_
							$definitionname = $(Get-AlarmDefinition -id $triggeredAlarmState.Alarm -Server $myvCenter).Name
							$objectIssuesRegister += "The $type reported a $definitionname alarm on $(get-date ($triggeredAlarmState.Time)).`n"
							$objectIssues++
						}
						
						if ($hasAlarm) {Remove-Variable hasAlarm}
						if ($alarmCount) { Remove-Variable alarmCount}
					}
					
					#check if the alarm actions are enabled on this device
					if (!$obj.ExtensionData.AlarmActionsEnabled)
					{
						$objectIssuesRegister += "The alarm actions on this datacenter are disabled. No alarms will be generated for this datacenter as a result. Consider re-enabling it.`n"
						$objectIssues++
					}
					
					
					$issuesList,$issuesCount = Get-events -obj $obj -myvCenter $myvCenter -startPeriod $eventsStartPeriod -endPeriod $eventsEndPeriod
					$objectIssuesRegister += $issuesList
					$objectIssues += $issuesCount

					
					$row | Add-Member -MemberType NoteProperty -Name "Issues" -Value "$objectIssuesRegister"
					
					if ($objectIssues -and $objectIssues -gt 0) 
					{
						
						Write-Output $row
						$totalIssues += $objectIssues
						
					}
					$deviceIndex++
				}
				
				if ($dataTable)
				{
					$description += " A total of $totalIssues issues were recorded.`n"
					$objMetaInfo = @()
					$objMetaInfo +="tableHeader=$title"
					$objMetaInfo +="introduction=$description. "
					$objMetaInfo +="chartable=false"
					$objMetaInfo +="titleHeaderType=h$($headerType+1)"
					$objMetaInfo +="showTableCaption=false"
					$objMetaInfo +="displayTableOrientation=Table" # options are List or Table
					$metricCSVFilename = "$logdir\$($title -replace '\s','_').csv"
					$metricNFOFilename = "$logdir\$($title -replace '\s','_').nfo"
					ExportCSV -table $dataTable -thisFileInstead $metricCSVFilename 
					ExportMetaData -metadata $objMetaInfo -thisFileInstead $metricNFOFilename
					updateReportIndexer -string "$(split-path -path $metricCSVFilename -leaf)"
				}				
			}
			default {
				return
			}
		}
		$deviceTypeIndex++
	}
}

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}