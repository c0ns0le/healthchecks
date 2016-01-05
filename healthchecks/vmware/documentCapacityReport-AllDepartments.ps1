# Determines the Total capacity (Number of VMS, amt CPU, amt Memory, amt Disk) exist  in each
# "root" Folders within the "Virtual Machine and Template" Inventory
#Version : 0.1
#Updated : 27th Feb 2012
#Author  : teiva.rodiere-at-gmail.com
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$verbose=$true)

function ShowSyntax() {
	Write-host "" -ForegroundColor $global:colours.Information 
	Write-host " Syntax: ./CapacityReport-AllDepartments.ps1 -srvConnection `$srvConnection" -ForegroundColor $global:colours.Information 
	Write-host "" -ForegroundColor $global:colours.Information 
	Write-host "`$srvConnection: You can obtain this variable by first executing a command like this: `$srvConnection = Connect-VIServer vcenterServerFQDN" -ForegroundColor $global:colours.Information 
	Write-host "" -ForegroundColor $global:colours.Information 
}

function VerboseToScreen([string]$msg,[string]$color="White",[bool]$newline=$false)
{
	if ($verbose) {write-host $msg  -foregroundcolor $color }
}

VerboseToScreen "Executing script $($MyInvocation.MyCommand.path)" "Green";
VerboseToScreen "Current path is $($pwd.path)" "yellow"

if (!$srvConnection -and !$vmName) {
	ShowSyntax
	exit
}

$disconnectOnExist = $true;

if (!$srvConnection)
{ 
	$vcenterName = Read-Host "Enter virtual center server name"
	VerboseToScreen "Connecting to virtual center server $vcenterName.."
	$srvConnection = Connect-VIServer -Server $vcenterName
	$disconnectOnExist = $true;	
} else {
	$disconnectOnExist = $false;
	$vcenterName = $srvConnection.Name;
}

if ((Test-Path -path $logDir) -ne $true) {
	New-Item -type directory -Path $logDir
}


$filename = ($($MyInvocation.MyCommand.Name)).TrimEnd('.ps1');

VerboseToScreen "$filename";

if ($comment -eq "" ) {
	$of = $logDir + "\"+$filename+"-"+$vcenterName+".csv"
} else {
	$of = $logDir + "\"+$filename+"-"+$comment+".csv"
}
VerboseToScreen "This script log to $of" "Yellow"

VerboseToScreen "Loading VMs..." "Yellow" 
$allVMs = Get-VM * -Server $srvConnection;
$totalVMsCount = $allVMs.Count
VerboseToScreen "Total Count=$totalVMsCount" "Green";
$totalVMsCPU = 0; 
$totalVMsRAM = 0;
$totalVMDiskGbProvisioned = 0;
$totalVMDiskGbUsed = 0;

$allVMs | %{$totalVMsCPU += $_.NumCPU};
$allVMs | %{$totalVMsRAM += $_.MemoryMB};
$allVMs | %{$totalVMDiskGbUsed += $_.UsedSpaceGB};
$allVMs | %{$totalVMDiskGbProvisioned += $_.ProvisionedSpaceGB};

VerboseToScreen "Folders to process" "Yellow"  
$folderIndex=1
$folders = Get-Folder -Server $srvConnection | ?{$_.IsChildTypeVm -eq $true -and $_.Parent -like "vm"} | select-object * | Sort-Object "Name"
VerboseToScreen "$($folders.Count)" "Green"
VerboseToScreen "" "Green"

$Report = $folders | %{ 
	VerboseToScreen "Processing ""$($_.Name)"" [$folderIndex/$($folders.Count)]..." "Yellow"
	$cmdb = ""| Select-Object "vFolder"
	#VerboseToScreen   $totalVMsCPU,$totalVMsRAM,$totalVMDiskGbUsed,$totalVMDiskGbProvisioned
	$cmdb.vFolder = $_.Name;
	$vms = Get-VM * -Location $_.Name;
	$folderVMCount=0;
	$folderVMsCPU=0;
	$folderVMsRAM=0;
	$folderVMDiskGbProvisioned=0;
	$folderVMDiskGbUsed=0;
	$VMCountPerc=0;
	$VMsCPUPerc=0;
	$VMsRAMPerc=0;
	$VMDiskGbUsedPerc=0;
	$VMDiskGbProvisionedPerc=0;
	if ($vms.Count)	{	
		$folderVMCount = $vms.Count
		
		$vms | %{$folderVMsCPU += $_.NumCPU};
		$vms | %{$folderVMsRAM += $_.MemoryMB};
		$vms | %{$folderVMDiskGbProvisioned +=$_.ProvisionedSpaceGB};
		$vms | %{$folderVMDiskGbUsed +=$_.UsedSpaceGB};
		$VMCountPerc = [math]::round($folderVMCount/$totalVMsCount*100,2);
		$VMsCPUPerc = [math]::round($folderVMsCPU/$totalVMsCPU*100,2);
		$VMsRAMPerc = [math]::round($folderVMsRAM/$totalVMsRAM*100,2);
		$VMDiskGbUsedPerc = [math]::round($folderVMDiskGbUsed/$totalVMDiskGbUsed*100,2);
		$VMDiskGbProvisionedPerc = [math]::round($folderVMDiskGbProvisioned/$totalVMDiskGbProvisioned*100,2);
		VerboseToScreen   $totalVMsCPU,$totalVMsRAM,$totalVMDiskGbUsed,$totalVMDiskGbProvisioned
		VerboseToScreen   $folderVMsCPU,$folderVMsRAM,$folderVMDiskGbUsed,$folderVMDiskGbProvisioned
		VerboseToScreen "Total VMs in folder = $($vms.Count)" "Yellow"
		
	} else {
		VerboseToScreen "Total VMs in folder = 0" "Yellow"
	}

	#VerboseToScreen " $($VMsCPU,$VMsCPU,$VMsRAM, $VMDiskGbProvisioned, $VMDiskGbUsed)" "Yellow"

	$cmdb | Add-Member -Type NoteProperty -Name "VMCount" -Value $folderVMCount;
	$cmdb | Add-Member -Type NoteProperty -Name "VMCountPerc" -Value "$($VMCountPerc)%"
	$cmdb | Add-Member -Type NoteProperty -Name "CpuCount" -Value $folderVMsCPU;
	$cmdb | Add-Member -Type NoteProperty -Name "CpuCountPerc" -Value "$($VMsCPUPerc)%";
	$cmdb | Add-Member -Type NoteProperty -Name "RamCount" -Value $folderVMsRAM;
	$cmdb | Add-Member -Type NoteProperty -Name "RamCountPerc" -Value "$($VMsRAMPerc)%";
	$cmdb | Add-Member -Type NoteProperty -Name "DiskUsageGb" -Value $folderVMDiskGbUsed ;
	$cmdb | Add-Member -Type NoteProperty -Name "DiskUsageGbPerc" -Value "$($VMDiskGbUsedPerc)%";
	$cmdb | Add-Member -Type NoteProperty -Name "DiskProvisionedGB" -Value $folderVMDiskGbProvisioned;
	$cmdb | Add-Member -Type NoteProperty -Name "DiskProvisionedGBPerc" -Value "$($VMDiskGbProvisionedPerc)%";
	VerboseToScreen $cmdb;
	$cmdb
	++$folderIndex;
}


Write-Output $Report | Export-Csv $of -NoTypeInformation
Write-Output "" >> $of
Write-Output "" >> $of
Write-Output "Collected on $(get-date)" >> $of

Write-Host "Logs written to " $of -ForegroundColor  yellow;

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}