#param([string]$global:logDir=".\output")

########################################################################
# This file contains a collection of functions which can be imported into each script to minimise foot print and allow 
# better code managemnt
#
# Maintained by: teiva.rodiere@gmail.com
# Version: 12.10 - 7/11/2015
# Usage: in any of your scripts, just add this line "Import-Module <path>\vmwareModules.psm1"
#

# Get Issues
# Syntaxt
#
# Example 1 : to get objects related to a guestName VM
#		$objectsArray = @(
#			@($global:srvConnection | %{ $vcenterName=$_.Name; Get-VM $guestName -Server $_ | Get-Cluster -server $_ | %{ $obj=$_; $obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenterName; $obj} }),
#			@($global:srvConnection | %{ $vcenterName=$_.Name; Get-VM $guestName -Server $_ | Get-vmhost -server $_ | %{ $obj=$_; $obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenterName; $obj} }),
#			@($global:srvConnection | %{ $vcenterName=$_.Name; Get-VM $guestName -Server $_ | %{ $obj=$_; $obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenterName; $obj} }),
#			@($global:srvConnection | %{ $vcenterName=$_.Name; Get-VM $guestName -Server $_ | get-datacenter -server $_ | %{ $obj=$_; $obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenterName; $obj} }),
#			@($global:srvConnection | %{ $vcenterName=$_.Name; Get-VM $guestName -Server $_ | get-datastore -server $_ | %{ $obj=$_; $obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenterName; $obj} })
#		)
#		$results = getIssues -objectsArray $objectsArray -returnDataOnly $true -performanceLastDays 7  -headerType $($headerType+2) -showPastMonths $lastMonths
#
#
# Example 2 : Get Everything then 
#  $objectsArray = @(
#		@($srvConnection | %{ $vcenterName=$_.Name; get-cluster * -server $_ | %{ $obj=$_; $obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenterName; $obj} }),
#		@($srvConnection | %{ $vcenterName=$_.Name; get-vmhost * -server $_ | %{ $obj=$_; $obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenterName; $obj} }),
#		@($srvConnection | %{ 
#			$vcenterName=$_.Name; 
#			$targetVMs = get-vm * -server $_ 
#			$targetVMs | %{ $obj=$_; $obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenterName; 		
#			if ($vmsToCheck)
#			{
#				if ($vmsToCheck.Contains($obj.Name))
#				{
#					$obj
#				}
#			} else {
#				$obj 
#			}
#		} }),
#		@($srvConnection | %{ $vcenterName=$_.Name; get-datacenter * -server $_ | %{ $obj=$_; $obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenterName; $obj} }),
#		@($srvConnection | %{ $vcenterName=$_.Name; get-datastore * -server $_ | %{ $obj=$_; $obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenterName; $obj} })
#	)
#	$results = getIssues -objectsArray $objectsArray -returnDataOnly $true -performanceLastDays 7  -headerType 2 -showPastMonths 3

function setLoggingDirectory([string]$dirPath)
{
	if (!$dirPath)
	{
		$global:logDir=".\output"
	} else {
		$global:logDir=$dirPath
	}
}

function getIssues(
	[Parameter(Mandatory=$true)][Object]$objectsArray,
	[Parameter(Mandatory=$true)][Object]$srvconnection,
	[bool]$returnDataOnly=$true,
	[int]$performanceLastDays=7,
	[string]$lastDayOfReportOveride,
	[int]$showPastMonths=3,
	[int]$maxsamples = [int]::MaxValue,
	[int]$headerType=1,
	[string]$li="",
	$ensureTheseFieldsAreFieldIn
	
)		
{
	if ($lastDayOfReportOveride)
	{
		$performanceEndPeriod=Get-Date $lastDayOfReportOveride
	} else {
		$performanceEndPeriod=Get-Date 
	}
	$performanceStartPeriod = $performanceEndPeriod.AddDays(-$performanceLastDays)
	$eventsEndPeriod = $performanceEndPeriod
	$eventsStartPeriod = $performanceEndPeriod.AddMOnths(-$showPastMonths)

	if ($returnDataOnly)
	{
		$resultsIssuesRegisterTable = @{}
	}
	$vmtoolsMatrix = getVMwareToolsVersionMatrix
	$enable = $true
	
	if ($enable)
	{
		logThis -msg "######################################################################" -ForegroundColor Green
		logThis -msg "Checking Individual Systems / component issues and action items"  -ForegroundColor Green
		$title= "Systems Issues and Actions"
		#$htmlPage += "$(header2 $title)"
		$deviceTypeIndex=1
		$objectsArray | %{
			if ($_)
			{
				$objArray = $_
				
				$firstObj = $objArray | select -First 1
				$type = $firstObj.GetType().Name.Replace("Impl","")				
				Write-Progress -Activity "Processing report" -Id 1 -Status "$deviceTypeIndex/$($objectsArray.Count) :- $type..." -PercentComplete  (($deviceTypeIndex/$($objectsArray.Count))*100)
				$index=0;
				logThis -msg "[`t`t$type`t`t]" -foregroundcolor Green
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
							$myvCenter = $srvconnection | ?{$_.Name -eq $obj.vCenter}
							$intervalsSecs = (Get-StatInterval -Server $myvCenter | ?{$_.Name -eq "Past Day"}).SamplingPeriodSecs
							Write-Progress -Activity "$title" -Id 2 -ParentId 1 -Status "$deviceIndex/$($objArray.Count) :- $($myvCenter.Name)\$($obj.Name)..." -PercentComplete (($deviceIndex/$($objArray.Count))*100)
							logthis -msg "`t-$($myvCenter.Name)\$($obj.Name)"
							$objectIssues = 0; $objectIssuesRegister = ""
							$clear = $false # use to disable the incomplete if statements below	
							$row = New-Object System.Object
							if ($srvconnection.Count -gt 1)
							{
								$row | Add-Member -MemberType NoteProperty -Name "Name" -Value "$($myvCenter.Name.ToUpper())\$($obj.Name.ToUpper())"
							} else {
								$row | Add-Member -MemberType NoteProperty -Name "Name" -Value $obj.Name.ToUpper()
							}
							if ($obj.ExtensionData.Runtime.ConnectionState -ne "connected")
							{
								$objectIssuesRegister += "$($li)Appears disconnected from within the vCenter inventory.`n"
								$objectIssues++
							}
							# Check if VM does not have Alarm Actions enabled 				
							if (!$obj.ExtensionData.AlarmActionsEnabled)
							{
								$objectIssuesRegister += "$($li)Is not monitored by vCenter because its ""Alarms Actions"" were manualy disabled. Re-enable as soon as possible.`n"
								$objectIssues++
							}
							# Check if Question mark. Warn if it is
							if ($obj.ExtensionData.Runtime.Question)
							{
								$objectIssuesRegister += "$($li)Is awaiting manual intervention by an administrator.`n"
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
									$objectIssuesRegister += "$($li)Is reporting a ""$definitionname"" alarm on $(get-date ($triggeredAlarmState.Time)).`n"
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
									$objectIssuesRegister += "$($li)The current guest name ""$guestName"" does not match the virtual machine name ""$($obj.Name)"".`n"
									$objectIssues++
								} 
							}
							# Check if tool installer is mounted. Warn if it is
							if ($obj.ExtensionData.Runtime.ToolsInstallerMounted)
							{
								$objectIssuesRegister += "$($li)Has its CD-ROM connected to the VMware Tools Installer. Disconnect it as soon possible to allow DRS to work effectively.`n"
								$objectIssues++
							}

							# Check for VMware Tools Running
							$objwareToolsNotRunning = $obj.ExtensionData.Guest.ToolsRunningStatus -ne "guestToolsRunning"
							if ($objwareToolsNotRunning)
							{
								$objectIssuesRegister += "$($li)Its VMware Tools are not running, check the in Guest.`n"
								$objectIssues++
							}
							# Check for VMware Tools installed
							$objwareToolssNotInstalled = $obj.ExtensionData.Guest.ToolsVersionStatus -eq "guestToolsNotInstalled" -or $obj.ExtensionData.Guest.ToolsVersionStatus -eq "guestToolsNeedUpgrade"
							if ($objwareToolsNotInstalled)
							{						
								$objectIssuesRegister += "$($li)Install or upgrade the VMware Tools because they are either not installed or too old.`n"
								$objectIssues++
							} else {
								if ( ([int]$($obj.Version -replace 'v') + 0) -le 4 ) {
									$objectIssuesRegister += "$($li)The VM hardware version does not support VMware VDAP which will impact Backups.`n"
									$objectIssues++
								}
							}
							# check file system space
							if ($obj.ExtensionData.Guest.ToolsRunningStatus -eq "guestToolsRunning") 
							{
								if ($obj.ExtensionData.Guest.Disk)
								{
									$obj.ExtensionData.Guest.Disk | %{
										$freeGB = "{0:N2} GB" -f $($_.FreeSpace / 1gb)
										# Issue with attempt to device by zero -- need to resolve -- teiva
										$usedPerc = 100 - ($_.FreeSpace / $_.Capacity * 100)
										
										if ($usedPerc -gt 95)
										{
											$objectIssuesRegister += "$($li)Volume ""$($_.DiskPath)"" is " + $("{0:N2} %" -f $usedPerc) +" used ($freeGB free).`n"
											$objectIssues++ 
										}
									}
								} else {
									$objectIssuesRegister += "$($li)Unable to read Filesystem utilisation.`n"
									$objectIssues++ 
								}
							} 
							
							# Check for snapshots
							$objhasSnapshot = $obj.ExtensionData.Snapshot
							if ($objhasSnapshot)
							{
								$snapshots = Get-Snapshot -VM $obj -Server $myvCenter
								#$objectIssuesRegister += "$($li)This VM has $($snapshots.Count) VM Snapshots. Please delete as soon as possible.`n"
								#$objectIssuesRegister += "$($li)<table><th>Snapshot Name</th><th>Description</th><th>Age</th><th>SizeGB</th><th>Taken by</th><th>PowerState Before Snapshot</th><th>Active One</th>"
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
									$objectIssuesRegister += "$($li)`tA snapshot called ""$($snapshot.Name)"" taken $($mydatestring.Days) days $($mydatestring.hours) hours ago by ""$SnapUser"" is still active. It is consuming $([math]::round($snapshot.SizeGB,2)) GB.`n"
							       	#Write-Output $Snapshots
								}
								#$objectIssuesRegister += "$($li)<ul>`n"
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
									$objectIssuesRegister += "$($li)This VM has $($hasThinDisks.Count) thinly deployed disks. Reconsider using Thick disks instead.`n"
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
								$objectIssuesRegister += "$($li)Is running an old $friendlyName Hardware Version ""$($obj.Version)"". The latest supported version by the host is ""$latestVMHardwareVersion"".`n"
								$objectIssues++
							}
							# Check VMs with memory balooning
							if ($obj.PowerState -eq "PoweredOn")
							{
								# Check performance
								#$objectIssuesRegister=""
								"mem.vmmemctl.average","mem.usage.average","cpu.usage.average","mem.swapped.average" | %{
								#"mem.usage.average" | %{
									$statName=$_
									$warningThreshold=70
									$objStats = $obj | Get-Stat -Server $myvCenter -Stat $statName #-Start $performanceStartPeriod -Finish $performanceEndPeriod -MaxSamples $maxsamples -IntervalSecs $intervalsSecs
									if ($objStats)
									{
										$unit=$objStats[0].Unit
										$unitName = $objStats[0].MetricId -split '.',1
										if ($statName -eq "mem.vmmemctl.average")
										{
											$whatIsBeenUpTo="balooning ($statName)"											
										} elseif ($statName -eq "mem.swapped.average")
										{
											$whatIsBeenUpTo="swapping ($statName)"
										} else {
											$whatIsBeenUpTo="consuming ($statName)"
										}
										$performance = $objStats | measure -Property Value -Average -Maximum					
										$peaks = $objStats | ?{$_.Value -ge $warningThreshold}										
										if ($peaks) 
										{ 
											#if ($unit -eq "%")
											#{
												$highestPeaks = $("{0:N2} $unit" -f $performance.Maximum)
											#} else {
											#	$highestPeaks = 
											#}
											$percExceeds=$peaks.Count/$objStats.count*100
											if ((($performance.Average -ge $warningThreshold) -or ($performance.Maximum -ge $warningThreshold)) -and $percExceeds -gt 5)
											{
												#$objectIssuesRegister += "$($li)A potential $((($objStats[0].MetricId) -split '\.')[0].ToUpper()) bottleneck was identified which could cause poor performance. It has been $whatIsBeenUpTo on average $(getsize -unit $($unit) -val $($performance.Average)) of its resources over the past $performanceLastDays days with peaks exceeding the warning threshold of $warningThreshold%, $('{0:N2} %' -f $($peaks.Count/$objStats.count*100)) of the time during the reporting period. The highest recorded peak was $highestPeaks.`n"
												$objectIssuesRegister += "$($li)A potential $((($objStats[0].MetricId) -split '\.')[0].ToUpper()) bottleneck was identified which could cause poor performance. It has been $whatIsBeenUpTo on average $($performance.Average) of its resources over the past $performanceLastDays days with peaks exceeding the warning threshold of $warningThreshold%, $('{0:N2} %' -f $($peaks.Count/$objStats.count*100)) of the time during the reporting period. The highest recorded peak was $highestPeaks.`n"
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
									$guestAdapater = $_
									if ($guestAdapater.DeviceConfigId)
									{
										$guestAdapaterId=$guestAdapater.DeviceConfigId
									
										$idToMatch="$($obj.Id)/$guestAdapaterId"
										#$idToMatch
										$adapter=$obj.NetworkAdapters | ?{$_.id -eq $idToMatch }
										$adapterMAC=$adapter.MacAddress.ToUpper()
										$guestAdapterMAC=$($guestAdapater.MacAddress.ToUpper())
										#logThis -msg "GuestMAC=$guestMAC, AdapterMAC=$adapterMAC"
										if ($guestAdapterMAC -ne $adapterMAC) {
											$objectIssuesRegister += "$($li)""$($adapter.Name)""'s MAC Address ""$adapterMAC"" differs from the Guest MAC address ""$guestAdapterMAC"".`n"
											$objectIssues++
										}
									}
								}
							}

							# Check VMs with MemMB Reservations
							$objHasResourceLimits = $obj.ExtensionData.ResourceConfig.MemoryAllocation.Limit -lt ( $obj.MemoryMB + ($obj.ExtensionData.Runtime.MemoryOverhead / 1024 / 1024) )
							if ($objHasResourceLimits -and ($objHasResourceLimits -ne "-1"))
							{
								$objectIssuesRegister += "$($li)Has a Hard Memory Limits placed on it. It is allocated $($obj.MemoryMB)MB whilst hard limited to $($obj.ExtensionData.ResourceConfig.MemoryAllocation.Limit) MB. It could eventually cause it to swap.`n"
								$objectIssues++
							}
							
							# If the VM has reservations that exceed the requirement of the VM itself (memory MB)
							$objHasResourceReservations = $obj.ExtensionData.ResourceConfig.MemoryAllocation.Reservation -gt ( $obj.MemoryMB + ($obj.ExtensionData.Runtime.MemoryOverhead / 1024 / 1024) )
							if ($objHasResourceReservations -and ($objHasResourceReservations -ne "-1"))
							{
								$value = ($obj.MemoryMB + ($obj.ExtensionData.Runtime.MemoryOverhead / 1024 / 1024)) - $obj.ExtensionData.ResourceConfig.MemoryAllocation.Reservation
								if ($value -lt 0)
								{
									$objectIssuesRegister += "$($li)Has a memory reservation that exceeds its allocation, essentially wasting reserve memory. It is allocated $($obj.MemoryMB) MB and reserved $value MB.`n"
									$objectIssues++
									
								}
								Remove-Variable value
								Remove-Variable objHasResourceReservations
							}
							
							
							if ($ensureTheseFieldsAreFieldIn)
							{								
								$ensureTheseFieldsAreFieldIn | %{
									$attributeName=$_
									logThis -msg "`t`tChecking for Attribute information: $attributeName"
									$attibute = Get-CustomAttribute -Name $attributeName -Server $myvCenter
									if ($attibute)
									{
										$value = ($obj.CustomFields | ?{$_.Key -eq $($attibute.Name)}).Value
										if (!$value)
										{
											$objectIssuesRegister += "$($li)Field ""$attributeName"" for this server is empty.`n"
											$objectIssues++
										} else {
											if ($attributeName -like "*date*")
											{
												$lastBackupDate=get-date (($obj.CustomFields | ?{$_.Key -eq $($attibute.Name)}).Value)
												if ($lastBackupDate -lt $performanceStartPeriod)
												{
													#$lastBackupDate
													$objectIssuesRegister += "$($li)The date in field ""$attributeName"" of $lastBackupDate and is older than $performanceLastDays days.`n"
													$objectIssues++
												}
											}
										}
										
									}
								}
							}
							
							#teiva
							$issuesList,$issuesCount = Get-events -obj $obj -myvCenter $myvCenter -startPeriod $eventsStartPeriod -endPeriod $eventsEndPeriod
							$objectIssuesRegister += $issuesList
							$objectIssues += $issuesCount
							
							$row | Add-Member -MemberType NoteProperty -Name "Issues" -Value $objectIssuesRegister
							
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
							$metricCSVFilename = "$global:logDir\$($title -replace '\s','_').csv"
							$metricNFOFilename = "$global:logDir\$($title -replace '\s','_').nfo"
							if ($returnDataOnly)
							{
								$resultsIssuesRegisterTable["$type"] = @{}
								$resultsIssuesRegisterTable["$type"]["NFO"]=$objMetaInfo
								$resultsIssuesRegisterTable["$type"]["DataTable"]=$dataTable
								$resultsIssuesRegisterTable["$type"]["IssuesCount"]=$objectIssues
								$resultsIssuesRegisterTable["$type"]["Title"]=$title
								$resultsIssuesRegisterTable["$type"]["Introduction"]=$description
							} 
						}				
					}
					########################
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
							$myvCenter=$srvconnection | ?{$_.Name -eq $obj.vCenter}
							Write-Progress -Activity "$title" -Id 2 -ParentId 1 -Status "$deviceIndex/$($objArray.Count) :- $($myvCenter.Name)\$($obj.Name)..." -PercentComplete (($deviceIndex/$($objArray.Count))*100)
							logthis -msg "`t-$($myvCenter.Name)\$($obj.Name)"
							$objectIssues = 0; $objectIssuesRegister = ""
							$clear = $false # use to disable the incomplete if statements below				
							$row = New-Object System.Object
							if ($srvconnection.Count -gt 1)
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
									$objectIssuesRegister += "$($li)It reported a ""$definitionname"" alarm on $(get-date ($triggeredAlarmState.Time)).`n"
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
											#$objectIssuesRegister += "$($li)Over the past $performanceLastDays days, this $friendlyName has using on average $([math]::round($performance.Average,2)) $unit of its $((($objStats[0].MetricId) -split '\.')[0].ToUpper()) entitlements, with peaks exceeding $warningThreshold% usage $('{0:N2} %' -f $($peaks.Count/$objStats.count*100)) of the time. The highest peak recorded is $([math]::round($performance.Maximum,2)) %. If these peaks increase in frequency, consider adding more resources to this $friendlyName. "
											if ($statName -eq "mem.vmmemctl.average")
											{
												$whatIsBeenUpTo="balooning"
											} else {
												$whatIsBeenUpTo="consuming"
											}
											$objectIssuesRegister += "$($li)A potential $((($objStats[0].MetricId) -split '\.')[0].ToUpper()) bottleneck was identified which could cause poor performance. It as been $whatIsBeenUpTo on average $([math]::round($performance.Average,2)) $unit of its entitlements over the past $performanceLastDays days with peaks exceeding the warning threshold of $warningThreshold%, $('{0:N2} %' -f $($peaks.Count/$objStats.count*100)) of the time. The highest peak recorded was $([math]::round($performance.Maximum,2))%.`n"
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
								#logThis -msg "Parent Object: $($parent.Name)" -ForegroundColor Yellow -BackgroundColor Red
								#logThis -msg "Cluster nodes: $($clusterNodes.Count)" -ForegroundColor Yellow -BackgroundColor Red
								# Check to see if the ESX servers in the same cluster have the same amount of datastores that the cluster has 
								$datastoreCount = (get-datastore -VMHost $clusterNodes -Server $myvCenter).Count
								if ($obj.DatastoreIdList.Count -ne $datastoreCount)
								{
									$objectIssuesRegister += "$($li)This host belongs to a cluster ""$($parent.Name)"" which has a total of $datastoreCount datastores but this server only has $($obj.DatastoreIdList.Count) datastores mapped to it.`n"
									$objectIssues++
									Remove-Variable datastoreCount
								}
								
								$stdClustersVSwitchesCount = ($clusterNodes | Get-VirtualSwitch  -Server $myvCenter | select Name -unique).Count
								$stdVSwitchesCount = ($obj | Get-VirtualSwitch  -Server $myvCenter | select Name -unique).Count
								if ($stdVSwitchesCount -ne $stdClustersVSwitchesCount)
								{
									$objectIssuesRegister += "$($li)This host belongs to a cluster ""$($parent.Name)"" which has a total of $stdClustersVSwitchesCount Switches but this server only has $stdVSwitchesCount Switches mapped to it.`n"
									$objectIssues++
									Remove-Variable stdClustersVSwitches
									Remove-Variable  stdVSwitches
								}
								
								# Check the same port group count
								$stdClusterVPGCount = ($clusterNodes | Get-VirtualPortGroup  -Server $myvCenter| select Name -unique).Count
								$stdVPGCount = ($obj | Get-VirtualPortGroup  -Server $myvCenter| select Name -unique).Count
								if ($stdVPGCount -ne $stdClusterVPGCount)
								{
									$objectIssuesRegister += "$($li)This host belongs to a cluster ""$($parent.Name)"" which has a total of $stdClusterVPGCount Port Groups but this server only has $stdVPGCount Port Group mapped to it.`n"
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
											$objectIssuesRegister += "$($li)This host uses the same VMkernel Interface ""$($_.Name)"" for Hypervisor Management and VMotion. It is recommended to separate the roles onto dedicated interfaces.`n"
											$objectIssues++
										}
										if ($vmkernelNics.ManagementTrafficEnabled -and $_.FaultToleranceLoggingEnabled)
										{
											$objectIssuesRegister += "$($li)This host uses the same VMkernel Interface ""$($_.Name)"" for Hypervisor Management and Fault Tolerance Traffic. It is recommended to separate the roles onto dedicated interfaces.`n"
											$objectIssues++
										}
										if ($vmkernelNics.ManagementTrafficEnabled -and $_.VsanTrafficEnabled)
										{
											$objectIssuesRegister += "$($li)This host uses the same VMkernel Interface ""$($_.Name)"" for Hypervisor Management and VSAN Traffic. It is recommended to separate the roles onto dedicated interfaces.`n"
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
								$objectIssuesRegister += "$($li)This host supports a higher EVC mode ($($obj.ExtensionData.Summary.MaxEVCModeKey) than the cluster is currently enabled for ($($obj.ExtensionData.Summary.CurrentEVCModeKey)).`n"
								$objectIssues++
							}
							
							# Check if a reboot is required
							if ($obj.ExtensionData.Summary.RebootRequired)
							{
								$objectIssuesRegister += "$($li)This server is pending a reboot.`n"
								$objectIssues++
							}
							
							#check if the alarm actions are enabled on this device
							if (!$obj.ExtensionData.AlarmActionsEnabled)
							{
								$objectIssuesRegister += "$($li)The alarm actions on this system are disabled. No alarms will be generated for this system as a result. Consider re-enabling it.`n"
								$objectIssues++
							}
							
											
							$issuesList,$issuesCount = Get-events -obj $obj -myvCenter $myvCenter -startPeriod $eventsStartPeriod -endPeriod $eventsEndPeriod
							$objectIssuesRegister += $issuesList
							$objectIssues += $issuesCount

							
							$row | Add-Member -MemberType NoteProperty -Name "Issues" -Value $objectIssuesRegister
							
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
							$metricCSVFilename = "$global:logDir\$($title -replace '\s','_').csv"
							$metricNFOFilename = "$global:logDir\$($title -replace '\s','_').nfo"
							if ($returnDataOnly)
							{
								$resultsIssuesRegisterTable["$type"] = @{}
								$resultsIssuesRegisterTable["$type"]["NFO"]=$objMetaInfo
								$resultsIssuesRegisterTable["$type"]["DataTable"]=$dataTable
								$resultsIssuesRegisterTable["$type"]["IssuesCount"]=$objectIssues
								$resultsIssuesRegisterTable["$type"]["Title"]=$title
								$resultsIssuesRegisterTable["$type"]["Introduction"]=$description
							} 					
						}		
					}
					
					
					########################
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
							$myvCenter=$srvconnection | ?{$_.Name -eq $obj.vCenter}
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
								$objectIssuesRegister += "$($li)The Datastore is reporting having $alarmCount active alarm(s). <ul><u>Alarms</u>`n"
								$obj.ExtensionData.TriggeredAlarmState | %{
									$triggeredAlarmState = $_
									$definitionname = $(Get-AlarmDefinition -id $triggeredAlarmState.Alarm  -Server $myvCenter).Name
									$objectIssuesRegister += "$($li)<i><u>Name:</u> $definitionname, <u>Date:</u> $(get-date ($triggeredAlarmState.Time)).</i>`n"
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
								$objectIssuesRegister += "$($li)There is only $freeSpacePerc % of freesace ($freeSpaceGB GB) on this datastore `n"
								$objectIssues++
							}					
							# Check if there are Non VMFS 5 Volumes
							
							# Check for growth
							#$dataTable = .\Datastore_Usage_Report.ps1 -srvConnection $srvconnection  -includeThisMonthEvenIfNotFinished $false -showPastMonths $showPastMonths -datastore $obj -vcenter $myvCenter -returnTableOnly $true
							
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
							logthis -msg "Searching for Folders - BEFORE"
							#$searchResult = $dsBrowser.SearchDatastoreSubFolders($rootPath, $searchSpec)
							logthis -msg "Searching for Folders - AFTER"
							if ($orphanDisksOutput) { Remove-variable orphanDisksOutput }
							$orphanDisksOutput = @()
							foreach ($folder in $searchResult)
							{
								echo "Searching for Folders"
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
								logThis -msg "------------" -ForegroundColor Blue
								#logThis -msg $orphanDisksOutput	 -ForegroundColor Blue
								$orphanDisksTotalSizeGB = $($orphanDisksOutput | measure -Property SizeGB -Sum).Sum
								if ($orphanDisksOutput.Count -eq 1)
								{
									$themTxt="There is 1 orphan VMDK on this datastore consuming $($orphanDisksTotalSizeGB) GB. Consider removing it."
								} else {
									$themTxt="There is $($orphanDisksOutput.Count) orphan VMDKs on this datastore consuming $(getsize -unit 'GB' -val $orphanDisksTotalSizeGB). Consider removing them."
								}
								$objectIssuesRegister += "$($li)$themTxt`n"
								$objectIssuesRegister += $orphanDisksOutput # | ConvertTo-Html -Fragment
								$objectIssues++
								#logThis -msg "$objectIssuesRegister" -ForegroundColor Blue
							}
							
							if ($obj.ExtensionData.Summary.MaintenanceMode -ne "normal")
							{
								$objectIssuesRegister += "$($li)This datastore is in maintenance mode and cannot be used by $types until it is removed from Maintenance Mode.`n"
								$objectIssues++
							}
							
							if (-not $obj.ExtensionData.Summary.Accessible)
							{
								$objectIssuesRegister += "$($li)This datastore is reporting being inaccessible. Ensure it is correctly presented to this environment.`n"
								$objectIssues++
							}
							#check if the alarm actions are enabled on this device
							if (!$obj.ExtensionData.AlarmActionsEnabled)
							{
								$objectIssuesRegister += "$($li)The alarm actions on this datastore are disabled. No alarms will be generated for this datastore as a result. Consider re-enabling it.`n"
								$objectIssues++
							}
							
							# is vmfs upgradable
							if ($obj.ExtensionData.info.Vmfs.VmfsUpgradable)
							{
								$objectIssuesRegister += "$($li)This datastore is too old ($( $obj.ExtensionData.info.Vmfs.Version)) and upgradable for your environment. Consider upgrading to the latest required version.`n"
								$objectIssues++
							}
					
							$issuesList,$issuesCount = Get-events -obj $obj -myvCenter $myvCenter -startPeriod $eventsStartPeriod -endPeriod $eventsEndPeriod
							$objectIssuesRegister += $issuesList
							$objectIssues += $issuesCount

							
							
							$row | Add-Member -MemberType NoteProperty -Name "Issues" -Value $objectIssuesRegister
							
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
							$metricCSVFilename = "$global:logDir\$($title -replace '\s','_').csv"
							$metricNFOFilename = "$global:logDir\$($title -replace '\s','_').nfo"
							if ($returnDataOnly)
							{
								$resultsIssuesRegisterTable["$type"] = @{}
								$resultsIssuesRegisterTable["$type"]["NFO"]=$objMetaInfo
								$resultsIssuesRegisterTable["$type"]["DataTable"]=$dataTable
								$resultsIssuesRegisterTable["$type"]["IssuesCount"]=$objectIssues
								$resultsIssuesRegisterTable["$type"]["Title"]=$title
								$resultsIssuesRegisterTable["$type"]["Introduction"]=$description
							} 
						}		
					}
					########################
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
							$myvCenter = $srvconnection | ?{$_.Name -eq $obj.vCenter}							
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
								$objectIssuesRegister += "$($li)The Cluster is reporting having $alarmCount active alarm(s).`nAlarms:`n"
								$obj.ExtensionData.TriggeredAlarmState | %{
									$triggeredAlarmState = $_
									$definitionname = $(Get-AlarmDefinition -id $triggeredAlarmState.Alarm -Server $myvCenter).Name
									$objectIssuesRegister += "$($li)<i><u>Name:</u> $definitionname, <u>Date:</u> $(get-date ($triggeredAlarmState.Time)).</i>`n"
									$objectIssues++
								}
								
								if ($hasAlarm) {Remove-Variable hasAlarm}
								if ($alarmCount) { Remove-Variable alarmCount}
							}
							
							if (!$vmhosts)
							{
								$objectIssuesRegister += "$($li)Your cluster is empty. Please delete all clusters without ESX Hypervisors.`n"
								$objectIssues++
							}
							
							# Check if HAFailoverLevel is less than 1
							if($obj.HAFailoverLevel -lt 1)
							{					
								$objectIssuesRegister += "$($li)Your HA Failover Levels are less than 1 (actual $obj.HAFailoverLevel). You do not have enough resources to cope for a single host failure.`n"
								$objectIssues++
							}
							
							# Check number of HA Slots left (less than 10% left
							if ($obj.HAEnabled)
							{
								$minHaSlotsBeforeScreaming = 10 # Count
								$availalableHASlots = [math]::round($obj.HAAvailableSlots / $obj.HATotalSlots * 100)
								if($availalableHASlots -lt $minHaSlotsBeforeScreaming)
								{					
									$objectIssuesRegister += "$($li)Less than $minHaSlotsBeforeScreaming% of your HA Slots are available (actual availability is $availalableHASlots%). You need to review your resource allocation or add another hosts`n"
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
									$objectIssuesRegister += "$($li)Warning, the allocation ration of vCPU is currently at $($totalAllocatvCPU / $totalClusterCores * 100)%. $($totalAllocatvCPU)vCPUs are currently allocated of a recommended maximum of $($totalClusterCores)vCPUs. This leaves a recommended total of $($totalClusterCores - $totalAllocatvCPU)vCPUs left for use. `n"
									$objectIssuesRegister += "$($li)Consider the following course of actions:<ul>- Reduce the number of allocated $types vCPU,<br>- Add more Physical Processors into your existing ESX servers<br>- Add an additional physical server of the same specifications than your current systems.<br></ul>`n"
									$objectIssues++
								} elseif( $($totalAllocatvCPU / $totalClusterCores * 100) -ge 100) # 100% allocation
								{
									$objectIssuesRegister += "$($li)Warning, this cluster's allocation of vCPU is has exceeded the recommendation for this Cluster. Your allocation is over by $($totalAllocatvCPU - $totalClusterCores)vCPUs. `n"
									$objectIssuesRegister += "$($li)Consider the following course of actions:<ul>- Reduce the number of allocated $types vCPU,<br>- Add more Physical Processors into your existing ESX servers<br>- Add an additional physical server of the same specifications than your current systems.<br></ul>`n"
									$objectIssues++
								}
							}
							
							# Check if HA Capable but HA is Disabled TO BE COMEPLET
							if (!$obj.HAEnabled -and ($obj.ExtensionData.Host.Count -gt 1))
							{
								$objectIssuesRegister += "$($li)VMware HA is Disabled on this cluster despite having $($obj.ExtensionData.Host.Count) ESX Hosts in it. Consider enable it as soon as possible.`n"
								$objectIssues++
							}
							
							# Check if Admission Control is disabled
							if ($obj.HAEnabled -and !$obj.HAAdmissionControlEnabled)
							{
								$objectIssuesRegister += "$($li)Although HA is Enabled on this cluster, Admission Control is disabled. Consider re-enabling.`n"
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
									$objectIssuesRegister += "$($li)There are $($allVms.Count) $types in this cluster with some form of Reservation of CPU [$cpuReservationsTotalGHz GHz] and Memory [$memReservationTotalGB GB]. The affected servers are: `n"
									#$objectIssuesRegister += $allVms | ConvertTo-Html -Fragment
									$objectIssuesRegister += $allVms | ConvertTo-Html -Fragment
									$objectIssuesRegister += "$($li)`n"
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
									$objectIssuesRegister += "$($li)$count hosts in this cluster are configured with VMotion disabled. The affected servers are: "
									$indexAffectHosts=0
									$vmhostsWithVMOTIonDisabled | %{
										if ($indexAffectHosts -gt 0)
										{
											$objectIssuesRegister += "$($li), $($_.Name)"
										} else {
											$objectIssuesRegister += "$($li)$($_.Name)"
										}
										$indexAffectHosts++
									}
									$objectIssuesRegister += "$($li)`n"
									$objectIssues++
								}
							}
							# Chech if NumEffectiveHosts < NumHosts
							if ($obj.ExtensionData.Summary.NumEffectiveHosts -lt $obj.ExtensionData.Summary.NumHosts)
							{					
								$objectIssuesRegister += "$($li)Only $($obj.ExtensionData.Summary.NumEffectiveHosts) out of $($obj.ExtensionData.Summary.NumHosts) are active and effective cluster nodes. It means that only $($obj.ExtensionData.Summary.NumHosts - $obj.ExtensionData.Summary.NumEffectiveHosts) are capable of running $types.`n"
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
											#$objectIssuesRegister += "$($li)Over the past $performanceLastDays days, this $type has using on average $([math]::round($performance.Average,2)) $unit of its $((($objStats[0].MetricId) -split '\.')[0].ToUpper()) entitlements, with peaks exceeding $warningThreshold% usage $('{0:N2} %' -f $($peaks.Count/$objStats.count*100)) of the time. The highest peak recorded is $([math]::round($performance.Maximum,2)) %. If these peaks increase in frequency, consider adding more Compute to this cluster. `n"
											$objectIssuesRegister += "$($li)Over the past $performanceLastDays days, this $type has consumed on average $([math]::round($performance.Average,2)) $unit of its resources, with peaks exceeding the warning threshold of $warningThreshold%, $('{0:N2} %' -f $($peaks.Count/$objStats.count*100)) of the time. The highest peak recorded was $([math]::round($performance.Maximum,2)) %. If these peaks increase in frequency, consider adding more resources to this Cluster.`n"
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
									$objectIssuesRegister += "$($li)The following ESX servers do not have the same number of expected datastores. Verify that all servers are configured the same way. `n"
									$vmhostNames | sort Name | %{
										$objectIssuesRegister += "$($li)$_"	
									}
								}
							}
							
							#check if the alarm actions are enabled on this device
							if (!$obj.ExtensionData.AlarmActionsEnabled)
							{
								$objectIssuesRegister += "$($li)The alarm actions on this cluster are disabled. No alarms will be generated for this cluster as a result. Consider re-enabling it.`n"
								$objectIssues++
							}
							$issuesList,$issuesCount = Get-events -obj $obj -myvCenter $myvCenter -startPeriod $eventsStartPeriod -endPeriod $eventsEndPeriod
							$objectIssuesRegister += $issuesList
							$objectIssues += $issuesCount

							
							$row | Add-Member -MemberType NoteProperty -Name "Issues" -Value $objectIssuesRegister
							
							if ($objectIssues -and $objectIssues -gt 0) 
							{
								
								Write-Output $row
								$totalIssues += $objectIssues
								
							}
							$deviceIndex++
						}
						if ($dataTable)
						{
							$description += "A total of $totalIssues issues were recorded.`n"
							$objMetaInfo = @()
							$objMetaInfo +="tableHeader=$title"
							$objMetaInfo +="introduction=$description. "
							$objMetaInfo +="chartable=false"
							$objMetaInfo +="titleHeaderType=h$($headerType+1)"
							$objMetaInfo +="showTableCaption=false"
							$objMetaInfo +="displayTableOrientation=Table" # options are List or Table
							$metricCSVFilename = "$global:logDir\$($title -replace '\s','_').csv"
							$metricNFOFilename = "$global:logDir\$($title -replace '\s','_').nfo"
							if ($returnDataOnly)
							{
								$resultsIssuesRegisterTable["$type"] = @{}
								$resultsIssuesRegisterTable["$type"]["NFO"]=$objMetaInfo
								$resultsIssuesRegisterTable["$type"]["DataTable"]=$dataTable
								$resultsIssuesRegisterTable["$type"]["IssuesCount"]=$objectIssues
								$resultsIssuesRegisterTable["$type"]["Title"]=$title
								$resultsIssuesRegisterTable["$type"]["Introduction"]=$description
							}
						}
					}
					
					########################
					"Datacenter" {
						$title = "Datacenters"
						$description = "This section reports on $title related issues."				
						$totalIssues = 0
						$deviceIndex=1
						$sectionIssuesHTMLText = $htmlTableHeader
						$dataTable = $objArray | sort Name | %{
							$obj = $_
							$myvCenter=$srvconnection | ?{$_.Name -eq $obj.vCenter}
							Write-Progress -Activity "$title" -Id 2 -ParentId 1 -Status "$deviceIndex/$($objArray.Count) :- $($myvCenter.Name)\$($obj.Name)..." -PercentComplete (($deviceIndex/$($objArray.Count))*100)
							logthis -msg "`t-$($myvCenter.Name)\$($obj.Name)"
							$objectIssues = 0; $objectIssuesRegister = ""
							$clear = $false # use to disable the incomplete if statements below						
							$row = New-Object System.Object
							if ($srvconnection.Count -gt 1)
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
									$objectIssuesRegister += "$($li)The $type reported a $definitionname alarm on $(get-date ($triggeredAlarmState.Time)).`n"
									$objectIssues++
								}
								
								if ($hasAlarm) {Remove-Variable hasAlarm}
								if ($alarmCount) { Remove-Variable alarmCount}
							}
							
							#check if the alarm actions are enabled on this device
							if (!$obj.ExtensionData.AlarmActionsEnabled)
							{
								$objectIssuesRegister += "$($li)The alarm actions on this datacenter are disabled. No alarms will be generated for this datacenter as a result. Consider re-enabling it.`n"
								$objectIssues++
							}
							
							
							$issuesList,$issuesCount = Get-events -obj $obj -myvCenter $myvCenter -startPeriod $eventsStartPeriod -endPeriod $eventsEndPeriod
							$objectIssuesRegister += $issuesList
							$objectIssues += $issuesCount

							
							$row | Add-Member -MemberType NoteProperty -Name "Issues" -Value $objectIssuesRegister
							
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
							$metricCSVFilename = "$global:logDir\$($title -replace '\s','_').csv"
							$metricNFOFilename = "$global:logDir\$($title -replace '\s','_').nfo"
							if ($returnDataOnly)
							{
								$resultsIssuesRegisterTable["$type"] = @{}
								$resultsIssuesRegisterTable["$type"]["NFO"]=$objMetaInfo
								$resultsIssuesRegisterTable["$type"]["DataTable"]=$dataTable
								$resultsIssuesRegisterTable["$type"]["IssuesCount"]=$objectIssues
								$resultsIssuesRegisterTable["$type"]["Title"]=$title
								$resultsIssuesRegisterTable["$type"]["Introduction"]=$description
							}
						}
					}
					########################
					default {
						return
					}
				}
				$deviceTypeIndex++
			} # The array object is null, skipping
		}
	}
	if ($resultsIssuesRegisterTable)
	{
		return $resultsIssuesRegisterTable
	} else {
		return $null
	}
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

function getVMs([Parameter(Mandatory=$true)][Object]$srvConnection,[Parameter(Mandatory=$false)][object]$vmsToCheck)
{
	return (
		$srvConnection | %{ 
			$vcenterServer=$_; 
			$targetVMs = get-vm * -server $vcenterServer
			$targetVMs | %{ 
				$obj=$_; $obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenterServer.Name; 		
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
		}
	)
}

################################################
#$cpumytable = getVirtualMachinesCapacityBy -srvConnection $srvconnection -property "NumCPU" -propertyDisplayName "CPU Size"
#$memmytable = getVirtualMachinesCapacityBy -srvConnection $srvconnection -property "MemoryMB" -propertyDisplayName "Memory Size" -unit "MB"
#$osmytable = getVirtualMachinesCapacityBy -srvConnection $srvconnection -property "ExtensionData.Config.GuestFullName" -propertyDisplayName "Operating System"
#$cpumytable.Table
#$cpumytable.MetaInfo

function getVirtualMachinesCapacityBy([Object]$srvConnection,
	[Parameter(Mandatory=$true)][string]$property,
	[Parameter(Mandatory=$true)][string]$propertyDisplayName,
	[string]$unit,
	[string]$chartable="false",
	[int]$headerType=1
)
{
	$deviceType="VMs"
	$deviceTypeLong="Virtual Machines"
	$totalCountDisplayName="Total $deviceType"
	$siteDisplayName="Environment"
	
	# Report Meta Data
	$metaInfo = @()
	$metaInfo +="tableHeader=$deviceTypeLong by $propertyDisplayName"
	$metaInfo +="introduction=The table below provides configuration information of $deviceTypeLong grouped by $propertyReadable."
	$metaInfo +="chartable=false"
	$metaInfo +="titleHeaderType=h$($headerType)"

	Write-Host $metaInfo

	$objects = $srvConnection | %{
		$vCenter = $_
		Get-VM -Server $vCenter | sort Name | %{
			$device=$_
			#logThis -msg "`t`t--> $vcenterName\$_" -ForegroundColor Yellow
			$obj = "" | Select-Object "Device"
			$obj.Device =$device.Name;
			$setting="`$device.$property"
			$obj | Add-Member -Type NoteProperty -Name "$propertyDisplayName" -Value $(iex "$setting")
			#$obj | Add-Member -MemberType NoteProperty -Name "$propertyDisplayName" -Value $device.$property;
			$obj | Add-Member -MemberType NoteProperty -Name "$siteDisplayName" -Value "$($vCenter.Name)";
			#logThis -msg $obj
			$obj
		}
	}
	# Process the results
	$uniqueEnvironments=$objects | select "$siteDisplayName" -Unique

	$dataTable = $objects | Group-Object -Property "$propertyDisplayName" | %{
		$object=$_
		$row = "" | Select-Object $propertyDisplayName
		$row.$propertyDisplayName = $object.Name
		Write-Host "$($object.Name)"
		$row | Add-Member -MemberType NoteProperty -Name "$totalCountDisplayName" -Value  $object.Count;
		if ($uniqueEnvironments.Count)
		{
			#$object.Group | group "$siteDisplayName" | select Name,Count | %{
			$uniqueEnvironments.$siteDisplayName | %{ 
				$siteNAme=$_
				$count=($object.Group | ?{$_.$siteDisplayName -eq $siteNAme} | measure).Count
				$row | Add-Member -Type NoteProperty -Name "$deviceType in $($siteNAme)" -Value  $count;
			}
		}
		$row
	} | sort "$totalCountDisplayName" -Descending


	$dataTableDetails = $objects | Group-Object -Property "$propertyDisplayName" | %{
		$object=$_
		$row = "" | Select-Object $propertyDisplayName
		$row.$propertyDisplayName = $object.Name
		$devices=$_.Group
		Write-Host "$($object.Name)"
		#$row | Add-Member -MemberType NoteProperty -Name "$totalCountDisplayName" -Value  $object.Count;
		if ($uniqueEnvironments.Count)
		{
			#$object.Group | group "$siteDisplayName" | select Name,Count | %{
			$uniqueEnvironments.$siteDisplayName | %{ 
				$siteNAme=$_
				$count=($object.Group | ?{$_.$siteDisplayName -eq $siteNAme} | measure).Count
				$row | Add-Member -Type NoteProperty -Name "$deviceType in $($siteNAme)" -Value $($([string]($devices.Device | %{ Write-output "$_," })) -replace ",$")
			}
		}
		$row
	} 

	$topconsumer=$dataTable[0]
	$biggestPortion="{0:N2} %" -f (($topconsumer[0]."$totalCountDisplayName" / ($dataTable | measure "$totalCountDisplayName" -Sum).Sum)*100)

	$metaAnalytics=(" The results show that $biggestPortion, or $($topconsumer.$totalCountDisplayName) of $deviceTypeLong, are configured with a $propertyDisplayName of $($topconsumer.$propertyDisplayName) $unit.").Trim()
	if ($uniqueEnvironments.Count)
	{
		$topSite=$uniqueEnvironments.$siteDisplayName | %{
			$obj = New-Object System.Object
			$obj | Add-Member -MemberType NoteProperty -Name "Site" -Value  "$_";
			$obj | Add-Member -MemberType NoteProperty -Name "Count" -Value  $($topconsumer."$deviceType in $_");
			$obj
		} | sort Count -Descending
		$metaAnalytics+=" The biggest site for this capacity is $($topSite[0].Site), with $($topSite[0].Count) $deviceTypeLong."
	}
	if ($metaAnalytics)
	{
		$metaInfo += "analytics="+$metaAnalytics
	}
	
	$table = @{}
	$table["Property"]=$property
	$table["Property Display Name"]=$propertyDisplayName
	$table["Unit"]=$unit
	$table["MetaInfo"]=$metaInfo
	$table["Table"]=$dataTable
	
	#$dataTableDetails | group $propertyDisplayName | %{
	$table["Table_With_Device_Names"] = $dataTableDetails
	#}
	return $table	
}

#$cpumytable = getVMhostCapacityBy -srvConnection $srvconnection -property "NumCPU" -propertyDisplayName "CPU Size"
function getVMhostCapacityBy([Object]$srvConnection,
	[Parameter(Mandatory=$true)][string]$property,
	[Parameter(Mandatory=$true)][string]$propertyDisplayName,
	[string]$unit,
	[string]$chartable="false",
	[int]$headerType=1
)
{
	$deviceType="Servers"
	$deviceTypeLong="Hypervisors"
	$totalCountDisplayName="Total $deviceType"
	$siteDisplayName="Environment"
	
	# Report Meta Data
	$metaInfo = @()
	$metaInfo +="tableHeader=$deviceTypeLong by $propertyDisplayName"
	$metaInfo +="introduction=The table below provides configuration information of $deviceTypeLong grouped by $propertyReadable."
	$metaInfo +="chartable=$chartable"
	$metaInfo +="titleHeaderType=h$($headerType)"
	
	$objects = $srvConnection | %{
		$vCenter = $_
		Get-VMhost -Server $vCenter | sort Name | %{
			$device=$_
			#logThis -msg "`t`t--> $vcenterName\$_" -ForegroundColor Yellow
			$obj = New-Object System.Object
			$obj | Add-Member -MemberType NoteProperty -Name $($device.gettype().Name) -Value $device.Name;
			$setting="`$device.$property"
			$obj | Add-Member -Type NoteProperty -Name "$propertyDisplayName" -Value $(iex "$setting")
			$obj | Add-Member -MemberType NoteProperty -Name "$siteDisplayName" -Value "$($vCenter.Name)";
			#logThis -msg $obj
			$obj
		}
	}
	# Process the results
	$uniqueEnvironments=$objects | select "$siteDisplayName" -Unique

	$dataTable = $objects | Group-Object -Property "$propertyDisplayName" | %{
		$object=$_
		$row = "" | Select-Object $propertyDisplayName
		$row.$propertyDisplayName = $object.Name
		Write-Host "$($object.Name)"
		$row | Add-Member -MemberType NoteProperty -Name "$totalCountDisplayName" -Value  $object.Count;
		if ($uniqueEnvironments.Count)
		{
			#$object.Group | group "$siteDisplayName" | select Name,Count | %{
			$uniqueEnvironments.$siteDisplayName | %{ 
				$siteNAme=$_
				$count=($object.Group | ?{$_.$siteDisplayName -eq $siteNAme} | measure).Count
				$row | Add-Member -Type NoteProperty -Name "$deviceType in $($siteNAme)" -Value  $count;
			}
		}
		$row
	} | sort "$totalCountDisplayName" -Descending

	$topconsumer=$dataTable[0]
	$biggestPortion="{0:N2} %" -f (($topconsumer[0]."$totalCountDisplayName" / ($dataTable | measure "$totalCountDisplayName" -Sum).Sum)*100)

	$metaAnalytics=(" The results show that $biggestPortion, or $($topconsumer.$totalCountDisplayName) of $deviceTypeLong, are configured with a $propertyDisplayName of $($topconsumer.$propertyDisplayName) $unit.").Trim()
	if ($uniqueEnvironments.Count)
	{
		$topSite=$uniqueEnvironments.$siteDisplayName | %{
			$obj = New-Object System.Object
			$obj | Add-Member -MemberType NoteProperty -Name "Site" -Value  "$_";
			$obj | Add-Member -MemberType NoteProperty -Name "Count" -Value  $($topconsumer."$deviceType in $_");
			$obj
		} | sort Count -Descending
		$metaAnalytics+=" The biggest site for this capacity is $($topSite[0].Site), with $($topSite[0].Count) $deviceTypeLong."
	}
	if ($metaAnalytics)
	{
		$metaInfo += "analytics="+$metaAnalytics
	}
	
	$table = @{}
	$table["Property"]=$property
	$table["Property Display Name"]=$propertyDisplayName
	$table["Unit"]=$unit
	$table["MetaInfo"]=$metaInfo
	$table["Table"]=$dataTable
	return $table	
}
#$cpumytable = getVMhostCapacityBy -srvConnection $srvconnection -property "NumCPU" -propertyDisplayName "CPU Size"


function setSectionHeader (
		[Parameter(Mandatory=$true)][ValidateSet('h1','h2','h3','h4','h5')][string]$type="h1",
		[Parameter(Mandatory=$true)][object]$title,
		[Parameter(Mandatory=$false)][object]$text
	)
{
	$csvFilename=$global:outputCSV -replace ".csv","-$($title -replace ' ','_').csv"
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
		#Write-Host $bytes
		#pause
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
		Set-Variable -Name metaFile -Value $filename -Scope Global
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
	if ($tmpMetafile)
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
	$metadata | Out-File -FilePath $global:runtimeCSVMetaFile -Append
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
	$string -replace ".csv",".nfo" -replace ".ps1",".nfo" -replace ".log",".nfo" | Out-file -Append -FilePath $global:reportIndex
}

function downloadVMwareToolsPackagesVersions()
{
	$source="http://packages.vmware.com/tools/versions"
	$destination="vmware-tools-versions.txt"
	$file = Invoke-WebRequest -Uri $source 
	$file.Content | Out-File -FilePath $destination
}

function checkForVersion([string]$hwVersion)
{
	$file="vmware-tools-versions.txt"
	$content = Get-Content -Path $file
	# To complete the task here.
}

function Get-LDAPUser ($UserName) {
    $queryDC = (get-content env:logonserver).Replace('\','');
    $domain = new-object DirectoryServices.DirectoryEntry `
        ("LDAP://$queryDC")
    $searcher = new-object DirectoryServices.DirectorySearcher($domain)
    $searcher.filter = "(&(objectClass=user)(sAMAccountName=$UserName))"
    return $searcher.FindOne().Properties.displayname
} 

function formatSnapshotTable($snapshots)
{	
	
}

function getObjectVMwareLicence([Object]$obj)
{
	#$lm = Get-view $_.ExtensionData.Content.LicenseManager
}

function LoadNFOVariables([Parameter(Mandatory=$true)][string]$file) {
    Get-Content $file | Foreach-Object {
        $var = $_.Split('=')
        New-Variable -Name $var[0] -Scope Global -Value $var[1]
    }
}

function UnloadNFOVariables([Parameter(Mandatory=$true)][string]$file) {
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
	[int]$xAxisInterval
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
		$xAxisInterval = [math]::round($tableCSV.Count/7,0)
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
function GetVMSnapshots($vm)
{
	$objhasSnapshot = $vm.ExtensionData.Snapshot
	if ($objhasSnapshot)
	{
		$results = $vm | Get-Snapshot | %{
			$snapshot = $_
			$row  = New-Object System.Object
			$TaskMgr = Get-View TaskManager
	        $Filter = New-Object VMware.Vim.TaskFilterSpec
	        $Filter.Time = New-Object VMware.Vim.TaskFilterSpecByTime
	        $Filter.Time.beginTime = ((($Snapshot.Created).AddSeconds(-5)).ToUniversalTime())
	        $Filter.Time.timeType = "startedTime"
	        $Filter.Time.EndTime = ((($Snapshot.Created).AddSeconds(5)).ToUniversalTime())
	        $Filter.State = "success"
	        $Filter.Entity = New-Object VMware.Vim.TaskFilterSpecByEntity
	        $Filter.Entity.recursion = "self"
	        $Filter.Entity.entity = (Get-Vm -Name $Snapshot.VM.Name).Extensiondata.MoRef
	        $TaskCollector = Get-View ($TaskMgr.CreateCollectorForTasks($Filter))
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
			$mydatestring = new-timespan -End (get-date) -Start (get-date $snapshot.Created)
			$row | Add-Member -MemberType NoteProperty -Name "VM" -Value $vm.Name
			$row | Add-Member -MemberType NoteProperty -Name "State" -Value $vm.PowerState
			$row | Add-Member -MemberType NoteProperty -Name "VM (in snapshot)" -Value $snapshot.VM
			$row | Add-Member -MemberType NoteProperty -Name "Snapshot" -Value $snapshot.Name
			$row | Add-Member -MemberType NoteProperty -Name "Description" -Value $snapshot.Description
			$row | Add-Member -MemberType NoteProperty -Name "Size (GB)" -Value $([math]::round($snapshot.SizeGB,2))
			$row | Add-Member -MemberType NoteProperty -Name "State Before Snapshot" -Value $snapshot.PowerState
			$row | Add-Member -MemberType NoteProperty -Name "IsCurrent" -Value $snapshot.IsCurrent
			$row | Add-Member -MemberType NoteProperty -Name "Age" -Value "$($mydatestring.Days) days $($mydatestring.hours) hours"			
	        $row | Add-Member -MemberType NoteProperty -Name "CreatedBy" -Value $SnapUser
			$row 
	       	
		}		
		return $results
		
	} else {
		return $false
	}
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




function getVMwareToolsVersionMatrix()
{
	#File can be downloaded from "https://packages.vmware.com/tools/versions"
	$targetFile = ".\packages.vmware.com.tools.versions.csv"
	return Import-Csv $targetFile
}

function getVMToolsVersionForThisHost([Parameter(Mandatory=$true)][string]$hostBuild)
{
	$table = getVMwareToolsVersionMatrix
	
}

# Takes in a metric, unit and returns a Formated Title to be used in reports
function convertMetricToTitle($metric)
{
	$deviceType, $measure, $frequency = $metric.split('.')
	if ($deviceType -eq "MEM")
	{
		$deviceTypeText = "Memory"
	} else {
		$deviceTypeText = $deviceType
	}
	return "$frequency $deviceTypeText $measure"
}

#
# getstats, returns an Array or a formatted HTML string with Title,Description, and Performance results for a given Statistic Type (example: cpu.usage.average)
# Array["Name"] = Name of the object
# Array["ObjectType"] = The type of object it is ClusterResourceImpl, VirtualMachineImpl etc..
# Array["Metric"] = The actual name of the metric past to getstats
# Array["DeviceType"] = CPU, Memory, Disk or what
# Array["Measure"] = What it's measured in Swapused, cpumhz, memgranted, memvmctl etcc
# Array["Frequency"] = as in Average, Minimum, Maximum of the metric
# Array["Description"] = the description of the metric
# Array["Unit"] = KBps, Mhz, % etc..
# Array["FriendlyName"] = A formated readible string combining frequency deviceTypeText measure (unit)
#
# OR
# HTML which is a formated table of the results
function formatHeaders($text)
{
	reteurn ((Get-Culture).TextInfo.ToTitleCase(($text -replace "_"," " -replace '\.',' ').ToLower()))
}

function getStats(
	[Parameter(Mandatory=$true)]$sourceVIObject, 
	[Parameter(Mandatory=$true)]$metric, 
	[Parameter(Mandatory=$false)][array]$filters,
	[Parameter(Mandatory=$true)][int]$maxsamples=([int]::MaxValue),
	[Parameter(Mandatory=$false)][bool]$showIndividualDevicesStats=$true,
	[Parameter(Mandatory=$false)][int]$previousMonths=6,
	[Parameter(Mandatory=$false)][int]$sampleIntevalsMinutes=5,
	[bool]$returnObjectOnly=$false
)
{
	# Uncomment to overwride
	#$metric = "cpu.usage.average"

	if ($returnObjectOnly)
	{
		$resultsObject = @{}
	}
	
	# Intervals
	$statIntervalsDefinitions = Get-StatInterval #-Server $global:srvconnection
	# DEFINITIONS
	$today = Get-Date
	$erroractionpreference  = "SilentlyContinue"
	$outputHTML = ""
	#$tableColumnHeaders = @("Last20minutes", "SofarThisMonth");#, "6-Last6Months");
	$tableColumnHeaders = @();#, "6-Last6Months");
	$months = @()
	$requiredMeasures = @("Average","Minimum","Maximum");
	
	# CHECK IF THE METRIC HAS BEEN PASSED TO THIS FUNCTION
	if ($metric) 
	{	
		# Write the headers for this metric
		$writeHeaders = $true;
		logThis -msg "[$($sourceVIObject.Name)\$($metric)]:";
		#$stats | Measure-Object -Property Value -Average -Max -Min

		######################################################
		# Get Stats for each previous month - defined by 
		# variable $previousMonths
		######################################################
		if ($previousMonths -gt 0)
		{
			$monthIndex = $previousMonths
			while ($monthIndex -le $previousMonths -and $monthIndex -gt 0)
			{
				$firstDay = forThisdayGetFirstDayOfTheMonth ( $(Get-Date $today).AddMonths(-$monthIndex) )
				$lastDay = forThisdayGetLastDayOfTheMonth ( $(Get-Date $today).AddMonths(-$monthIndex) )
				$nameofdate = getMonthYearColumnFormatted($firstDay)
				$tableColumnHeaders += $nameofdate
				$months += $nameofdate
				logThis -msg "`t- For $nameofdate [$firstDay -> $lastDay]";
				#New-Variable -Name $tableColumnHeaders[2] -Value ($sourceVIObject | Get-Stat -Stat $metric -Start (Get-Date).addMonths(-1) -Finish (Get-Date) -MaxSamples $maxsamples  -IntervalMins $sampleIntevalsMinutes | select *)
				New-Variable -Name "stats$nameofdate" -Value ($sourceVIObject | Get-Stat -Stat $metric -Start $firstDay -Finish $lastDay -MaxSamples $maxsamples | select *)
				#Write-Host (Get-Variable "stats$nameofdate" -Valueonly)
				$monthIndex--
			}
		}
						
		######################################################
		# Get Stats for all the days so far in this month
		######################################################
		#New-Variable -Name $tableColumnHeaders[1] -Value ($sourceVIObject | Get-Stat -Stat $metric -Start (Get-Date).adddays(-7) -Finish (Get-Date) -MaxSamples $maxsamples -IntervalMins $sampleIntevalsMinutes | select *)
		$firstDayOfMonth = forThisdayGetFirstDayOfTheMonth($today)
		$nameofdate = "Last $(daysSoFarInThisMonth($today)) Days"
		$tableColumnHeaders += $nameofdate
		logThis -msg "`t- The last $(daysSoFarInThisMonth($today)) Days [$firstDayOfMonth -> now]";
		#New-Variable -Name "$($tableColumnHeaders[$tableColumnHeaders.GetUpperBound(0)])" -Value ($sourceVIObject | Get-Stat -Stat $metric -Start $firstDayOfMonth -Finish $today -MaxSamples $maxsamples  -IntervalMins 5  | select *)
		New-Variable -Name "stats$nameofdate" -Value ($sourceVIObject | Get-Stat -Stat $metric -Start $firstDayOfMonth -Finish $today -MaxSamples $maxsamples  -IntervalMins 5  | select *)

		######################################################
		# Get Stats for the last 20 minutes (aka realtime)
		######################################################
		#New-Variable -Name $tableColumnHeaders[0] -Value ( $sourceVIObject | Get-Stat -Stat $metric -Realtime -MaxSamples $maxsamples -IntervalMins $sampleIntevalsMinutes | select *)
		logThis -msg "`t- Last 20 minutes";
		$nameofdate = "Last 20 minutes"
		$tableColumnHeaders += $nameofdate
		New-Variable -Name "stats$nameofdate" -Value ( $sourceVIObject | Get-Stat -Stat $metric -Realtime -MaxSamples $maxsamples  -IntervalMins 5 | select *)			
		
		if ($showIndividualDevicesStats)
		{
			# This will get the "EMpty" instance as well as the Non empty ones. Meaning it will get VM overall performnace + the individual devices (ie. CPU0,CPU2,CPU3 etc..)
			$uniqueHWInstancesArray = (Get-Variable "stats$($tableColumnHeaders[$tableColumnHeaders.GetLowerBound(0)])" -ValueOnly) | Select-Object -Property Instance -Unique | sort Instance # | %{$_.Instance};
		} else {
			# This get the overwall performance stats excluding individual devices such as CPU0, CPU1 etc..
			$uniqueHWInstancesArray = (Get-Variable "stats$($tableColumnHeaders[$tableColumnHeaders.GetLowerBound(0)])" -ValueOnly) | Select-Object -Property Instance -Unique | sort Instance | Select -First 1 | %{$_.Instance};
		}

		# if filters is not defined, then ensure that all unique hardware instances are convered 
		#logThis -msg $uniqueHWInstancesArray.GetType() -ForegroundColor DarkCyan
		if ($filters.Count -eq 0)
		{
			#$filters = @();
			$filters = $uniqueHWInstancesArray
		} else {
			# Implement a device filter for example
			# not yet
		}
		
		######################################################
		# Exctract the UNIT & Description for the metric 
		######################################################
		$unit = (Get-Variable "stats$($tableColumnHeaders[$tableColumnHeaders.GetLowerBound(0)])" -ValueOnly)[0].Unit;
		switch($unit)
		{
			"Mhz" { $unitToDisplay = "Ghz"; $devider = 1024;  $wordToReplace="megahertz"; $wordToReplaceWith="gigahertz"}
			"Khz" { $unitToDisplay = "Ghz"; $devider = 1024 * 1024;  $wordToReplace="kilohertz"; $wordToReplaceWith="gigahertz" }
			#"hz" { $unitToDisplay = "Ghz"; $devider = 1024 * 1024 * 1024;  $wordToReplace="hertz"; $wordToReplaceWith="gigahertz" }
			#"B" { $unitToDisplay = "GB"; $devider = 1024 * 1024 * 1024;  $wordToReplace="megahertz"; $wordToReplaceWith="gigahertz" }
			"KB" { $unitToDisplay = "MB"; $devider = 1024 ;  $wordToReplace="kilobyte"; $wordToReplaceWith="megabyte" }
			"MB" { $unitToDisplay = "GB"; $devider = 1024;  $wordToReplace="megahertz"; $wordToReplaceWith="gigabyte" }
			"GB" { $unitToDisplay = "GB"; $devider = 1;  $wordToReplace="megahertz"; $wordToReplaceWith="gigabyte" }
			"KBps" { $unitToDisplay = "MBps"; $devider = 1024 ;  $wordToReplace="kilobytes per second"; $wordToReplaceWith="megabytes per second" }
			"MBps" { $unitToDisplay = "GBps"; $devider = 1024;  $wordToReplace="megabytes per second"; $wordToReplaceWith="gigabytes per second" }
			default {$unitToDisplay = $unit; $devider = 1; }
		}
		
		$metricDescription = (Get-Variable "stats$($tableColumnHeaders[$tableColumnHeaders.GetLowerBound(0)])" -ValueOnly)[0].Description
		logThis -msg "`t-> The Metric unit is: $unitToDisplay"
		logThis -msg "`t-> Description: $metricDescription"
		$deviceType, $measure, $frequency = $metric.split('.')
		if ($deviceType -eq "MEM")
		{
			$deviceTypeText = "Memory"
		} else {
			$deviceTypeText = $deviceType
		}
		
		if (!$metricDescription.EndsWith('.'))
		{
			$introduction = $metricDescription.Insert($metricDescription.Length,'.')
		} else {
			$introduction = $metricDescription
		}

		if ($returnObjectOnly)
		{			
			#$resultsObject["Metric"] = @{}
			$resultsObject["Name"] = $sourceVIObject.Name
			$resultsObject["ObjectType"] = ($sourceVIObject.GetType()).Name
			$resultsObject["Metric"] = $metric
			#$resultsObject["DeviceType"] = @{}
			$resultsObject["DeviceType"] = $deviceTypeText
			#$resultsObject["Measure"] = @{}
			$resultsObject["Measure"] = $measure
			#$resultsObject["Frequency"] = @{}
			$resultsObject["Frequency"] = $frequency
			$resultsObject["Months"] = $months
			#$resultsObject["Unit"] = @{}
			if ($DEBUG)
			{
				$resultsObject["Description"] = "$($sourceVIObject.Name) $introduction"
			} else {			
				$resultsObject["Description"] = "$introduction"
			}
			#$resultsObject["Description"] = @{}
			$resultsObject["Unit"] = $unitToDisplay
			$resultsObject["FriendlyName"] = formatHeaderString("$frequency $deviceTypeText $measure ($unitToDisplay)")
		}
		$outputHTML += header2 "$frequency $deviceTypeText $measure ($unitToDisplay)"
		$outputHTML += paragraph "$introduction"
		
		######################################################
		# Print the reporting periods
		######################################################
		#$tableColumnHeaders | %{
		#	Write-Host $((Get-Variable -Name "$($_)" -ValueOnly)[0])  -ForegroundColor Green
		#}
		$table = foreach ($currMeasure in $requiredMeasures) 
		{
			logThis -msg "`t-> Number of unique Device Instance to process: $($uniqueHWInstancesArray.Count)"
			logThis -msg "`t-> Number of Unique Devices filter out: $($filters.Count)"						
			foreach ($instance in $uniqueHWInstancesArray) 
			{
				logThis -msg "`t-> $($instance.Instance)"
				
				$sourceStats = @{};
				$row = "" | Select "Measure";
				$row.Measure = $currMeasure				
				if ($instance.Instance -and $showIndividualDevicesStats)
				{
					#$sourceStats.Add("2-$($deviceType.ToUpper())", "$($instance.Instance)");
					$row | Add-Member -MemberType NoteProperty -Name $($deviceType.ToUpper()) -Value "$($instance.Instance)"
				} else {
					#$sourceStats.Add("2-$($deviceType.ToUpper())", "All");
					$row | Add-Member -MemberType NoteProperty -Name $($deviceType.ToUpper()) -Value "All"
				}
				#logThis -msg "`t-> Processing results for [$metric].$currMeasure values.."
				# Iterate through the tableColumnHeaders and get thre results needed
				foreach ($nameofdate in $tableColumnHeaders) 
				{
					#
					# If the variable already exists, then re-use it, dangerous but workss
					#
					if (!(Get-variable "results$nameofdate")) {
						if ($instance.Instance -and $showIndividualDevicesStats)
						{
							New-Variable -Name "results$nameofdate" -Value ((Get-Variable "stats$nameofdate" -ValueOnly) | ?{$_.Instance -eq $instance.Instance} | select Value | Measure-Object -Property Value -Average -Maximum -Minimum);
						} 
						else 
						{
							New-Variable -Name "results$nameofdate" -Value ((Get-Variable "stats$nameofdate" -ValueOnly) | ?{!$_.Instance} | select Value | Measure-Object -Property Value -Average -Maximum -Minimum);
						}
					} else {
						logThis -msg "`t-> Performance stats already collected, re-using it"
					}
					
					if (!(Get-Variable "results$nameofdate" -ValueOnly))
					{	
						$result = printNoData
						logThis -msg "$results" -ForegroundColor RED
					}
					else {
						
						#$result = [Math]::Round((Get-Variable "results$nameofdate" -ValueOnly).$currMeasure,2);
						#using / devider because sometime you may want to set everything to megabyte or gigabyte
						$result = [Math]::Round((Get-Variable "results$nameofdate" -ValueOnly).$currMeasure / $devider,2);
						logThis -msg "$results" -ForegroundColor Green
					}
					
				#	logThis -msg ">> " $(Get-Variable "stats$nameofdate" -ValueOnly) " / $result  <<" -ForegroundColor Green;
					if ($result -is [int] -and $result -lt 1)
					{
						#$sourceStats.Add($nameofdate,"< 1");
						$row | Add-Member -MemberType NoteProperty -Name $nameofdate -Value "< 1"
					} else {
						#$sourceStats.Add($nameofdate,$result);
						$row | Add-Member -MemberType NoteProperty -Name $nameofdate -Value $result
					}

				}				
				#logThis $row				
				$row
			}
		}
		# Clear the variables just in case
		foreach ($nameofdate in $tableColumnHeaders) {
			Remove-Variable "results$nameofdate"
			Remove-Variable "stats$nameofdate"
			Remove-Variable "nameofdate"
		}
		if ($returnObjectOnly)
		{
			#$resultsObject["Table"] = @{}
			$resultsObject["Table"] = $table
			return $resultsObject
		} else {
			$outputHTML +=  $table | ConvertTo-Html -Fragment
			return $outputHTML;
		}
	} else {
		logThis -msg "Invalid parameters reported by function: getStats([Object] sourceVIObject, [array] metrics, [array] filters )"
		logThis -msg ">> Parameter 1: sourceVIObject [$($sourceVIObject.GetType())] must be a VM using command let ""Get-VM"" or an ESX object using Command let ""Get-VMHost"""
		logThis -msg ">> Parameter 2: metrics [$($metrics.GetType())] must be an array with valid metrics for the object"
		logThis -msg ">> Parameter 3: filters [$($filters.GetType())] must be an array with valid filtering strings (1 or more)"
		return $false
	}
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
	[Parameter(Mandatory=$true)]$var
)
{
	#Write-Host $("{0:n2}" -f $val)
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
	[Parameter(Mandatory=$false)][string] $BackgroundColor = "black",
	[Parameter(Mandatory=$false)][bool]$logToScreen = $true,
	[Parameter(Mandatory=$false)][bool]$NoNewline = $false
	)
{
	if ($logToScreen -and !$global:silent)
	{
		# Also verbose to screent
		if ($NoNewline)
		{
			Write-Host $msg -ForegroundColor $ForegroundColor -NoNewline;
		} else {
			Write-Host $msg -ForegroundColor $ForegroundColor;
		}
	} 
	if ($logFile)
	{
		$msg  | out-file -filepath $logFile -append
	} else 
	{
		if ((Test-Path -path $global:logDir) -ne $true) {
					
			New-Item -type directory -Path $global:logDir
			$childitem = Get-Item -Path $global:logDir
			$global:logDir = $childitem.FullName
		}
		if ($global:runtimeLogFile)
		{
			$msg  | out-file -filepath $global:runtimeLogFile -append
		} 
	}
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
	"" | out-file -filepath $global:runtimeLogFile
	logThis -msg "This script will be logging to $global:runtimeLogFile"
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
		[Parameter(Mandatory=$false)][string]$fromContactName="",
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
		$msg.From = "$fromContactName $from"
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
				$attachment = new-object System.Net.Mail.Attachment($_,"Application/Octet")
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

#
function loadSessionSnapings ()
{	
	if (!(Get-PSsnapin VMware.VimAutomation.Core))
	{
		Add-pssnapin VMware.VimAutomation.Core
	}
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

#Get-MyEvents -name $name -objType $objType -EventTypes $EventTypes -EventCategories $EventCategories -MoRef $MoRef -vCenterObj $vCenterObj -functionlogFile $functionlogFile -MessageFilter $MessageFilter

function Get-MyEvents {
param(
[Parameter(Mandatory=$true)][object]$obj, # Type of Entity, if left Empty assumes VirtualMachine
[Parameter(Mandatory=$true)][object]$vCenterObj, # pass an object obtain using command ""Connect-VIServer <vcentername>""
[string[]]$EventCategories, #Info, warning, error
[string]$MessageFilter, # pass a string if you want to filter on FullFormattedMessage, usefull if you don't know the EventType and/or Catgory
[DateTime]$startPeriod,
[DateTime]$endPeriod,
[int]$maxEventsNum=1000 # Can only read 1000 events at a time
)
	$result = ""
	#logThis -msg "`tGet-MyEvents: object: $($obj.Name), vCenter Details $($vCenterObj.Name)"

	$eventManager = get-view $vCenterObj.ExtensionData.Content.EventManager -Server $vCenterObj
	#logThis -msg "`tGet-MyEvents: $($eventManager.Client.Version) "
	if($eventManager.Client.Version -eq "Vim4" -and $maxEventsNum -gt 1000){
		logThis -msg "`tSorry, API 4.0 only allows a maximum event window of 1000 entries!" -foregroundcolor red
		logThis -msg "`tPlease set the variable `$maxEventsNum to 1000 or less" -foregroundcolor red
		return
	} else {		
	    $eventFilterSpec = New-Object VMware.Vim.EventFilterSpec
		if ($EventTypes)
		{
			$eventFilterSpec.Type = $EventTypes
		}
		$eventFilterSpec.time = New-Object VMware.Vim.EventFilterSpecByTime
	    if ($startPeriod)
		{
			$eventFilterSpec.time.beginTime = $startPeriod
		}
		if ($endPeriod)
		{
			$eventFilterSpec.time.endtime = $endPeriod
		} else {		
	    	$eventFilterSpec.time.endtime = (Get-Date)
		}
		
		if($EventCategories){
			$eventFilterSpec.Category = $EventCategories
		}

		#$objEntity = get-view -ViewType $obj.ExtensionData.MoRef.Type -Filter @{'name'=$obj.Name} -Server $vCenterObj
		$eventFilterSpec.Entity = New-Object VMware.Vim.EventFilterSpecByEntity
		$eventFilterSpec.Entity.Entity = $obj.ExtensionData.MoRef
		
		#logThis -msg $eventFilterSpec 

		#$eventFilterSpec.disableFullMessage = $false
		#$result = $eventManager.QueryEvents($eventFilterSpec)
		#$maxEventsNum = 1000 # can only read 1000 events at a time
		$ecollectionImpl = Get-View ($eventManager.CreateCollectorForEvents($eventFilterSpec))
		$ecollection = $ecollectionImpl.ReadNextEvents($maxEventsNum)
		$result = $ecollection
		$index = 1
		#logThis -msg "---- Iteration: $index :- Events located $($result.count)"
		$index++
		while($ecollection -ne $null){			
			$ecollection = $ecollectionImpl.ReadNextEvents($maxEventsNum)
			if ($ecollection)
			{
				if ($MessageFilter)
				{
					$result += $ecollection | ?{$_.FullFormattedMessage -match $MessageFilter}
				} else {
					$result += $ecollection
				}
				#logThis -msg "---- Iteration: $index :- Events located $($result.count)"
			}
			$index++;
		}
		$ecollectionImpl.DestroyCollector()
		
		return $result
	}
}

function test2()
{
	Write-Host " Output Dir = $global:logDir" -ForegroundColor Green
	Write-Host " RuntimeLogFile = $global:runtimeLogFile" -ForegroundColor Green
	
}

function InitialiseModule 
(
	#[Parameter(Mandatory=$true)][string]$global:scriptName,
	#[Parameter(Mandatory=$true)][string]$logDir
)
{
	$global:runtime="$(date -f dd-MM-yyyy)"	
	#Set-Variable -Name "logDir" -Value  $logDir -Scope 1
	Set-Variable -Name "runtimeLogFile" -Value  $($global:logDir + "\"+$global:scriptName.Replace(".ps1",".log")) -Scope Global
	#$global:logDir | Out-File "C:\admin\OUTPUT\AIT\19-11-2015\Capacity_Reports\$($global:scriptName).txt"
	Set-Variable -Name "runtimeCSVOutput" -Value  $($global:logDir+"\"+$global:scriptName.Replace(".ps1",".csv")) -Scope Global
	setRuntimeMetaFile -filename $($global:logDir+"\"+$global:scriptName.Replace(".ps1",".nfo"))
	#Set-Variable -Name "runtimeCSVMetaFile" -Value  $($global:logDir+"\"+$global:scriptName.Replace(".ps1",".nfo")) -Scope Global
	#$scriptsHomeDir = split-path -parent $global:scriptName
	
	SetmyLogFile -filename $global:runtimeLogFile
	logThis -msg " ****************************************************************************" -foregroundColor Cyan
	logThis -msg " Script Started @ $(get-date)" -ForegroundColor Cyan
	logThis -msg " Executing script: $global:scriptName " -ForegroundColor Cyan
	logThis -msg " Output Dir = $global:logDir" -ForegroundColor Cyan
	logThis -msg " Runtime log file = $global:runtimeLogFile" -ForegroundColor Cyan
	logThis -msg " Runtime CSV File = $global:runtimeCSVOutput" -ForegroundColor Cyan
	logThis -msg " Runtime Meta File = $global:runtimeCSVMetaFile" -ForegroundColor Cyan
	logThis -msg " vCenter Server: $global:vCenter" -ForegroundColor  Cyan	
	logThis -msg " ****************************************************************************" -foregroundColor Cyan
	logThis -msg "Loading Session Snapins.."
	loadSessionSnapings
	SetmyCSVOutputFile -filename $global:runtimeCSVOutput
	SetmyCSVMetaFile -filename $global:runtimeCSVMetaFile	
	test2
}