# Exports detailed Virtual Machines Settings and Runtime information
# Version : 1.1
# Last Updated : 8/10/2015, by teiva.rodiere@gmail.com
param(
		[object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$showOnlyTemplates=$false,
		[bool]$skipEvents=$true,[bool]$verbose=$false,
		[int]$numsamples=([int]::MaxValue),[int]$numPastDays=7,
		[int]$sampleIntevalsMinutes=5
)
Write-Host "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global
$global:logfile
$global:outputCSV

# Want to initialise the module and blurb using this 1 function
InitialiseModule

$index=1;
$run1Report =  $srvConnection | %{
    $vcenterName = $_.Name
    if ($showOnlyTemplates) 
    {
        logThis -msg "Enumerating Virtual Machines Templates only from vCenter $_ inventory..." -ForegroundColor Yellow
        $vms = Get-Template -Server $_ | Sort-Object Name
        
        #logThis -msg "Enumerating Virtual Machines Templates Views from vCenter $_ inventory..." -ForegroundColor Red
        #$vmsViews = $vms | Get-View;
    } else {
        logThis -msg "Enumerating Virtual Machines from vCenter $_ inventory..." -ForegroundColor Yellow
        $vms = Get-VM -Server $_ | Sort-Object Name 
        
        #logThis -msg "Enumerating Virtual Machines Views from vCenter $_ inventory..." -ForegroundColor Red
        #$vmsViews = $vms | Get-View;
    }
    
    if ($vms) 
    {
        logThis -msg "Loading vcFolders from vCenter $_..." -ForegroundColor Yellow
        $vcFolders = get-folder * -Server $_ | select -unique
    
        logThis -msg "Loading Virtual Machine Creation Events from vCenter $_..." -ForegroundColor Yellow
        if (!$skipEvents)
        {
            # only load events for virtual machines which 
            #$viEvents = $vms | Get-VIEvent -Finish (get-date) -Start $(get-date).AddYears(-10) -Types Info  -MaxSamples ([int]::MaxValue) -Server $_ | Where { $_.Gettype().Name -eq "VmReconfiguredEvent" -or $_.Gettype().Name -eq "VmBeingDeployedEvent" -or $_.Gettype().Name -eq "VmCreatedEvent" -or $_.Gettype().Name -eq "VmRegisteredEvent"}
			$viEvents = $vms | Get-VIEvent -Types Info  -MaxSamples ([int]::MaxValue) -Server $_ | Where { $_.Gettype().Name -eq "VmReconfiguredEvent" -or $_.Gettype().Name -eq "VmBeingDeployedEvent" -or $_.Gettype().Name -eq "VmCreatedEvent" -or $_.Gettype().Name -eq "VmRegisteredEvent"}
        }
    
        $vms | %{
			$vm = $_;
            #$vmView = $vmsView | ?{$_.Name -eq $vm.Name}
			logThis -msg "Processing $index of $($vms.Count) :- $vm [$($vm.PowerState)]" -ForegroundColor Yellow;
			$GuestConfig = "" | Select-Object Name; 
			$GuestConfig.Name = $vm.Name;
            
            $Created ="";
            $User = "";
			
            if (!$skipEvents)
            {
            
                # Process creation/registrations etc events
                $vmCreationEvents = $viEvents | Where { ($_.Gettype().Name -eq "VmBeingDeployedEvent" -or $_.Gettype().Name -eq "VmCreatedEvent" -or $_.Gettype().Name -eq "VmRegisteredEvent") -and $_.Vm.Name -match $vm.Name} 
                # Processing events               
                If (($vmCreationEvents | Measure-Object).Count -eq 0)
                {
                    #none found
                    $User = "Unknown"
                    $Created = "Unknown"
                } else {
                    # some found
                    
                    If ($vmCreationEvents.Username -eq "" -or $vmCreationEvents.Username -eq $null) {
                        # 
                        $User = "Unknown"
                    } Else {
                        $User = (Get-QADUser -Identity $vmCreationEvents.Username).DisplayName
    				    if ($User -eq $null -or $User -eq ""){
    					   $User = $vmCreationEvents.Username
    				    }
    				    $Created = $vmCreationEvents.CreatedTime
                    }
                }
                
               # Process last event - including TSM
                $vmLastReconfigurationEvent = $viEvents | Where { $_.Gettype().Name -match "VmReconfiguredEvent" -and $_.Vm.Name -match $vm.Name} | Sort-Object -Property CreatedTime -Descending | select -First 1
                
                # Processing events               
                If ($vmLastReconfigurationEvent)
                {
                    $lastModifiedUser = "Unknown"
                    # a reconfiguration event was detected
                    $lastModifiedEventCreationTime = $vmLastReconfigurationEvent.CreatedTime
                    if ($vmLastReconfigurationEvent.Username -ne $null -or $vmLastReconfigurationEvent.Username -ne ""){
                           $lastModifiedUser = (Get-QADUser -Identity $vmLastReconfigurationEvent.Username).DisplayName
                           if ($lastModifiedUser -eq $null -or $lastModifiedUser -eq "")
                           {
                                # cannot determine the user from ad, so just add the username as shown in the event
                                $lastModifiedUser =  $vmLastReconfigurationEvent.Username
                           }
       				    }
                }

            }
            
            if (!$showOnlyTemplates)
            {
                $bootDelay = $vm.ExtensionData.Config.BootOptions.BootDelay
                $cluster = "$(($vm | Get-Cluster).Name)";
                $resourcePool = $vm.ResourcePool;
                $datacenter = "$(($vm | Get-Datacenter).Name)";
                $vcFolder = "$($vcFolders | ?{$_.Id -match $vm.ExtensionData.Parent.Value})";
                $vMPathName = $vm.ExtensionData.Summary.Config.VmPathName;
                #$modifiedDate = $vm.ExtensionData.Config.Modified;
                #$modifiedDate = $lastModifiedEventCreationTime 
            } else {
                $bootDelay = $vm.ExtensionData.Config.BootOptions.BootRetryDelay
                $cluster = "$(($vm | Get-Cluster).Name)";
                $resourcePool = $vm.ResourcePool;
                $datacenter = "$(($vm | Get-Datacenter).Name)";
                $vcFolder = (Get-Folder -id $vm.ExtensionData.Parent).Name;
                $vMPathName = $vm.ExtensionData.Summary.Config.VmPathName;
            
			}
		
            $GuestConfig | Add-Member -Type NoteProperty -Name "GuestFullName" -Value  $vm.ExtensionData.Config.GuestFullName;
	
			$cpuStats = -1
			$memStats = -1
			$netStats = -1
			$balloonStats = -1
			
			if ($vm.PowerState -eq "PoweredOn")
			{
				$cpuStats = "{0:n2}" -f $(Get-Stat -Entity $vm -Stat "cpu.usage.average" -MaxSamples $numsamples -Start (Get-Date).AddDays(-$numPastDays) -IntervalMins $sampleIntevalsMinutes | measure -Property Value -Average).Average
				$memStats = "{0:n2}" -f $(Get-Stat -Entity $vm -Stat "mem.usage.average" -MaxSamples $numsamples -Start (Get-Date).AddDays(-$numPastDays) -IntervalMins $sampleIntevalsMinutes | measure -Property Value -Average).Average	
				$netStats = "{0:n2}" -f $(Get-Stat -Entity $vm -Stat "net.usage.average" -MaxSamples $numsamples -Start (Get-Date).AddDays(-$numPastDays) -IntervalMins $sampleIntevalsMinutes | measure -Property Value -Average).Average
				$balloonStats = "{0:n2}" -f $(Get-Stat -Entity $vm -Stat "mem.vmmemctl.average" -MaxSamples $numsamples -Start (Get-Date).AddDays(-$numPastDays) -IntervalMins $sampleIntevalsMinutes | measure -Property Value -Average).Average
				$swapStats = "{0:n2}" -f $(Get-Stat -Entity $vm -Stat "mem.swapped.average" -MaxSamples $numsamples -Start (Get-Date).AddDays(-$numPastDays) -IntervalMins $sampleIntevalsMinutes | measure -Property Value -Average).Average
			}
			
			if (!$cpuStats -or ($cpuStats -eq -1))
			{
				$GuestConfig | Add-Member -Type NoteProperty -Name "Avg CPU Usage" -Value "-" ;
			} else {
				$GuestConfig | Add-Member -Type NoteProperty -Name "Avg CPU Usage" -Value $("{0:N2} %" -f $cpuStats) ;
			}
			
			if (!$memStats -or ($memStats -eq -1))
			{
				$GuestConfig | Add-Member -Type NoteProperty -Name "Avg Memory Usage" -Value  "-";			
			} else {
				$GuestConfig | Add-Member -Type NoteProperty -Name "Avg Memory Usage" -Value  $("{0:N2} %" -f $memStats)			
			}
			if (!$netStats -or ($netStats -eq -1))
			{
				$GuestConfig | Add-Member -Type NoteProperty -Name "Avg Throughput KBps" -Value "-";
			} else {
				$GuestConfig | Add-Member -Type NoteProperty -Name "Avg Throughput KBps" -Value "$netStats" ;
			}
			
			if (!$balloonStats -or ($balloonStats -le 0) -or ($balloonStats.GetType().Name -eq "string"))
			{
				$GuestConfig | Add-Member -Type NoteProperty -Name "Balloon" -Value "-" ;
			} else {
				$GuestConfig | Add-Member -Type NoteProperty -Name "Balloon" -Value $(getSize -unit "KB" -val $balloonStats) ;
			}
			
			if (!$swapStats -or ($swapStats -le 0) -or ($swapStats.GetType().Name -eq "string"))
			{
				$GuestConfig | Add-Member -Type NoteProperty -Name "Swap" -Value "-" ;
			} else {
				$GuestConfig | Add-Member -Type NoteProperty -Name "Swap" -Value $(getSize -unit "KB" -val $swapStats);
			}
			$GuestConfig | Add-Member -Type NoteProperty -Name "Power State" -Value $vm.PowerState;
			$GuestConfig | Add-Member -Type NoteProperty -Name "Tools Status" -Value $vm.ExtensionData.Guest.ToolsStatus;
            $GuestConfig | Add-Member -Type NoteProperty -Name "vCPU" -Value  $vm.ExtensionData.Summary.Config.NumCPU;
            $GuestConfig | Add-Member -Type NoteProperty -Name "Memory" -Value $vm.ExtensionData.Summary.Config.MemorySizeMB;            
            $GuestConfig | Add-Member -Type NoteProperty -Name "Size Deployed" -Value $(getSize -unit "B" -val $(($vm.ExtensionData.Summary.Storage.Committed + $vm.ExtensionData.Summary.Storage.Uncommitted))) # "$([math]::Round(($vm.ExtensionData.Summary.Storage.Committed + $vm.ExtensionData.Summary.Storage.Uncommitted) / 1gb,2));
            $GuestConfig | Add-Member -Type NoteProperty -Name "Size On Disk" -Value  $(getSize -unit "B" -val $($vm.ExtensionData.Summary.Storage.Committed)) #"$([math]::Round($vm.ExtensionData.Summary.Storage.Committed/1gb,2));
            $GuestConfig | Add-Member -Type NoteProperty -Name "Shared Disks" -Value  $(getSize -unit "B" -val $($($vm.ExtensionData.Summary.Storage.Committed - $vm.ExtensionData.Summary.Storage.unshared))) #"$([math]::Round($vm.ExtensionData.Summary.Storage.Committed - $vm.ExtensionData.Summary.Storage.unshared,2))";
            $GuestConfig | Add-Member -Type NoteProperty -Name "Disk Count" -Value  $vm.ExtensionData.Summary.Config.NumVirtualDisks;
            $GuestConfig | Add-Member -Type NoteProperty -Name "Datastore Count" -Value  $vm.ExtensionData.Config.datastoreurl.Count;
			$GuestConfig | Add-Member -Type NoteProperty -Name "Nic Count" -Value  $vm.ExtensionData.Summary.Config.NumEthernetCards;
            $GuestConfig | Add-Member -Type NoteProperty -Name "Last Modified" -Value  $lastModifiedEventCreationTime; #$modifiedDate;
            $GuestConfig | Add-Member -Type NoteProperty -Name "Last Modified By" -Value  $lastModifiedUser; #$modifiedDate;
            $GuestConfig | Add-Member -Type NoteProperty -Name "Is Template" -Value $vm.ExtensionData.Config.Template;
            $GuestConfig | Add-Member -Type NoteProperty -Name "VM Version" -Value $vm.Version;            
			$GuestConfig | Add-Member -Type NoteProperty -Name "Guest State" -Value $vm.ExtensionData.Guest.GuestState;
            $GuestConfig | Add-Member -Type NoteProperty -Name "Guest Hostname" -Value $vm.ExtensionData.Guest.HostName;

             
            if (!$skipEvents)
            { 
                $GuestConfig | Add-Member -Type NoteProperty -Name "Commissioned Date" -Value $Created;
                $GuestConfig | Add-Member -Type NoteProperty -Name "Commissioned By" -Value $User;
            }
			#$GuestConfig | Add-Member -Type NoteProperty -Name "PortGroup" -Value  $(($vm.ExtensionData.Config.Hardware.Device | ?{$_.key -match 4000}).DeviceInfo.Summary);
			
            $GuestConfig | Add-Member -Type NoteProperty -Name "Cpu Reservations" -Value  $vm.ExtensionData.ResourceConfig.CpuAllocation.Reservation;
            $GuestConfig | Add-Member -Type NoteProperty -Name "Cpu Reservations Expandable" -Value  $vm.ExtensionData.ResourceConfig.CpuAllocation.ExpandableReservation;
            $GuestConfig | Add-Member -Type NoteProperty -Name "Cpu Limits" -Value  $vm.ExtensionData.ResourceConfig.CpuAllocation.Limit;
            $GuestConfig | Add-Member -Type NoteProperty -Name "Cpu Shares" -Value  $vm.ExtensionData.ResourceConfig.CpuAllocation.Shares.Shares;
            $GuestConfig | Add-Member -Type NoteProperty -Name "Cpu Affinity" -Value $vm.ExtensionData.Config.CpuAffinity;
            $GuestConfig | Add-Member -Type NoteProperty -Name "Ram Reservations" -Value  $vm.ExtensionData.ResourceConfig.MemoryAllocation.Reservation;
            $GuestConfig | Add-Member -Type NoteProperty -Name "Ram ReservationsExp" -Value  $vm.ExtensionData.ResourceConfig.MemoryAllocation.ExpandableReservation;
            $GuestConfig | Add-Member -Type NoteProperty -Name "Ram Limits" -Value  $vm.ExtensionData.ResourceConfig.MemoryAllocation.Limit;
            $GuestConfig | Add-Member -Type NoteProperty -Name "Ram Shares" -Value  $vm.ExtensionData.ResourceConfig.MemoryAllocation.Shares.Shares;
            $GuestConfig | Add-Member -Type NoteProperty -Name "Ram Overhead Limits" -Value  $vm.ExtensionData.ResourceConfig.MemoryAllocation.OverheadLimit;
            $GuestConfig | Add-Member -Type NoteProperty -Name "Ram Affinity" -Value $vm.ExtensionData.Config.MemoryAffinity ;
            # Custom Attributes
			if ($vm.ExtensionData.AvailableField) {
				foreach ($field in $vm.ExtensionData.AvailableField) {
					$custField = $vm.ExtensionData.CustomValue | ?{$_.Key -eq $field.Key}
					$GuestConfig | Add-Member -Type NoteProperty -Name $field.Name -Value $custField.Value
				}
			}
            if (!$showOnlyTemplates)
            {
                $GuestConfig | Add-Member -Type NoteProperty -Name "NIC 1 Type" -Value  $vm.NetworkAdapters[0].Type;
                $GuestConfig | Add-Member -Type NoteProperty -Name "NIC 1 Portgroup" -Value  $vm.NetworkAdapters[0].NetworkName;
                $GuestConfig | Add-Member -Type NoteProperty -Name "NIC 1 MAC" -Value  $vm.NetworkAdapters[0].MacAddress;
            }
           
            $GuestConfig | Add-Member -Type NoteProperty -Name "Primary IP Address" -Value $vm.Guest.IpAddress[0];

			$GuestConfig | Add-Member -Type NoteProperty -Name "VMware Tools Version" -Value  $vm.ExtensionData.Config.Tools.ToolsVersion;
            $GuestConfig | Add-Member -Type NoteProperty -Name "VMware Tools Status" -Value  $vm.ExtensionData.Summary.Guest.ToolsVersionStatus;
            $GuestConfig | Add-Member -Type NoteProperty -Name "VMware Tools Update On Boot" -Value  $vm.ExtensionData.Config.Tools.ToolsUpgradePolicy;
            $GuestConfig | Add-Member -Type NoteProperty -Name "VM Snapshots" -Value  $vm.Snapshot.Count;
			$GuestConfig | Add-Member -Type NoteProperty -Name "Sync Time With Host" -Value $vm.ExtensionData.Config.Tools.SyncTimeWithHost;
			$GuestConfig | Add-Member -Type NoteProperty -Name "Boot Time" -Value  $vm.ExtensionData.Runtime.BootTime;
            $GuestConfig | Add-Member -Type NoteProperty -Name "VMX UUID" -Value  $vm.ExtensionData.Config.Uuid;
            $GuestConfig | Add-Member -Type NoteProperty -Name "vCenter UID" -Value  $vm.ExtensionData.Config.InstanceUuid;

            $GuestConfig | Add-Member -Type NoteProperty -Name "Boot Delay" -Value $bootDelay;
			$GuestConfig | Add-Member -Type NoteProperty -Name "VMX Location" -Value $vMPathName;
            if ($($($vm.ExtensionData.Config.ExtraConfig | ?{$_.Key -eq "ctkEnabled"}).Value))
            {
                $GuestConfig | Add-Member -Type NoteProperty -Name "ctkEnabled" -Value $($($vm.ExtensionData.Config.ExtraConfig | ?{$_.Key -eq "ctkEnabled"}).Value);
            }

            $GuestConfig | Add-Member -Type NoteProperty -Name "Cluster" -Value $cluster;
            $GuestConfig | Add-Member -Type NoteProperty -Name "Resource Pool Name" -Value $resourcePool;
            $GuestConfig | Add-Member -Type NoteProperty -Name "vCenter Server" -Value $vcenterName;
            $GuestConfig | Add-Member -Type NoteProperty -Name "Datacenter" -Value $datacenter ;
            $GuestConfig | Add-Member -Type NoteProperty -Name "vCenter Folder" -Value $vcFolder;
            
            if ($($vm.ExtensionData.Config.ExtraConfig | ?{$_.Key -match "usb"})) { 
                $GuestConfig | Add-Member -Type NoteProperty -Name "USB Device" -Value "Yes";
                $vm.ExtensionData.Config.ExtraConfig | ?{$_.Key -match "usb"} | %{
                    $GuestConfig | Add-Member -Type NoteProperty -Name $($_.Key) -Value $($_.Value);
                }
            } else {
                $GuestConfig | Add-Member -Type NoteProperty -Name "USB Device" -Value "No";
            }
			# Enumerate VMs VMDK(s)
			$vmdks = Get-HardDisk -VM $vm.Name;
			$i=1;
			if ($vmdks.Filename -or $vmdks.Count -gt 0)
			{
				if ($vmdks.Filename) {
					$GuestConfig | Add-Member -Type NoteProperty -Name "VMDK Count" -Value "1";
				} 
				else 
				{
					$GuestConfig | Add-Member -Type NoteProperty -Name "VMDK Count" -Value $vmdks.Count;
				}
				foreach ($vmdk in $vmdks) 
				{
					#$diskpath = $vmdk.Filename;
					#logThis -msg $vmdk.Filename -ForegroundColor blue
					$datastore,$onDiskName = $vmdk.Filename.Split(" ");
					$datastore = $datastore -replace "\[","";
					$datastore = $datastore -replace "\]","";
					$GuestConfig | Add-Member -Type NoteProperty -Name "VMDK$($i) Disk name" -Value $vmdk.Name;
					$GuestConfig | Add-Member -Type NoteProperty -Name "VMDK$($i) OnDisk name" -Value $onDiskName;
					$GuestConfig | Add-Member -Type NoteProperty -Name "VMDK$($i) Capacity" -Value $(getSize -unit "KB" -val $($vmdk.CapacityKB)) # "$([math]::Round($vmdk.CapacityKB/1Mb))";
					$GuestConfig | Add-Member -Type NoteProperty -Name "VMDK$($i) Disk Type" -Value $vmdk.DiskType;
					$GuestConfig | Add-Member -Type NoteProperty -Name "VMDK$($i) Persistence" $vmdk.Persistence;
					$GuestConfig | Add-Member -Type NoteProperty -Name "VMDK$($i) Format" $vmdk.StorageFormat;
					$GuestConfig | Add-Member -Type NoteProperty -Name "VMDK$($i) Datastore" -Value $datastore;
					$i++;
				}
			} 
			else 
			{ 
				$GuestConfig | Add-Member -Type NoteProperty -Name "VMDK Count" -Value "0";
			}
			

			
			# Enumerate Guest volume(s)
			$guestdisks = $vm.ExtensionData.Guest.Disk;
			$i=1
			if ($guestdisks.DiskPath -or  $guestdisks.Count -gt 0)
			{
				if ($guestdisks.DiskPath) {
					$GuestConfig | Add-Member -Type NoteProperty -Name "Guest Volumes" -Value  "1";
				} else {
					$GuestConfig | Add-Member -Type NoteProperty -Name "Guest Volumes" -Value  $guestdisks.Count;
				}
				foreach ($guestdisk in $guestdisks)
				{	
					#logThis -msg $guestdisk.DiskPath -BackgroundColor Cyan
					$GuestConfig | Add-Member -Type NoteProperty -Name "Volume$($i)" -Value $guestdisk.DiskPath;
					$GuestConfig | Add-Member -Type NoteProperty -Name "Volume$($i) FreeSpace" -Value $(getSize -unit "B" -val $guestdisk.FreeSpace) # "$([math]::Round($guestdisk.FreeSpace/1Mb))";
					$GuestConfig | Add-Member -Type NoteProperty -Name "Volume$($i) Capacity" -Value $(getSize -unit "B" -val $guestdisk.Capacity) #"$([math]::Round($guestdisk.Capacity/1Mb))";
					$GuestConfig | Add-Member -Type NoteProperty -Name "Volume$($i) PercFree" -Value "$([math]::Round( (100*($guestdisk.Freespace/$guestdisk.Capacity))))";
					$i++;
				}
			} 
			else 
			{ 
				$GuestConfig | Add-Member -Type NoteProperty -Name "Volumes Count" -Value  "0";
			}

			
    		if ($verbose)
            {
                logThis -msg $GuestConfig;
            }
    		$GuestConfig;
            $index++;
        }
    } # if ($vms)
}

# Fix the object array, ensure all objects within the 
# array contain the same members (required for Format-Table / Export-CSV)
$loop = 1;
$continue = $true;
logThis -msg "-> Fixing the object arrays <-" -ForegroundColor Magenta
while ($continue)
{
	logThis -msg "Loop index: " $loop;
	$continue = $false;
	
	$Members = $run1Report | Select-Object `
	@{n='MemberCount';e={ ($_ | Get-Member).Count }}, `
	@{n='Members';e={ $_.PsObject.Properties | %{ $_.Name } }}
	$AllMembers = ($Members | Sort-Object MemberCount -Descending)[0].Members
	
	$Report = $run1Report | %{
		ForEach ($Member in $AllMembers)
		{
			If (!($_ | Get-Member -Name $Member))
			{ 
				$_ | Add-Member -Type NoteProperty -Name $Member -Value "[N/A]"
				$continue = $true;
			}
		}
		Write-Output $_
	}
	
	$run1Report = $Report;
	$loop++;
}


ExportCSV -table $Report

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
	logThis -msg "-> Disconnected from $srvConnection.Name <-" -ForegroundColor Magenta
}

logThis -msg "Log file written to $($global:logfile)" -ForegroundColor Yellow