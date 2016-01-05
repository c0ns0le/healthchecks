# Exports Guest detailed information
# Version : 1.6
# Last updated : 02/02/2015, by teiva.rodiere-at-gmail.com
# It exports 3 things: 1) VM Properties, 2) Performance Metrics, 3) Event logs
#
#
# Example = .\exportVMDetails.ps1 -guestName VMNAME -srvConnection $($srvConnection) -verbose $true -includeSectionSysInfo $true -includeSectionPerfStats $true
#
#
param([object]$srvConnection,[string]$vcenters="",[string]$logDir="output",[string]$comment="",
      [string]$guestName="*",[string]$Stat="",[string]$outputFormat="html",[bool]$outToFile=$true,[bool]$verbose=$false, 
      [bool]$includeSectionSysInfo=$true,[bool]$includeSectionPerfStats=$true,[bool]$showIndividualDevicesStats=$false,[bool]$includeTasks=$true,
      [bool]$includeErrors=$true, [bool]$includeAlarms=$true, [bool]$includeVMEvents=$true,
      [bool]$outToScreen=$false,[int]$maxsamples=([int]::MaxValue),[bool]$emailReport=$false,
	  [bool]$launchBrowser=$true,
	  [int]$sampleIntevalsMinutes=5,[int]$lastMonths=2,
	  [bool]$includeVMSnapshots=$true,[int]$showOnlyRecentEventsFromDaysAgo=7,[bool]$includeIssues=$true
)

Write-Host -msg "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $($srvConnection) -Scope Global



# Want to initialise the module and blurb using this 1 function



##########################################################################################################
#
#	FUNCTIONS
#
##########################################################################################################
#$vcenterName = $($srvConnection).Name;
#$filename = ($($MyInvocation.MyCommand.Name)).TrimEnd('.ps1');
#logThis -msg "$filename";
#logThis -msg "Verbose Debugging [ON]";
switch($outputFormat) {
	"csv" {
		$fileExtension = ".csv"
	      }
	"text" {
		$fileExtension = ".txt"
	      }		
	"html" {
		$fileExtension = ".html"
	      }
	"toscreen" {
		logThis -msg "Results will be only be show to this screen"
	    }
	default {
	}
}

if (!$timeStampt)
{
	$timeStampt = "_$(get-date -f d-MM-yyyy_hh-mm-ss)_"
}


#if (Test-Path $of) { Remove-Item $of }
logThis -msg "This script log to $of"

$Report = @()
$attachments = @("");

$htmlColourArray = @("#ECE5B6","#C9C299","#827B60");

$index=1;
$vms = Get-VM -Name $guestName -Server $($srvConnection).Name | Sort-Object Name;
logThis -msg "[$($vms.Count)] found." -foreground green
$vms | %{
	$vm = $_;
	$guestName = $vm.Name
	$htmlPage = htmlHeader
	$htmlPage += header1 "Health Check Report for $guestname"
	$htmlPage += paragraph "This report presents a health check assessment for system <b>$guestname</b>. The assessment was performed on $(get-date) <i>$($srvConnection.Name)</i> ."

	#$of = $logDir + "\"+$guestName+$comment+$timeStampt+$fileExtension
	$of = $logDir + "\"+$guestName+$comment+$fileExtension
	logThis -msg "$index/$($vms.Count) :- $($($srvConnection).Name)/$($vm.host.name)/$($vm.name)" -ForegroundColor $global:colours.Information;
	
	###############################################################################################################################
	# PART 1 :- INCLUDE SYSTEM INFORMATION
	###############################################################################################################################
	# If the use chooses, collect the System Information
	
	if ($includeSectionSysInfo)  
	{
		logThis -msg "-> Export SYSTEM INFORMATION"		
		
		$htmlPage +=  header1 "System Properties"
		
		$vmView = $vm | Get-View ;
		$advanceSettings = $vm.ExtensionData.Config.ExtraConfig
		$esxHost = $vm.Host.Name #$(get-view $vm.ExtensionData.Runtime.Host).Name
		$vSphereRPO = $($advanceSettings | ?{$_.Key -eq "hbr_filter.rpo"}).Value
		$clustername = $($vm | Get-cluster).Name
		$snapshotCount = $(Get-Snapshot $vm).Count
		$dc = $($vm | Get-datacenter).Name
		
		$htmlPage +=  header2 "Quick Info"		
		$GuestConfig = "" | Select-Object "Name";
		#$GuestConfig."Name" = $vmView.Name;
		#$GuestConfig | Add-Member -Type NoteProperty -Name "Hostname" -Value $vmView.Guest.HostName;
		$GuestConfig.Name = $vmView.Guest.HostName;
		$GuestConfig | Add-Member -Type NoteProperty -Name "Description" -Value $vm.Description;
		$GuestConfig | Add-Member -Type NoteProperty -Name "IP Address" -Value $vmView.Guest.IpAddress;
		$GuestConfig | Add-Member -Type NoteProperty -Name "vCPU" -Value  $vmView.Config.Hardware.NumCPU;
		if (!($vmView.Guest.GuestState -ne "running"))
		{
			$GuestConfig | Add-Member -Type NoteProperty -Name "Memory" -Value "$(getSize -unit 'MB' -val $($vmView.Config.Hardware.MemoryMB+0)) ($(getsize -unit 'B' -val $($vm.ExtensionData.Summary.Runtime.MemoryOverhead)) overhead)" ;
		} else {
			$GuestConfig | Add-Member -Type NoteProperty -Name "Memory" -Value $(getSize -unit "MB" -val $($vmView.Config.Hardware.MemoryMB+0)) ;
		}
		$GuestConfig | Add-Member -Type NoteProperty -Name "State" -Value $vmView.Guest.GuestState;
		$GuestConfig | Add-Member -Type NoteProperty -Name "Guest Operating System / What VMware sees it as" -Value  "$($vmView.Guest.GuestFullName) / $($vm.ExtensionData.Config.GuestFullName)";
		if ($vSphereRPO) { $GuestConfig | Add-Member -Type NoteProperty -Name "vSphere Replication RPO (minutes)" -Value $vSphereRPO }
		$GuestConfig | Add-Member -Type NoteProperty -Name "Active Alarms" -Value $($vmView.TriggeredAlarmState.Count);
		$GuestConfig | Add-Member -Type NoteProperty -Name "VMware vCenter Server" -Value $($srvConnection).Name;
		$GuestConfig | Add-Member -Type NoteProperty -Name "VMware Datacenter" -Value $dc;
		$GuestConfig | Add-Member -Type NoteProperty -Name "VMware Cluster" -Value $clustername;	
		$GuestConfig | Add-Member -Type NoteProperty -Name "Current VMware ESX Server" -Value $esxHost;
		$GuestConfig | Add-Member -Type NoteProperty -Name "Last Boot" -Value  $vmView.Runtime.BootTime;
		#$tableTransposed = transposeTable $GuestConfig
		#Write-Host $tableTransposed
		$htmlPage += $GuestConfig | ConvertTo-Html -Fragment -As List
		
		$htmlPage +=  header2 "Extra Info"
		$GuestConfig = "" | Select-Object "Resource Pool";
		$GuestConfig."Resource Pool" = "$($(Get-View $vmView.ResourcePool | Select-Object Name).Name)";		
		$GuestConfig | Add-Member -Type NoteProperty -Name "Port Group" -Value  $vm.ExtensionData.Guest.Net.Network;
		$GuestConfig | Add-Member -Type NoteProperty -Name "Network Interfaces" -Value  $vmView.Guest.Net.Count;
		$GuestConfig | Add-Member -Type NoteProperty -Name "VMware Tools" -Value "$($vmView.Config.Tools.ToolsVersion) ($($vmView.Guest.ToolsStatus))";
		$GuestConfig | Add-Member -Type NoteProperty -Name "Hardware Version" -Value "$($vm.version)";
		$GuestConfig | Add-Member -Type NoteProperty -Name "Time Synched with Host" -Value $vmView.Config.Tools.SyncTimeWithHost;
		$GuestConfig | Add-Member -Type NoteProperty -Name "Last Modified Date" -Value  $vmView.Config.Modified;
		$GuestConfig | Add-Member -Type NoteProperty -Name "VMX Location" -Value $vmView.Summary.Config.VmPathName;
		$GuestConfig | Add-Member -Type NoteProperty -Name "Change Block Tracking Enabled" -Value $($vmView.Config.ExtraConfig | ?{$_.Key -eq "ctkEnabled"}).Value
		$GuestConfig | Add-Member -Type NoteProperty -Name "EVC Requirement" -Value $vm.ExtensionData.Runtime.MinRequiredEVCModeKey
		$GuestConfig | Add-Member -Type NoteProperty -Name "DHCP Enabled" -Value $vm.ExtensionData.Guest.IpStack.DnsConfig.Dhcp
		$GuestConfig | Add-Member -Type NoteProperty -Name "DNS" -Value $vm.ExtensionData.Guest.IpStack.DnsConfig.DomainName
		$GuestConfig | Add-Member -Type NoteProperty -Name "IpAddress" -Value $([string]$vm.ExtensionData.Guest.IpStack.DnsConfig.IpAddress)
		$GuestConfig | Add-Member -Type NoteProperty -Name "Search Domain" -Value $([string]$vm.ExtensionData.Guest.IpStack.DnsConfig.SearchDomain)
		$GuestConfig | Add-Member -Type NoteProperty -Name "Guest MAC" -Value $vm.ExtensionData.Guest.Net.MacAddress
		$htmlPage += $GuestConfig | ConvertTo-Html -Fragment -As List
		
		# Enumerate VMs VMDK(s)
		
		$vmdks = Get-HardDisk -VM $vmView.Name;
		$i=1;
		if ($vmdks.Filename -or $vmdks.Count -gt 0)
		{
			$htmlPage +=  header2 "Virtual Machine Disks"
			#if ($vmdks.Filename) 
			#{
			#	$GuestConfig.Count = "1";
			#} 
			#else 
			#{
			#	$GuestConfig.Count = $vmdks.Count;
			#}
			$GuestConfig = foreach ($vmdk in $vmdks) 
			{
				
				$onDiskName = $vmdk.ExtensionData.DeviceInfo.Label;
				$datastore,$diskpath = $vmdk.ExtensionData.Backing.FileName.Split(" ")
				$datastore = $datastore -replace "\[","";
				$datastore = $datastore -replace "\]","";
				$datastoreView = Get-Datastore -Name $datastore | Get-View;
				$extentNames = "";
				foreach ($device in $datastoreView.Info.Vmfs.Extent)
				{
					$extentNames += "$($device.DiskName)"
				}
				$row = "" | Select-Object "Name";
				$row.Name = $onDiskName;
				$row | Add-Member -Type NoteProperty -Name "Capacity" -Value $(getSize -unit "KB" -val $vmdk.CapacityKB);
				$row | Add-Member -Type NoteProperty -Name "Format" -Value $vmdk.StorageFormat;
				$row | Add-Member -Type NoteProperty -Name "Type" -Value $vmdk.DiskType;
				$row | Add-Member -Type NoteProperty -Name "Persistence" $vmdk.Persistence;
				$row | Add-Member -Type NoteProperty -Name "Datastore" -Value $datastore;
				
				$row | Add-Member -Type NoteProperty -Name "VMFS Block Size" -Value "$($datastoreView.Info.Vmfs.BlockSizeMb) MB";
				$row
				$i++;
			}
		} 
		else 
		{ 
			#$GuestConfig | Add-Member -Type NoteProperty -Name "VM - Hard Disk Count" -Value "0";
		}

		if ($GuestConfig)
		{
			$htmlPage += $GuestConfig | ConvertTo-Html -Fragment #-As List
			Remove-Variable GuestConfig
		}
		
		
		# Enumerate Guest volume(s)
		$guestdisks = $vmView.Guest.Disk;
		$i=1
		if ($guestdisks.DiskPath -or  $guestdisks.Count -gt 0)
		{
			$htmlPage +=  header2 "Guest File Systems"
			#if ($guestdisks.DiskPath) 
			#{
			#	$GuestConfig | Add-Member -Type NoteProperty -Name "Guest - Volume Count" -Value  "1";
			#} else {
			#	$GuestConfig | Add-Member -Type NoteProperty -Name "Guest - Volume Count" -Value  $guestdisks.Count;
			#}
			$GuestConfig = foreach ($guestdisk in $guestdisks)
			{	
				$row = "" | Select-Object "Volume";
				$row.Volume = $guestdisk.DiskPath;
				$row | Add-Member -Type NoteProperty -Name "Size" -Value $(getSize -unit "B" -val $guestdisk.Capacity);
				$row | Add-Member -Type NoteProperty -Name "Free" -Value $(getSize -unit "B" -val $guestdisk.FreeSpace);
				$row | Add-Member -Type NoteProperty -Name "% Free" -Value $([Math]::Round($guestdisk.Freespace/$guestdisk.Capacity*100,2));
				$row
				$i++;
			}
		} 
		else 
		{ 
			#$GuestConfig | Add-Member -Type NoteProperty -Name "Guest - Volume Count" -Value  "0";
		}

		if ($GuestConfig)
		{
			$htmlPage += $GuestConfig | sort -property "% Free" -Descending | ConvertTo-Html -Fragment #-As List
			Remove-Variable GuestConfig
		}
		
		
		# Custom Attributes
		if ($vmView.AvailableField) 
		{			
			$htmlPage +=  header2 "Custom Attributes"
			$GuestConfig = foreach ($field in $vmView.AvailableField) 
			{
				$custField = $vmView.CustomValue | ?{$_.Key -eq $field.Key}
				$row = "" | Select-Object "Name";
				$row.Name = $field.Name
				$row | Add-Member -Type NoteProperty -Name "Value" -Value $custField.Value
				$row
			}
		}
		
		if ($GuestConfig)
		{
			$htmlPage += $GuestConfig | ConvertTo-Html -Fragment #-As List
			Remove-Variable GuestConfig
		}

		
		
	}
		
	###############################################################################################################################
	# PART 2 :- INCLUDE VM PERFORMANCE STATS
	###############################################################################################################################
	# 
	#  If the use choose, collect the System Performance Stats 
	if ($includeSectionPerfStats) 
	{
		# Default performance stats from the virtual machine
		#$vmStatMetrics = @("disk.numberRead.summation");
		#$vmStatMetrics = @("cpu.usagemhz.average","net.usage.average");
		$vmStatMetrics = @("cpu.usage.average","mem.usage.average","cpu.ready.summation","mem.granted.average","mem.vmmemctl.average","mem.swapped.average","mem.shared.average","mem.overhead.average","disk.usage.average","disk.read.average","disk.write.average","disk.maxTotalLatency.latest","net.usage.average");
		#$esxStatMetrics = @("disk.deviceLatency.average","disk.deviceReadLatency.average","disk.deviceWriteLatency.average","disk.totalLatency.average","disk.totalReadLatency.average","disk.totalWriteLatency.average");
		#$vmStatMetrics = @("cpu.usage.average","cpu.usagemhz.average","cpu.ready.summation","cpu.used.summation","mem.usage.average","mem.granted.average","mem.vmmemctl.average","mem.swapped.average","mem.shared.average","mem.overhead.average","disk.usage.average","disk.read.average","disk.write.average","disk.numberWrite.summation","disk.numberRead.summation");
		#$esxStatMetrics = @("disk.deviceLatency.average","disk.deviceReadLatency.average","disk.deviceWriteLatency.average","disk.totalLatency.average","disk.totalReadLatency.average","disk.totalWriteLatency.average");
		#$columns = 1; # VMName counts for 1
		#$columns = $vmStatMetrics | %{
		#	$categoryname,$metricsnames,$deviceType=$_.Split(".");
		#	$column
		#	$columns++;
		#}

		logThis -msg "-> Collecting the Performance stats..."
		logThis -msg "-> Samples: $maxsamples"
		logThis -msg "-> Metrics: $vmStatMetrics"

		if ($outputFormat -eq "html") {
			$htmlPage +=  header1 "Performance Stats"
			$htmlPage +=  paragraph "This section provides a detailed performance analysis of server for the reporting period listed below. All performance results come from the $farmname's VMware vCenter Database."
			$htmlPage +=  paragraph "Examine the results to ascertain if changes to resource allocations is needed."
			$htmlPage +=  "<table>
						  <tr><td>Reporting period:</td><td>Realtime, $showOnlyRecentEventsFromDaysAgo Days, $lastMonths Month(s)</td></tr>
						  <tr><td>Measure:</td><td>See each section below</td></tr>
						  <tr><td>Metrics</td><td>$vmStatMetrics</td></tr>
						  </table>"
			#<tr><td>Metrics</td><td>$vmStatMetrics</td></tr>
		}
		
		#$vmStatMetrics = @("cpu.usage.average");
		
		$filters = @();
		#logThis -msg " :::: vmStatMetrics = $($vmStatMetrics.GetType())";$vmStatMetrics;
		#logThis -msg " :::: filters = $($filters.GetType())"; $filters;
		#logThis -msg " :::: VM = $($vm.GetType())"; $vm;
		
		#logThis -msg "VMware $vm.Name"
		if ($vmStatMetrics)
		{
			#logThis -msg "`tCollecting VM Entity Based Stats for this VM: ";
			#################################################################
			# THIS IS WHERE THE STATS ARE COLLECTED
			logThis -msg "-> Calling getStats function for VM Metrics..."
			$outputString = $vmStatMetrics | %{ 
				$metric = $_
				#getStats  $_ $filters $maxsamples $showIndividualDevicesStats
				$tmpOutput = getStats -sourceVIObject $vm -metric $metric -filters $filters -maxsamples $maxsamples -showIndividualDevicesStats $showIndividualDevicesStats -previousMonths $lastMonths # -returnObjectOnly $true
				#Write-Host $tmpOutput
				#pause
				
			}
			#################################################################
			$htmlPage +=  $outputString
		}
		
		# Collect performance stats from the ESX host
					#MetricId
					# --------
					# disk.deviceReadLatency.average
					# disk.queueReadLatency.average
					# disk.numberWriteAveraged.average
					# disk.queueLatency.average
					# disk.totalWriteLatency.average
					# disk.write.average
					# disk.kernelLatency.average
					# disk.numberReadAveraged.average
					# disk.queueWriteLatency.average
					# disk.numberWrite.summation
					# disk.commandsAborted.summation
					# disk.kernelReadLatency.average
					# disk.numberRead.summation
					# disk.read.average
					# disk.maxQueueDepth.average
					# disk.busResets.summation
					# disk.totalLatency.average
					# disk.deviceLatency.average
					# # disk.totalReadLatency.average
					# disk.commandsAveraged.average
					# # disk.kernelWriteLatency.average
					# disk.deviceWriteLatency.average
					# disk.commands.summation
					# disk.maxTotalLatency.latest
					# disk.usage.average
					# 
		
		if ($esxStatMetrics)
		{
			if ($outputFormat -eq "html") {
			$htmlPage +=  header1 "Host Based Stats"
			$htmlPage +=  paragraph "Performance stats from the ESX server on which the system is hosted on."
			$htmlPage +=  paragraph "Examin the results to assertain if changes to resource allocations is needed."
			$htmlPage +=  "<table>
						  <tr><td>Reporting period:</td><td>Realtime, $showOnlyRecentEventsFromDaysAgo Days, $lastMonths Month(s)</td></tr>
						  <tr><td>Measure:</td><td>See each section below</td></tr>
						  <tr><td>Metrics</td><td>$esxStatMetrics</td></tr>
						  </table>"
			
			}
			#$esxStatMetrics = @("disk.deviceWriteLatency.average");
			logThis -msg "  Collecting VMHost Based Stats for this VM: ";
			$esxHost = Get-VMHost -Name (Get-View((Get-View $_.Id).Runtime.Host)).Name;
			$filters = @();
			
			foreach ($datastore in (Get-View (Get-View $_.Id).datastore))
			{
				#$filters += "$($datastore.Summary.Name)"
				foreach ($diskExtent in $datastore.Info.Vmfs.Extent)
				{
					$filters += $diskExtent.DiskName;
					
				}
			}
			
			#logThis -msg " :::: esxStatMetrics = $($esxStatMetrics.GetType())";$esxStatMetrics;
			#logThis -msg " :::: filters = $($filters.GetType())"; $filters;
			logThis -msg "-> Calling getStats function for VMHost Metrics for this VM ..."
			$outputString = $esxStatMetrics | %{ 
				getStats $esxHost $_ $filters $maxsamples $showIndividualDevicesStats 
				
			}
			$htmlPage += $outputString
		}
		#if ($outputFormat -eq "html") {
			#$htmlPage += "</table>";
		#}
	}

	
	if ($includeTasks -or $includeErrors -or $includeAlarms -or $includeVMEvents)
	{
		logThis -msg "`t-> Exporting Events"
		$vmEvents = Get-VM -Name $guestName -Server $($srvConnection) | Get-VIEvent -MaxSamples $maxsamples -Finish (get-date) -Start $(get-date).AddDays(-$showOnlyRecentEventsFromDaysAgo)
	}	
	###############################################################################################################################
	# PART 3 :- TASKS
	###############################################################################################################################
	if ($includeTasks) 
	{
		logThis -msg "`t-> Exporting Tasks"
		$tmpreport = $vmEvents | ?{$_.FullFormattedMessage.Contains("Task:")} | sort CreatedTime -Descending | select CreatedTime,FullFormattedMessage,UserName
		if ($outputFormat -eq "html") {
			
			$count=0
			if ($tmpreport)
			{
				if ($tmpreport.Count)
				{
					$count = $tmpreport.Count
				} else {
					$tmpreport = 1
				}
			} else { 
				#$count = 0s
			}
			$htmlPage +=  header1 "Recent Tasks and Configuration Changes"
			$htmlPage +=  paragraph "This table below contains a list of Tasks such as reconfigurations and other administrative actions made on this system over the reporting period. Changes and Tasks are indicative that administrative actions are taking place."
			$htmlPage +=  paragraph "Please note that changes within the Guest Operating system (example: Windows or Linux inside the VM) are not accounted for."
			$htmlPage +=  "<table>
						  <tr><td>Reporting period:</td><td>$showOnlyRecentEventsFromDaysAgo Days</td></tr>
						  <tr><td>Measure:</td><td>N/A</td></tr>
						  <tr><td>Number of Tasks:</td><td>$count</td></tr>
						  </table>"
			
			$htmlPage += $tmpreport | ConvertTo-Html -Fragment
			if ($count -gt 0)
			{
				$htmlPage += paragraph "Unique rows: $count"
			}
		}
	}
	
	#$rpoEvents = $vmEvents | ?{$_.EventTypeId -eq "com.vmware.vcHms.rpoRestoredEvent"}

	###############################################################################################################################
	# PART 5 :- INCLUDE ERRORS,WARNINGS
	###############################################################################################################################
	if ($includeErrors) 
	{
		logThis -msg "`t-> Exporting ERRORS"
		$tmpreport=$vmEvents | ?{$_.FullFormattedMessage.Contains("Error") -or $_.FullFormattedMessage.Contains("Warning")} | sort CreatedTime -Descending | select CreatedTime,FullFormattedMessage,UserName
		if ($outputFormat -eq "html") {
			
			$count=0
			if ($tmpreport)
			{
				if ($tmpreport.Count)
				{
					$count = $tmpreport.Count
				} else {
					$tmpreport = 1
				}
			} else { 
				#$count = 0
			}
			#$htmlPage +=  header "Errors and Warnings"
			#$htmlPage +=  paragraph "This section provides a list of errors recorded by vCenter for your system over the reporting period. Errors are related to the configurations and operation of the server."
			#$htmlPage +=  paragraph "<table>
			#			  <tr><td>Reporting period:</td><td>$showOnlyRecentEventsFromDaysAgo Days</td></tr>
			#			  <tr><td>Measure:</td><td>N/A</td></tr>
			#			  <tr><td>Number of Errors:</td><td>$count</td></tr>
			#			  </table>"
			$htmlPage += $tmpreport | ConvertTo-Html -Fragment
			if ($count -gt 0)
			{
				$htmlPage += paragraph "Unique rows: $count"
			}
		}
	}

	###############################################################################################################################
	# PART :- INCLUDE VM Snapshots
	###############################################################################################################################
	if ($includeVMSnapshots) 
	{
		logThis -msg "`t-> Exporting Snapshots"
		$tmpreport=  $vm | Get-Snapshot | select *
		if ($outputFormat -eq "html") {
			
			$count=0
			if ($tmpreport)
			{
				if ($tmpreport.Count)
				{
					$count = $tmpreport.Count
				} else {
					$tmpreport = 1
				}
			} else { 
				#$count = 0
			}
			$htmlPage +=  header1 "Virtual Machine Snapshots"
			$htmlPage +=  paragraph "This section provides a list of active snapshots for this system."
			$htmlPage +=  "<table>
						  <tr><td>Number of Snaphosts:</td><td>$count</td></tr>
						  </table>"
			$htmlPage += $tmpreport | ConvertTo-Html -Fragment
			if ($count -gt 0)
			{
				$htmlPage += paragraph "Unique rows: $count"
			}
		}
	}

	###############################################################################################################################
	# PART 6 :- INCLUDE ALARMS
	###############################################################################################################################
	if ($includeAlarms) 
	{
		logThis -msg "`t-> Exporting Alarms"
		$tmpreport = $vmEvents | ?{$_.FullFormattedMessage.Contains("Alarm")} | sort CreatedTime -Descending | select CreatedTime,FullFormattedMessage,UserName
		if ($outputFormat -eq "html") {
			
			$count=0
			if ($tmpreport)
			{
				if ($tmpreport.Count)
				{
					$count = $tmpreport.Count
				} else {
					$tmpreport = 1
				}
			} else { 
				#$count = 0
			}
			$htmlPage +=  header1 "Alarms"
			$htmlPage +=  paragraph "This section provides a list of Alarms as seen triggered for your system. The list of Alarms are pulled from the vCenter Database"
			$htmlPage +=  "<table>
						  <tr><td>Reporting period:</td><td>$showOnlyRecentEventsFromDaysAgo Days</td></tr>
						  <tr><td>Measure:</td><td>N/A</td></tr>
						  <tr><td>Number of Alarms:</td><td>$count</td></tr>
						  </table>"
			$htmlPage += $tmpreport | ConvertTo-Html -Fragment
			if ($count -gt 0)
			{
				$htmlPage += paragraph "Unique rows: $count"
			}
		}
	}
	
	if ($vmEvents)
	{
		$rpoViolations = $vmEvents | ?{$_.FullFormattedMessage.Contains("Virtual machine vSphere Replication RPO is violated by")} | sort CreatedTime | select CreatedTime,FullFormattedMessage,UserName
	}
	if ($rpoViolations)
	{
		logThis -msg "`t-> found vSphere Replication Violations, collecting stats"
		#$rpoEvents=$vmEvents | select CreatedTime,FullFormattedMessage,UserName 
		if ($outputFormat -eq "html") {
			
			
			$tmpreport = $rpoViolations | sort CreatedTime | %{ 
				$row = "" | Select "Date","Replication Delays"
				$row.Date = $_.Createdtime
				$row."Replication Delays" = $_.FullFormattedMessage.Replace("Virtual machine vSphere Replication RPO is violated by","").Replace("minute(s)","") 
				#Write-Host $row
				$row
			}
			
			logThis -msg "[$($tmpreport.Count)] entries found $($($tmpreport.Count) * 10)" -foreground CYAN
			$htmlPage += header1 "vSphere Replication RPO Violations"
			$htmlPage += paragraph "The diagram below shows the violations over the reporting period. Violations occur when the vSphere replication 
							is unable to replicate within the Recovery Point Object (RPO) defined for this Virtual Machine. Use this information in the review 
							of your VM disaster recovery strategy review."
			$htmlPage +=  "<table>
						  <tr><td>Replication RPO (minutes):</td><td>$vSphereRPO</td></tr>
						  <tr><td>Reporting period:</td><td>$showOnlyRecentEventsFromDaysAgo Days</td></tr>
						  <tr><td>Measure:</td><td>Delays in minutes for each date and time value</td></tr>
						  <tr><td>Number of Violations Recorded:</td><td>$($tmpreport.Count)</td></tr>
						  </table>"
			
			
			#$tmpcsvfile="$env:temp\$guestName-rpoviolations.csv"
			#$tmpreport | sort "Date" | Export-csv -NoTypeInformation -Path $tmpcsvfile
			$imgDir = "img"
			$chartStandardWidth=800
			#$chartStandardHeight=$($($tmpreport.Count) * 15)
			$chartStandardHeight=600
			$chartImageFileType="png"
			$chartType="Line" #StackedBar100
			$chartText="Replication Delayed by in minutes"
			$chartTitle="Last 7 Days"
			$yAxisTitle="Minutes"
			$xAxisTitle="Periods of violation"
			$startChartingFromColumnIndex=1
			$yAxisInterval=50
			$yAxisIndex=1
			$xAxisIndex=0
			$xAxisInterval=-1
			
			if ((Test-Path -path "$global:logdir\$imgDir") -ne $true) {
				New-Item -type directory -Path "$global:logdir\$imgDir"
			}
			
			logThis -msg "$tmpreport" -ForegroundColor $global:colours.Information
			$imageFileLocation = createChart -datasource $tmpreport -outputImage "$global:logdir\$imgDir\$guestname-rpoViolations.$chartImageFileType" -chartTitle $chartTitle `
				-xAxisTitle $xAxisTitle -yAxisTitle $yAxisTitle -imageFileType $chartImageFileType -chartType $chartType `
				-width $chartStandardWidth -height $chartStandardHeight -startChartingFromColumnIndex $startChartingFromColumnIndex -yAxisInterval $yAxisInterval `
				-yAxisIndex  $yAxisIndex -xAxisIndex $xAxisIndex -xAxisInterval $xAxisInterval
				
			$imageFilename = Split-Path -Leaf $imageFileLocation

			logThis -msg "`t-> image: [$imageFilename]" -foreground blue
			#$htmlPage += "<tr><td>"
			if ($emailReport)
			{
				$htmlPage += "<img src=""$imgDir/$imageFilename""></img>"
				$attachments += $imageFileLocation
			} else
			{
				$htmlPage += "<img src=""$imageFileLocation""></img>"
				logThis -msg "<img src=""$imageFileLocation""></img>"
			}
			#$htmlPage += $tableCSV | ConvertTo-HTML -Fragment
			#$htmlPage +="</td></tr></table>"
			$htmlPage += "</td></tr></table></div>"

			#$htmlPage += "<div class=""second column"">"      
			$htmlPage += header2 "Raw data"
			$htmlPage += paragraph "The following table shows a trend of vsphere replication violations. Values are in minutes."

			#logThis -msg $imageFileLocation -BackgroundColor $global:colours.Error -ForegroundColor $global:colours.Information
			#$attachments += $imageFileLocation			
			#$htmlPage += "<div><img src=""$imageFilename""></img></div>"
			#$attachments += $imageFileLocation
			
			Remove-Variable imageFileLocation
			Remove-Variable imageFilename
			
			
            $htmlPage += $tmpreport | sort "Date" | ConvertTo-html -Fragment
			$count=0
			if ($tmpreport)
			{
				if ($tmpreport.Count)
				{
					$count = $tmpreport.Count
				} else {
					$tmpreport = 1
				}
			} else { 
				#$count = 0
			}
			if ($count -gt 0)
			{
				$htmlPage += paragraph "Unique rows: $count"
			}
			
			$htmlPage +="</div>"
		}
	}
	
	#############
	# Issues Report
	#
	#############
	if ($includeIssues)
	{
		logThis -msg "######################################################################" -ForegroundColor $global:colours.Highlight
		logThis -msg "Checking the overall status of this system and its depending objects..."  -ForegroundColor $global:colours.Highlight
		$title="Issues Register"
		$description = "Find below a list of issues discovered for this system and its dependent components. Such components can be datastores, hosts, clusters, and datacenters."
		$objMetaInfo = @()
		$objMetaInfo +="tableHeader=$title"
		$objMetaInfo +="introduction=$description. "
		$objMetaInfo +="chartable=false"
		$objMetaInfo +="titleHeaderType=h$($headerType+1)"
		$objMetaInfo +="showTableCaption=false"
		$objMetaInfo +="displayTableOrientation=Table" # options are List or Table
		$htmlTableHeader = "<table><th>Name</th><th>Issues/Actions</th>"
		
		# define all the Devices to query
		
		#pause
		$objectsArray = @(
			@($srvConnection | %{ $vcenterName=$_.Name; Get-VM $guestName -Server $_ | Get-Cluster -server $_ | %{ $obj=$_; $obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenterName; $obj} }),
			#@($srvConnection | %{ $vcenterName=$_.Name; Get-VM $guestName -Server $_ | Get-vmhost -server $_ | %{ $obj=$_; $obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenterName; $obj} }),
			@($srvConnection | %{ $vcenterName=$_.Name; Get-VM $guestName -Server $_ | %{ $obj=$_; $obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenterName; $obj} }),
			@($srvConnection | %{ $vcenterName=$_.Name; Get-VM $guestName -Server $_ | get-datacenter -server $_ | %{ $obj=$_; $obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenterName; $obj} }),
			@($srvConnection | %{ $vcenterName=$_.Name; Get-VM $guestName -Server $_ | get-datastore -server $_ | %{ $obj=$_; $obj | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenterName; $obj} })
		)
		
		$results = getIssues -objectsArray $objectsArray -srvconnection $srvConnection -returnDataOnly $true -performanceLastDays 7  -headerType $($headerType+2) -showPastMonths $lastMonths
		
		$htmlPage +=  header1 "$title"
		$totalIssues = $(($results.Values.IssuesCount | measure -Sum).Sum)
		if ($totalIssues) { $analysis =  "A total of $totalIssues issues affecting this system were found.`n" }
		$htmlPage +=  paragraph "$description. $analysis"
		
		$results.Keys | %{
			$name = $_
			#$($results.$name.NFO)
			$htmlPage +=  header2 "$($results.$name.title)"
			#$($results.$name)"
			$htmlPage +=  paragraph "$($results.$name.introduction)"
			$htmlPage +=  ($results.$name.DataTable  | ConvertTo-Html -Fragment) -replace '&lt;li&gt;','<li>'
		}
	}
	

	$htmlPage += htmlFooter
	$htmlPage > $of
	
	if ($launchBrowser)
	{
		Invoke-Expression "$of"
	}
	
	if ($emailReport)
	{
		###################################
		# DEFINE THE IMPORTANT STUFF HERE - TO COME
		###################################
	}
	
	
	$index++;
}
