#param([string]$global:logDir=".\output")
# AUthor: teiva.rodiere-at-gmail.com

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
	[Object]$ensureTheseFieldsAreFieldIn,
	[bool]$reportThinDisksAsAnIssue=$false
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
		logThis -msg "######################################################################" -ForegroundColor $global:colours.Highlight
		logThis -msg "Checking Individual Systems / component issues and action items"  -ForegroundColor $global:colours.Highlight
		$title= "Systems Issues and Actions"
		#$htmlPage += "$(header2 $title)"
		$deviceTypeIndex=1
		$objectsArray | %{
			if ($_)
			{
				$objArray = $_
				
				$firstObj = $objArray | select -First 1
				#logThis -msg  $firstObj.Name
				$type = $firstObj.GetType().Name.Replace("Impl","")				
				Write-Progress -Activity "Processing report" -Id 1 -Status "$deviceTypeIndex/$($objectsArray.Count) :- $type..." -PercentComplete  (($deviceTypeIndex/$($objectsArray.Count))*100)
				$index=0;
				logThis -msg "[`t`t$type`t`t]" -foregroundcolor $global:colours.Highlight
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
							$hasThinDisks = $obj.ExtensionData.Config.Hardware.Device | ?{$_.ControllerKey -eq "1000"} | ?{$_.Backing.ThinProvisioned -eq $true}
							if ($hasThinDisks -and $reportThinDisksAsAnIssue)
							{
								$objectIssuesRegister += "$($li)This VM has $($hasThinDisks.Count) thinly deployed disks. Reconsider using Thick disks instead.`n"
								$objectIssues++
							} elseif ($hasThinDisks -and !$reportThinDisksAsAnIssue)
							{
								logThis -msg "`t-> Server has thin disks but the user specified not to report it as an issue"
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
								#logThis -msg "Parent Object: $($parent.Name)" -ForegroundColor $global:colours.Information -Backgroundcolor $global:colours.Error
								#logThis -msg "Cluster nodes: $($clusterNodes.Count)" -ForegroundColor $global:colours.Information -Backgroundcolor $global:colours.Error
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
					"NasDatastore" {
						logThis -msg "This type of device is not yet supported by this health check"
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
							# Note for the future release
							# try to find vmx and vmtx as well.
							$searchSpec.matchPattern = "*.vmdk"
							$searchSpec.sortFoldersFirst = $true
							$dsBrowser = Get-View $dsView.browser -Server $myvCenter
							$rootPath = "[" + $dsView.Name + "]"
							#logthis -msg "Searching for Folders - BEFORE"
							$searchResult = $dsBrowser.SearchDatastoreSubFolders($rootPath, $searchSpec)
							#logthis -msg "Searching for Folders - AFTER"
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
								logThis -msg "------------" -ForegroundColor $global:colours.ChangeMade
								#logThis -msg $orphanDisksOutput	 -ForegroundColor $global:colours.ChangeMade
								$orphanDisksTotalSizeGB = $($orphanDisksOutput | measure -Property SizeGB -Sum).Sum
								if ($orphanDisksOutput.Count -eq 1)
								{
									$themTxt="There is 1 orphan VMDK on this datastore consuming $($orphanDisksTotalSizeGB) GB. Consider removing it."
								} else {
									$themTxt="There are $($orphanDisksOutput.Count) potential orphan VMDKs on this datastore consuming $(getsize -unit 'GB' -val $orphanDisksTotalSizeGB). Consider removing them."
								}
								$objectIssuesRegister += "$($li)$themTxt`n"
								$objectIssuesRegister += $orphanDisksOutput # | ConvertTo-Html -Fragment
								$objectIssues++
								#logThis -msg "$objectIssuesRegister" -ForegroundColor $global:colours.ChangeMade
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
							
							if ($obj.HAEnabled -and ($obj.ExtensionData.Summary.CurrentFailoverLevel -lt $obj.HAFailoverLevel))
							{
								$objectIssuesRegister += "$($li)The cluster's failover levels are below the levels configured. The configured level is $($obj.HAFailoverLevel) whilst the actual is $($obj.ExtensionData.Summary.CurrentFailoverLevel).`n"
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
						logThis -msg "This type of device is not yet supported by this health check"
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

function collectAllEntities ([Parameter(Mandatory=$true)][Object]$server,[Parameter(Mandatory=$false)][bool]$force)
{
	
	if ($force -or !$global:infrastructure) 
	{
		#logThis -msg "Getting an Infrastructure List"
		$global:infrastructure = @{}
		logThis -msg "`t-> vCenters"
		$global:infrastructure["vCenters"] = $server

		logThis -msg "`t-> VMhosts"
		$global:infrastructure["VMhosts"] = $server | %{
			$vcenter = $_
			get-vmhost -server $vcenter | %{
				$_ | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenter.Name
				$_ | Add-Member -MemberType NoteProperty -Name "Datacenter" -Value $(get-datacenter -VMhost $_ -Server $vcenter | select Name,Id)
				$_ | Add-Member -MemberType NoteProperty -Name "Cluster" -Value $(get-cluster -VMhost $_ -Server $vcenter | select Name,Id)
				$_ | Add-Member -MemberType NoteProperty -Name "VMs" -Value $(get-vm -location $_ -Server $vcenter | select Name,Id)
				$_ | Add-Member -MemberType NoteProperty -Name "Datastores" -Value $(get-datastore -VMhost $_ -Server $vcenter | select Name,Id)
				$_ | Add-Member -MemberType NoteProperty -Name "ResourcePools" -Value $(get-resourcepool -location $_ -Server $vcenter | select Name,Id)
				$_ | Add-Member -MemberType NoteProperty -Name "StandardSwitches" -Value $(get-virtualswitch -VMhost $_ -Server $vcenter -Standard | select Name,Id)
				$_ | Add-Member -MemberType NoteProperty -Name "DistributedvSwitches" -Value $(get-virtualswitch -VMhost $_ -Server $vcenter -Distributed | select Name,Id)
				$_ | Add-Member -MemberType NoteProperty -Name "StandardPortGroups" -Value $(get-virtualportgroup -VMhost $_ -Server $vcenter -Standard | select Name,Key)
				$_ | Add-Member -MemberType NoteProperty -Name "DistributedPortGroups" -Value $(get-virtualportgroup -VMhost $_ -Server $vcenter -Distributed | select Name,Key)
				$_
			}
		}
		logThis -msg "`t-> Clusters"
		$global:infrastructure["Clusters"] = $server | %{
			$vcenter = $_
			get-cluster -server $vcenter | %{				
				$_ | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenter.Name
				$_ | Add-Member -MemberType NoteProperty -Name "Datacenter" -Value $(get-datacenter -Cluster $_ -Server $vcenter | select Name,Id)
				$vmhosts = get-vmhost -location $_ -Server $vcenter
				if ($vmhosts)
				{
					
					$_ | Add-Member -MemberType NoteProperty -Name "VMhosts" -Value $($vmhosts | select Name,Id)
					$_ | Add-Member -MemberType NoteProperty -Name "VMs" -Value $(get-vm -location $_ -Server $vcenter | select Name,Id)
					$_ | Add-Member -MemberType NoteProperty -Name "Datastores" -Value $($vmhosts | get-datastore -Server $vcenter | select Name,Id)
					$_ | Add-Member -MemberType NoteProperty -Name "ResourcePools" -Value $(get-resourcepool -location $_ -Server $vcenter | select Name,Id)
					$_ | Add-Member -MemberType NoteProperty -Name "StandardSwitches" -Value $(get-virtualswitch -Vmhost $vmhosts -Server $vcenter -Standard | select Name,Id)
					$_ | Add-Member -MemberType NoteProperty -Name "DistributedvSwitches" -Value $(get-virtualswitch -VMhost $vmhosts -Server $vcenter -Distributed | select Name,Id)
					$_ | Add-Member -MemberType NoteProperty -Name "StandardPortGroups" -Value $(get-virtualportgroup -VMhost $vmhosts -Server $vcenter -Standard | select Name,Key)
					$_ | Add-Member -MemberType NoteProperty -Name "DistributedPortGroups" -Value $(get-virtualportgroup -VMhost $vmhosts -Server $vcenter -Distributed | select Name,Key)
				}
				$_
			}
		}

		logThis -msg "`t-> VMs"
		$global:infrastructure["VMs"] = $server | %{
			$vcenter = $_
			get-vm -server $vcenter | %{
				$_ | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenter.Name
				$_ | Add-Member -MemberType NoteProperty -Name "Datacenter" -Value $(get-datacenter -VM $_ -Server $vcenter | select Name,Id)
				$_ | Add-Member -MemberType NoteProperty -Name "Cluster" -Value $(get-cluster -VM $_ -Server $vcenter | select Name,Id)
				$_ | Add-Member -MemberType NoteProperty -Name "Datastores" -Value $(get-datastore -VM $_ -Server $vcenter | select Name,Id)
				$_ | Add-Member -MemberType NoteProperty -Name "ResourcePools" -Value $(get-resourcepool -VM $_ -Server $vcenter | select Name,Id)
				$_ | Add-Member -MemberType NoteProperty -Name "StandardSwitches" -Value $(get-virtualswitch -VM $_ -Server $vcenter -Standard | select Name,Id)
				$_ | Add-Member -MemberType NoteProperty -Name "DistributedvSwitches" -Value $(get-virtualswitch -VM $_ -Server $vcenter -Distributed | select Name,Id)
				$_ | Add-Member -MemberType NoteProperty -Name "StandardPortGroups" -Value $(get-virtualportgroup -Vm $_ -Server $vcenter -Standard | select Name,Key)
				$_ | Add-Member -MemberType NoteProperty -Name "DistributedPortGroups" -Value $(get-virtualportgroup -VM $_ -Server $vcenter -Distributed | select Name,Key)
				#Folder"
				$_
			}
		}
		logThis -msg "`t-> Datastores"
		$global:infrastructure["Datastores"] = $server | %{
			$vcenter = $_
			get-datastore -server $vcenter | %{
				$_ | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenter.Name
				$_ | Add-Member -MemberType NoteProperty -Name "VMhosts" -Value $($_ | get-vmhost -Server $vcenter| Select Name,Id)
				$_ | Add-Member -MemberType NoteProperty -Name "VMs" -Value $($_ | get-vm -Server $vcenter | Select Name,Id)
				$_
			}
		}
		logThis -msg "`t-> Standard vSwitches"
		$global:infrastructure["StandardvSwitches"] = $server | %{
			$vcenter = $_
			get-VirtualSwitch -server $vcenter -Standard | %{
				$_ | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenter.Name
				$_
			}
		}
		logThis -msg "`t-> Distributed vSwitches"
		$global:infrastructure["DistributedvSwitches"] = $server | %{
			$vcenter = $_
			get-VirtualSwitch -server $vcenter -Distributed | %{
				$_ | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenter.Name
				$_
			}
		}
		<##$logThis -msg "`t-> Distributed vSwitches"
		#$global:infrastructure["DistributedvSwitches"] = $server | %{
			$vcenter = $_
			get-VirtualSwitch -server $vcenter -Distributed | %{
				$_ | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenter.Name
				$_
			}
		}
		#>
		logThis -msg "`t-> Port Groups"
		$global:infrastructure["PortGroups"] = $server | %{
			$vcenter = $_
			get-resourcepool -server $vcenter | %{
				$_ | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenter.Name
				$_
			}
		}
		logThis -msg "`t-> Virtual Folders"
		$global:infrastructure["vFolders"] = $server | %{
			$vcenter = $_
			get-Folder -server $vcenter | %{
				$_ | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenter.Name
				$_ | Add-Member -MemberType NoteProperty -Name "VMs" -Value $(Get-VM -Location $_ -Server $vcenter | select Name,Id)
				$_
			}
		}
		logThis -msg "`t-> Datacenters"
		$global:infrastructure["Datacenters"] = $server | %{
			$vcenter = $_
			get-datacenter -server $vcenter | %{				
				$_ | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenter.Name
				$_ | Add-Member -MemberType NoteProperty -Name "VMs" -Value $(Get-VM -Location $_ -Server $vcenter | select Name,Id)
				$_ | Add-Member -MemberType NoteProperty -Name "VMhosts" -Value $(Get-VMHost -Location $_ -Server $vcenter | select Name,Id)
				$_ | Add-Member -MemberType NoteProperty -Name "Clusters" -Value $(Get-Cluster -Location $_ -Server $vcenter | select Name,Id)
				$_ | Add-Member -MemberType NoteProperty -Name "ResourcePools" -Value $(Get-ResourcePool -Location $_ -Server $vcenter | select Name,Id)
				$_ | Add-Member -MemberType NoteProperty -Name "Datastores" -Value $(Get-Datastore -Location $_ -Server $vcenter | select Name,Id)
				$_ | Add-Member -MemberType NoteProperty -Name "vFolders" -Value $(Get-Folder -Location $_ -Server $vcenter | select Name,Id)
				$_ | Add-Member -MemberType NoteProperty -Name "StandardSwitches" -Value $(get-virtualswitch -datacenter $_ -Server $vcenter -Standard | select Name,Id)
				$_ | Add-Member -MemberType NoteProperty -Name "DistributedvSwitches" -Value $(get-virtualswitch -datacenter $_ -Server $vcenter -Distributed | select Name,Id)
				$_ | Add-Member -MemberType NoteProperty -Name "StandardPortGroups" -Value $(get-virtualportgroup -datacenter $_ -Server $vcenter -Standard | select Name,Key)
				$_ | Add-Member -MemberType NoteProperty -Name "DistributedPortGroups" -Value $(get-virtualportgroup -datacenter $_ -Server $vcenter -Distributed | select Name,Key)
				$_
			}
		}
		logThis -msg "`t-> Snapshots"
		$global:infrastructure["Snapshots"] = $server | %{
			$vcenter = $_
			Get-Snapshot * -server $vcenter | %{				
				$_ | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenter.Name				
				$_ | Add-Member -MemberType NoteProperty -Name "Age" -Value (getTimeSpanFormatted((Get-date) - (get-date $_.Created)))
				$_
			}
		}

		logThis -msg "`t-> Licenses"
		$global:infrastructure["Licenses"] = $server | %{
			$vcenter = $_
			Get-Snapshot * -server $vcenter | %{				
				$_ | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenter.Name
				$_
			}
		}

		return $global:infrastructure
	} else {
		logThis -msg "Already got an Infrastructure List, re-using it"
		return $global:infrastructure
	}
}
#$infrastructure = collectAllEntities -server $srvconnection -force $true

function getvSwitches([Parameter(Mandatory=$true)][Object]$server,[Parameter(Mandatory=$false)][bool]$force)
{
	if ($force -or (!$global:infrastructure.StandardvSwitches -and !$global:infrastructure))
	{
		logThis -msg "Getting list of StandardvSwitches"
		$infrastructure = collectAllEntities -server $server -force $true		
		return $global:infrastructure.StandardvSwitches
	} else {
		logThis -msg "The list of StandardvSwitches already exists, returning current list"
		return $global:infrastructure.StandardvSwitches
	}
}
function getdvSwitches([Parameter(Mandatory=$true)][Object]$server,[Parameter(Mandatory=$false)][bool]$force)
{
	if ($force -or (!$global:infrastructure.DistributedvSwitches -and !$global:infrastructure))
	{
		logThis -msg "Getting list of DistributedvSwitches"
		$infrastructure = collectAllEntities -server $server -force $true		
		return $global:infrastructure.DistributedvSwitches
	} else {
		logThis -msg "The list of DistributedvSwitches already exists, returning current list"
		return $global:infrastructure.DistributedvSwitches
	}
}
function getPortGroups([Parameter(Mandatory=$true)][Object]$server,[Parameter(Mandatory=$false)][bool]$force)
{
	if ($force -or (!$global:infrastructure.PortGroups -and !$global:infrastructure))
	{
		logThis -msg "Getting list of PortGroups"
		$infrastructure = collectAllEntities -server $server -force $true		
		return $global:infrastructure.PortGroups
	} else {
		logThis -msg "The list of PortGroups already exists, returning current list"
		return $global:infrastructure.PortGroups
	}
}
function getDatastores([Parameter(Mandatory=$true)][Object]$server,[Parameter(Mandatory=$false)][bool]$force)
{
	if ($force -or (!$global:infrastructure.Datastores -and !$global:infrastructure))
	{
		logThis -msg "Getting list of datastores"
		$infrastructure = collectAllEntities -server $server -force $true		
		return $global:infrastructure.Datastores
	} else {
		logThis -msg "The list of datastores already exists, returning current list"
		return $global:infrastructure.Datastores
	}
}
#$dstores = getDatastores -srvConnection $server -force $true

function getVMs([Parameter(Mandatory=$true)][Object]$server,[Parameter(Mandatory=$false)][bool]$force,[Parameter(Mandatory=$false)][object]$vmsToCheck)
{
	if ($force -or (!$global:infrastructure.VMs -and !$global:infrastructure))
	{
		logThis -msg "Getting list of Virtual Machine"
		$infrastructure = collectAllEntities -server $server -force $true		
		return $global:infrastructure.VMs

	} else {
		logThis -msg "The list of Virtual Machines already exists, returning current list"
		return $global:infrastructure.VMs
	}
}

#$hosts = getVmhosts -srvconnection $server -force $true
function getVMHosts([Parameter(Mandatory=$true)][Object]$server,[Parameter(Mandatory=$false)][bool]$force)
{
	if ($force -or (!$global:infrastructure.VMhosts -and !$global:infrastructure))
	{
		logThis -msg "Getting list of VMHosts"
		$infrastructure = collectAllEntities -server $server -force $true
		return $global:infrastructure.VMhosts
	} else {
		logThis -msg "The list of vmhosts already exists, returning current list"
		return $global:infrastructure.VMhosts
	}
}

#$clusters = getClusters -srvconnection $server -force $true
function getClusters([Parameter(Mandatory=$true)][Object]$server,[Parameter(Mandatory=$false)][bool]$force)
{
	if ($force -or (!$global:infrastructure.Clusters -and !$global:infrastructure))
	{
		logThis -msg "Getting list of clusters"
		$infrastructure = collectAllEntities -server $server -force $true
		return $global:infrastructure.Clusters
		
	} else {
		logThis -msg "The list of clusters already exists, returning current list"
		return $global:infrastructure.Clusters
	}
}

function getDatacenters([Parameter(Mandatory=$true)][Object]$server,[Parameter(Mandatory=$false)][bool]$force)
{
	if ($force -or (!$global:infrastructure.Datacenters -and !$global:infrastructure))
	{
		logThis -msg "Getting list of Datacenters"
		$infrastructure = collectAllEntities -server $server -force $true
		return $global:infrastructure.Datacenters
	} else {
		logThis -msg "The list of Datacenters already exists, returning current list"
		return $global:infrastructure.Datacenters
	}
}


function getvcFolders([Parameter(Mandatory=$true)][Object]$server,[Parameter(Mandatory=$false)][bool]$force)
{
	if ($force -or (!$global:infrastructure.vFolders -and !$global:infrastructure))
	{
		logThis -msg "Getting list of vCenter Folders"
		$infrastructure = collectAllEntities -server $server -force $true
		return $global:infrastructure.vFolders
	} else {
		logThis -msg "The list of vFolders already exists, returning current list"
		return $global:infrastructure.vFolders
	}
}

function getSnapshots([Parameter(Mandatory=$true)][Object]$server,[Parameter(Mandatory=$false)][bool]$force)
{
	if ($force -or (!$global:infrastructure.Snapshots -and !$global:infrastructure))
	{
		logThis -msg "Getting list of Snapshots"
		$infrastructure = collectAllEntities -server $server -force $true
		return $global:infrastructure.Snapshots
	} else {
		logThis -msg "The list of vFolders already exists, returning current list"
		return $global:infrastructure.Snapshots
	}
}

#collectAllEntities -srvConnection $srvconnection
#getVMs -srvConnection $srvconnection -force $true
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

	#logThis -msg $metaInfo

	$objects = $srvConnection | %{
		$vCenter = $_
		Get-VM -Server $vCenter | sort Name | %{
			$device=$_
			#logThis -msg "`t`t--> $vcenterName\$_" -ForegroundColor $global:colours.Information
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
		logThis -msg "$($object.Name)"
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
		logThis -msg  "$($object.Name)"
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
			#logThis -msg "`t`t--> $vcenterName\$_" -ForegroundColor $global:colours.Information
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
		logThis -msg  "$($object.Name)"
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
		logThis -msg "`t`t-> Removing Variable `$$variableName = $variableName" -ForegroundColor $global:colours.Highlight		
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
			logThis -msg  "Recursing ...$property " -ForegroundColor $global:colours.Information
			#$table += return recurseThruObject $obj.$field
		} elseif ($type -eq "string") 
		{
			#$row += $obj.$($_.Definition)
			logThis -msg  $type $field
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
				#logThis -msg  (Get-Variable "stats$nameofdate" -Valueonly)
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
		New-Variable -Name "stats$nameofdate" -Value ($sourceVIObject | Get-Stat -Stat $metric -Start $firstDayOfMonth -Finish $today -MaxSamples $maxsamples  -IntervalMins 5  | select *)

		######################################################
		# Get Stats for the last 20 minutes (aka realtime)
		######################################################
		#New-Variable -Name $tableColumnHeaders[0] -Value ( $sourceVIObject | Get-Stat -Stat $metric -Realtime -MaxSamples $maxsamples -IntervalMins $sampleIntevalsMinutes | select *)
		logThis -msg "`t- Last 20 minutes";
		$nameofdate = "Last 20 minutes"
		$tableColumnHeaders += $nameofdate
		New-Variable -Name "stats$nameofdate" -Value ( $sourceVIObject | Get-Stat -Stat $metric -Realtime -MaxSamples $maxsamples  -IntervalMins 5 | select *)

		#$definitionsFound=$false
		$lindex=0
		do {
			$nameofdate=$tableColumnHeaders[$lindex]
			#logThis -msg "HERE :- $nameofdate"
			if ( (Get-Variable "stats$nameofdate" -ValueOnly) -and !$unit)
			{
				logThis -msg "`t`t- $nameofdate"
				if ($showIndividualDevicesStats)
				{
					# This will get the "EMpty" instance as well as the Non empty ones. Meaning it will get VM overall performnace + the individual devices (ie. CPU0,CPU2,CPU3 etc..)
					$uniqueHWInstancesArray = (Get-Variable "stats$nameofdate" -ValueOnly) | Select-Object -Property Instance -Unique | sort Instance # | %{$_.Instance};
				} else 
				{
					# This get the overwall performance stats excluding individual devices such as CPU0, CPU1 etc..
					$uniqueHWInstancesArray = (Get-Variable "stats$nameofdate" -ValueOnly) | Select-Object -Property Instance -Unique | sort Instance | Select -First 1 | %{$_.Instance};
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
			
				$unit = (Get-Variable "stats$nameofdate" -ValueOnly)[0].Unit;
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
		
				$metricDescription = (Get-Variable "stats$nameofdate" -ValueOnly)[0].Description
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

				$lindex = $tableColumnHeaders.Count
			}
			$lindex++
		} while ($lindex -lt $tableColumnHeaders.Count)
			
		if ($returnObjectOnly)
		{		
			logThis -msg "`t`t---->>> $([string]$months)" -foregroundcolor $global:colours.Highlight
			$resultsObject["Name"] = $sourceVIObject.Name
			$resultsObject["ObjectType"] = ($sourceVIObject.GetType()).Name
			$resultsObject["Metric"] = $metric
			$resultsObject["DeviceType"] = $deviceTypeText
			$resultsObject["Measure"] = $measure
			$resultsObject["Frequency"] = $frequency
			
			$resultsObject["Months"] = $months
			if ($DEBUG)
			{
				$resultsObject["Description"] = "$($sourceVIObject.Name) $introduction"
			} else {			
				$resultsObject["Description"] = "$introduction"
			}
			#$resultsObject["Description"] = @{}
			$resultsObject["Unit"] = $unitToDisplay
			$resultsObject["FriendlyName"] = formatHeaderString("$frequency $deviceTypeText $measure ($unitToDisplay)")
		} else {
			$outputHTML += header2 "$frequency $deviceTypeText $measure ($unitToDisplay)"
			$outputHTML += paragraph "$introduction"
			logThis -msg "`t`t---->>> HERE" -foregroundcolor "BLUE"
		}
			
		######################################################
		# Print the reporting periods
		######################################################
		#$tableColumnHeaders | %{
		#	logThis -msg  $((Get-Variable -Name "$($_)" -ValueOnly)[0])  -ForegroundColor $global:colours.Highlight
		#}
		#logThis -msg "HERE  2:- $([string]$($resultsObject["Months"]))"
		#pause
		$table = foreach ($currMeasure in $requiredMeasures) 
		{
			logThis -msg "`t-> Number of unique Device Instance to process: $($uniqueHWInstancesArray.Count)"
			logThis -msg "`t-> Number of Unique Devices filter out: $($filters.Count)"						
			foreach ($instance in $uniqueHWInstancesArray) 
			{
				logThis -msg "`t-> $($instance.Instance)"
				
				#$sourceStats = @{};
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
						logThis -msg "$results" -Foregroundcolor $global:colours.Error
					}
					else {
						
						#$result = [Math]::Round((Get-Variable "results$nameofdate" -ValueOnly).$currMeasure,2);
						#using / devider because sometime you may want to set everything to megabyte or gigabyte
						$result = [Math]::Round((Get-Variable "results$nameofdate" -ValueOnly).$currMeasure / $devider,2);
						logThis -msg "$results" -ForegroundColor $global:colours.Highlight
					}
					
				#	logThis -msg ">> " $(Get-Variable "stats$nameofdate" -ValueOnly) " / $result  <<" -ForegroundColor $global:colours.Highlight;
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
				logThis -msg "HERE 7"
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
			#$table | Out-file "C:\admin\OUTPUT\AIT\05-01-2016\table.txt"
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




#######################################################################
# This function can be used to pass a username to it and secure file with 
# encrypted password and generate a powershell script
#######################################################################
<#function GetmyCredentialsFromFile(
	[Parameter(Mandatory=$true)][string]$User,
	[Parameter(Mandatory=$true)][string]$File
	) 
{
	
	$password = Get-Content $File | ConvertTo-SecureString 
	$credential = New-Object System.Management.Automation.PsCredential($user,$password)
	logThis -msg  "Am i in here [$($credential.Username)]" -Backgroundcolor $global:colours.Error -ForegroundColor $global:colours.Information
	return $credential
}#>


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
		logThis -msg "`tSorry, API 4.0 only allows a maximum event window of 1000 entries!" -foregroundcolor $global:colours.Error
		logThis -msg "`tPlease set the variable `$maxEventsNum to 1000 or less" -foregroundcolor $global:colours.Error
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

function getPerformanceReport (
	[string]$type,
	[Object]$objects,
	[object]$stats,
	[int]$showPastMonths,
	[bool]$showIndividualDevicesStats=$false,
	[int]$maxsamples=([int]::MaxValue),
	[bool]$unleashAllStats=$false,
	[int]$headerType=1)
{
	$title="$type Resource Usage"
	$metaInfo = @()
	$metaInfo +="tableHeader=$title"
	$metaInfo +="introduction=The section provides you with performance results for each of your $type."
	$metaInfo +="titleHeaderType=h$($headerType)"
	$metaInfo +="table=h$($headerType)"
	#$metaInfo +="titleHeaderType=h2"
	#updateReportIndexer -string "$(split-path -path $objectCSVFilename -leaf)"
	
	$combinedResults=@{}

	logThis -msg "Collecting stats on a monthly basis for the past $showPastMonths Months..." -foregroundcolor $global:colours.Highlight

	$global:logToScreen = $true
	$objects | sort -Property Name | %{
		$object = $_	
		$outputString = New-Object System.Object
		logThis -msg "Processing host $($_.Name)..." -foregroundcolor $global:colours.Highlight
		$filters = ""
	
		#$output.Server = $_.Name
    
		$combinedResults[$object.Name] = @{}

		if ($unleashAllStats)
		{
			$metricsDefintions = $object | Get-StatType | ?{!$_.Contains(".latest")}
		} else {
			$metricsDefintions = $stats
		}
		
		#$objectCSVFilename = $(getRuntimeCSVOutput).Replace(".csv","-$($object.Name).csv")
		#$objectNFOFilename = $(getRuntimeCSVOutput).Replace(".csv","-$($object.Name).nfo")
	
		# I dod this so I can have a title for this report bu specifically for this host
		#$objMetaInfo = @()
		#$objMetaInfo +="tableHeader=$($object.Name)"
		#$objMetaInfo +="introduction=The table below has been provided the performance review of hypervisor server: ""$($object.Name)"". The results show the usage over several periods including month by month for the last $showPastMonths months. "
		#$objMetaInfo +="chartable=false"
		#$objMetaInfo +="titleHeaderType=h$($headerType+1)"
		#$objMetaInfo +="showTableCaption=false"
		#$objMetaInfo +="displayTableOrientation=Table" # options are List or Table

		#ExportCSV -table "" -thisFileInstead $objectCSVFilename 
		#ExportMetaData -metadata $objMetaInfo -thisFileInstead $objectNFOFilename
		#updateReportIndexer -string "$(split-path -path $objectCSVFilename -leaf)"

		#$of = getRuntimeCSVOutput
		#Write-Host "NEW File : $of" -Backgroundcolor $global:colours.Error -ForegroundColor White
		#$report = 
		$metricsDefintions | %{
			$metric = $_
			$parameters= @{
				'sourceVIObject'=$object;
				'metric'=$metric;
				'maxsamples'=$maxsamples;
				'filters'=$filters;
				'showIndividualDevicesStats'=$showIndividualDevicesStats;
				'previousMonths'=$showPastMonths;
				'returnObjectOnly'=$true;
			}
			#$report = getStats -sourceVIObject $object -metric $metric -filters $filters -maxsamples $maxsamples -showIndividualDevicesStats $showIndividualDevicesStats -previousMonths $showPastMonths -returnObjectOnly $true
		
			$report = getStats @parameters
#			logThis -msg "(get Performance Report) $([string]$($report.Months))"
			#pause
			#$subheader = convertMetricToTitle $metric
			#logThis -msg $report.Table
			$combinedResults[$object.Name][$metric] = $report			
		}
	}

	# process the results
	$bigreport = @{}
	$metricsDefintions | %{
		$metricName = $_		
		$keys = $combinedResults.keys
		#$combinedResults[$keyname].$metricName.Table
	#	logThis -msg "(get Performance Report :- $metricName) $([string]$($combinedResults.$($combinedResults.keys | Select -First 1).$metricName.Months))"
		#pause
		$keys | %{
			$key=$_
			if ($combinedResults.$key.$metricName.Months)
			{
				logThis -msg "---->>>>>>> $key $metricName"
				$listOfMonths = $combinedResults.$key.$metricName.Months
				return			
			}
		}
		
		$row = New-Object System.Object
		$row | Add-Member -Type NoteProperty -Name  $metricName -Value ""
		$filerIndex=1
	
		$listOfMonths | %{
			$monthName = $_
			$row | Add-Member -Type NoteProperty -Name "$monthName" -Value "Minimum"
			$row | Add-Member -Type NoteProperty -Name "H$filerIndex" -Value "Maximum"; $filerIndex++;
			$row | Add-Member -Type NoteProperty -Name "H$filerIndex" -Value "Average"; $filerIndex++;
		}

		$finalreport = @()
		$finalreport += $row
		$finalreport += $keys | %{
			$keyname=$_
			$table = $combinedResults[$keyname].$metricName.Table
			#$row | Add-Member -Type NoteProperty -Name "Servers" -Value $keyname
			$row = New-Object System.Object
			$row | Add-Member -Type NoteProperty -Name  $metricName -Value $keyname
			$filerIndex=1
			$listOfMonths | %{
				$monthName = $_
				$row | Add-Member -Type NoteProperty -Name "$monthName" -Value ($table | ?{$_.Measure -eq "Minimum"}).$monthName
				$row | Add-Member -Type NoteProperty -Name "H$filerIndex" -Value ($table | ?{$_.Measure -eq "Maximum"}).$monthName 
				$filerIndex++
				$row | Add-Member -Type NoteProperty -Name "H$filerIndex" -Value ($table | ?{$_.Measure -eq "Average"}).$monthName
				$filerIndex++
			}
			$row
		}
		$bigreport[$metricName] = $finalreport
	}
	logThis -msg "HERE"
	return $bigreport,$metaInfo,(getRuntimeLogFileContent)
}

function InitialiseModule()
{
	#loadSessionSnapings
	if (!(Get-PSsnapin VMware.VimAutomation.Core))
	{
		logThis -msg "Loading Session Snapins.."
		Add-pssnapin VMware.VimAutomation.Core
	}
	
}

# Import the generic module because there are common functions and settings across vmware and non-vmware related modules
# silencer prevents unecessary strings from showing up on the screen
$silencer = Import-Module "..\generic\genericModule.psm1" -PassThru -Force -Verbose:$false

# call the InitialiseModule function 
InitialiseModule