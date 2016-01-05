# Lists the VMDK Disks for a VM
#Version : 0.1
#Updated : 21th Sept 2009
#Author  : teiva.rodiere-at-gmail.com 
# Syntaxt: exportVM_VMDKInformation.ps1 VSVWIN2003E055
# Syntaxt for multiple VMs: exportVM_VMDKInformation.ps1 NAME1 NAME2 NAME3
# Syntax Exporting to CSV: exportVM_VMDKInformation.ps1 VMNAME1 | Export-CSV ".\filename.csv"
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[string]$scanType="one",[bool]$showTimestamp=$true)
Write-Host "Executing script $($MyInvocation.MyCommand.path)" -ForegroundColor  green;
Write-Host "Current path is $($pwd.path)" -ForegroundColor  yellow;

$disconnectOnExist = $true;

if (!$srvConnection -or ( ($srvconnection.GetType().Name -ne "VIServerImpl") -and ($srvconnection.GetType().Name -ne "Object[]") ) )
{
	$vcenterName = Read-Host "Enter virtual center server name"
	Write-Host "Connecting to virtual center server $vcenterName.."
	$srvConnection = Connect-VIServer -Server $vcenterName
	$disconnectOnExist = $true;	
} else {
	$disconnectOnExist = $false;
	$vcenterName = $srvConnection.Name;
}

if ((Test-Path -path $logDir) -ne $true) {
	New-Item -type directory -Path $logDir
}


$runtime="$(date -f dd-MM-yyyy)"
$filename = ($($MyInvocation.MyCommand.Name)).TrimEnd('.ps1');
Write-Host "$filename";
if ($comment -eq "" ) {
	$of = $logDir + "\"+$runtime+"_"+$vcenterName.ToUpper()+"_"+$filename+".csv"
} else {
	$of = $logDir + "\"+$runtime+"_"+$vcenterName.ToUpper()+"_"+$filename+"-"+$comment+".csv"
}
Write-Host "This script log to " $of -ForegroundColor $global:colours.Information 

#$vCenterServers = "srvds3350x001.corporate.transgrid.local","SRVDWX3350X003.corporate.transgrid.local","SRVDSX3850X001.corporate.transgrid.local"
s = Connect-VIServer -Server $vCenterServers 

if ($args.Count -eq 0) {
	$VMNames = Read-Host "Enter VM name"
} else {
	$VMNames = $args
}
#######################################
# Start of script
if ($VMNames -eq ""){
	Write-Host
	Write-Host "Please specify 1 or multple virtual machine(s) name name eg...."
	Write-Host "      powershell.exe .ps1 MYVM"
	Write-Host
	Write-Host
	exit
} else {
	#foreach ($srvconnection in $srvconnections) {
		$vms= Get-VM $VMNames -Server $srvconnection -ErrorAction SilentlyContinue
		foreach ($vm in $vms) {
			if ($vm) { 
				$row = "" | Select VMName,GuestFullName,GuestState,ToolsStatus,ToolsVersion,DiskNumber,DiskName,VMDKCapacityGB,Persistent,Datastore,DatastoreCapacityLeftGB,MountPoint,CapacityGB,FreeSpaceGB,PercFree,Cluster;
				$row.VMName = $vm.Name;
				$row.Cluster = ($vm | Get-Cluster).Name;
				$row.ToolsStatus = $vm.Guest.ToolsStatus;
				$row.GuestState = $vm.Guest.GuestState;
				$row.ToolsVersion = $vm.Guest.ToolsVersion;
				$row.GuestFullName = $vm.Guest.GuestFullName;
				$guestdisks = $vm.Guest.Disks;
				$vmdkdisks = Get-HardDisk -VM $vm;
				for ($i = 0; $i -lt $guestdisks.Length; $i++) 
				{	
					if ($vmdkdisks.GetType().Name -eq "Object[]") {
						$disk = $vmdkdisks[$i];
					} else {
						$disk = $vmdkdisks;
					}
					if ($disk)
					{
						$diskpath = $disk.Filename;
						$datastore,$vmdk = $diskpath.Split(" ");
						$datastore = $datastore -replace "\[", " ";
						$datastore = $datastore -replace "\]","";
						$row.DiskNumber = $i+1;
						$row.DiskName = $vmdk;
						$row.VMDKCapacityGB = [math]::Round($disk.CapacityKB/1Mb);
						$row.Persistent = $disk.Persistence;
						$row.Datastore = $datastore;
						
						$guestdisk = "";
						$row.MountPoint = "";
						$row.FreeSpaceGB = 0;
						$row.CapacityGB = 0;
						$row.PercFree = 0;
						
						#if ($row.GuestState)
						#{
							$guestdisk = $guestdisks[$i];
							$row.MountPoint = $guestdisk.Path;
							$row.FreeSpaceGB = [math]::Round($guestdisk.FreeSpace/1Gb);
							$row.CapacityGB = [math]::Round($guestdisk.Capacity/1Gb);
							if ($guestdisk.Capacity) {
								$row.PercFree = [math]::Round( (100*($guestdisk.Freespace/$guestdisk.Capacity)));
							}	
							Write-Output $row;
						#}
					}
				}	
################# Insert Code here ##############################################
####################			
			}
		}
	#}
}