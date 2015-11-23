$runas = $false
if ($runas)
{
	$server=""
	$cred = Get-Credential
	$session = New-PSSession -Credential $cred -ComputerName $server
	Enter-PSSession $session
}

# Variables
$DateStamp = get-date -uformat "%m-%d-%Y"
# path and filename for report file
$computers = $Env:COMPUTERNAME
$file = ".\getmvlist-$computers-$DateStamp.txt"


# put todays date and time in the file
echo "Date report was ran" | out-file $file
get-date | out-file $file -append

echo "Reading in VM list from $computers"
$VMS = get-vm | select * | sort Name



# get the vhost uptime
Get-CimInstance Win32_OperatingSystem -comp $computers | Select @{Name="VHostName";Expression={$_."csname"}},@{Name="Uptime=D.H:M:S.Millseconds";Expression={(Get-Date) - $_.LastBootUpTime}},LastBootUpTime | format-table * -autosize -Wrap | out-string -width 4096 | out-file $file -append

# get the vhost name, total virtual CPU count, total RAM, virtualharddiskpath and virtualmachinepath
Get-VMHost | Select @{Name="VHostName";Expression={$_."Name"}},@{N="Total RAM(GB)";E={""+ [math]::round($_.Memorycapacity/1GB)}},logicalprocessorcount,virtualharddiskpath,virtualmachinepath | format-table * -autosize -Wrap | out-string -width 4096 | out-file $file -append

echo "VHOST Server IP Addresses and NIC's" | out-file $file -append
Get-WMIObject win32_NetworkAdapterConfiguration |   Where-Object { $_.IPEnabled -eq $true } | Select IPAddress,Description | format-table * -autosize -Wrap | out-string -width 4096 | out-file $file -append

echo "VHOST Server drive C: Disk Space" | out-file $file -append
# to get D: drive add ,D after C  - E: drive ,E etc.
Get-psdrive C | Select Root,@{N="Total(GB)";E={""+ [math]::round(($_.free+$_.used)/1GB)}},@{N="Used(GB)";E={""+ [math]::round($_.used/1GB)}},@{N="Free(GB)";E={""+ [math]::round($_.free/1GB)}} | format-table * -autosize -Wrap | out-string -width 4096 | out-file $file -append

echo "VHosts virtual switch(s) information" | out-file $file -append
get-vmswitch * | out-file $file -append

echo "Total number of VM's on server" | out-file $file -append
echo "------------------------------" | out-file $file -append
$VMS.Count | out-file $file -append
echo " " | out-file $file -append

echo "NOTE: Nothing listed under DVD Media Path = Nothing mounted in DVD" | out-file $file -append
$outputArray = @()
$index=0
foreach($VM in $VMS)
{ 
	Write-Progress -Activity "Processing VMs.." -CurrentOperation "$index/$($VMS.Count ) :- $($VM.Name)" -PercentComplete ($index /  $VMS.Count * 100)
	$VMsRAM = [math]::round($VM.Memoryassigned/1GB,2)
	$VMsCPU = $VM.processorCount
	$VMsState = $VM.State
	$VMsStatus = $VM.Status
	$VMsUptime = $VM.Uptime
	$VMsAutomaticstartaction = $VM.Automaticstartaction
	$VMsIntegrationServicesVersion = $VM.IntegrationServicesVersion
	$VMsReplicationState = $VM.ReplicationState
	$HardDisks = Get-VMHardDiskDrive -VMName $vm.Name
	$HardDisksCount = ($HardDisks | measure).Count
	$passthruDisks=$HardDisks | ?{$_.DiskNumber}
	$passthruDisksCount = ($passthruDisks | measure).Count
	$passthruDisksSizeGB = ($passthruDisks | %{ ($passthruDisks.Path -split " ")[2]} | measure -Sum).Sum

	$VHDs = Get-VHD -VMId $VM.VMiD
	$VHDsGB = $VHDs.FileSize | %{ [Math]::round($_/1GB,2) }
	$TotalVHDsGB = [Math]::round(($VHDs | measure -Property FileSize -Sum).Sum/1gb,2)
	$VMDVD = Get-vmdvddrive -VMname $VM.VMname

	$output = new-object psobject
	$output | add-member noteproperty "VM Name" $VM.Name
	$output | add-member noteproperty "RAM(GB)" $VMsRAM
	$output | add-member noteproperty "vCPU" $VMsCPU
	$output | add-member noteproperty "Disk Usage GB" ($TotalVHDsGB + $passthruDisksSizeGB)
	$output | add-member noteproperty "Disks" $HardDisksCount #$(($VHDs.FileSize | measure).Count)
	$output | add-member noteproperty "State" $VMsState
	$output | add-member noteproperty "Status" $VMsStatus
	$output | add-member noteproperty "Uptime" $VMsUptime
	$output | add-member noteproperty "Start Action" $VMsAutomaticstartaction
	$output | add-member noteproperty "Integration Tools" $VMsIntegrationServicesVersion
	$output | add-member noteproperty "Replication State" $VMsReplicationState
	$VM | select "Mem*" | gm -Type NoteProperty | %{ 
		#Write-Host "`tGetting $($_.Name)"
		#$output | add-member noteproperty $_.Name $([Math]::Round($VM.$($_.Name)/1gb,2))
		$output | add-member noteproperty $_.Name $VM.$($_.Name)
	}
	$DiskDetails=""
	$DiskDetails=$VHDs | %{
	"$($_.Path) ($([math]::round($_.Size/1gb,2)) GB,$($_.VhdFormat),$($_.VhdType))"
	}
	$DiskDetails += $passthruDisks | %{
		$disk=$_
		$type="Passthrough"
		$sizeGB=($disk.Path -split " ")[2,3] -join " "
		$DiskPath=$disk.Path -replace $sizeGB,""
		"$DiskPath ($sizeGB,$type)"
	}
	$output | add-member noteproperty "Disk Details" $($DiskDetails -join ", ")

	$output | add-member noteproperty "DVD Media Type" $VMDVD.dvdmediatype
	$output | add-member noteproperty "DVD Media Path" $VMDVD.path
	$outputArray += $output
	$index++
}
	  
#$outputarray[6]
$outputarray | Export-Csv -NoTypeInformation $($file -replace ".txt","-VMsDetails.csv")
	
write-output $outputarray | sort "VM Name" | format-table * -autosize -Wrap | out-string -width 4096 | out-file $file -append

Echo "VM's BIOS setting" | out-file $file -append
 get-vmbios *  | sort "VMName" | format-table * -autosize -Wrap | out-string -width 4096 | out-file $file -append

 echo "VM's Virtual Switch name and IP address" | out-file $file -append
 get-vmnetworkadapter * | Select vmname,switchname,ipaddresses | format-table * -autosize -Wrap | out-string -width 4096 | out-file $file -append

 echo "VM's Snapshot and location" | out-file $file -append
 echo "If nothing is Listed below, then there are no Snapshots" | sort "VMName" | format-table * -autosize -Wrap | out-string -width 4096 | out-file $file -append
 get-vmsnapshot -vmname * | out-file $file -append

 #load the report in notepad
 notepad.exe "$file"