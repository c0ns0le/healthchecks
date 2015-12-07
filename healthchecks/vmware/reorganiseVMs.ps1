# This scripts reads in the output CSV file from "documentVMGuests.ps1". It takes the name of a VM, moves the VM to the correct vFolder or Resource pool, or both
# Syntax: reorganiseVMs.ps1 -cluster clustername -executeMode [readonly|doit] -action [vfolderonly|rponly|both] -if inputfile.csv
# Version : 0.3
#Author : 11/06/2010, by teiva.rodiere-at-gmail.com
param([object]$srvConnection="",[string]$logDir="output", [string]$if="", [string]$cluster="", [string]$datacenter="", [string]$executeMode="readonly", [string]$action="")
Write-Host "Executing script $($MyInvocation.MyCommand.path)" -ForegroundColor  green;
Write-Host "Current path is $($pwd.path)" -ForegroundColor  yellow;

$disconnectOnExist = $true;

function Showsyntax([string]$clusterName)
{
	Write-Output "Syntax: reorganiseVMs.ps1 -datacenter dcname -cluster clustername -executeMode [readonly|doit] -action [vfolderonly|rponly|both] -if inputfile.csv"
	Write-Host "Example 1: C:\admin\powershell> C:\admin\powershell\reorganiseVMs.ps1 -cluster $clusterName -executeMode doit -action both -if documentVMGuests.csv -datacenter Customer_CENTRAL"
	Write-Host "Example 2: C:\admin\powershell> C:\admin\powershell\reorganiseVMs.ps1 -cluster $clusterName -executeMode doit -action rponly -if documentVMGuests.csv -datacenter Customer_CENTRAL"
	Write-Host "Example 3: C:\admin\powershell> C:\admin\powershell\reorganiseVMs.ps1 -cluster $clusterName -executeMode doit -action vfolderonly -if documentVMGuests.csv -datacenter Customer_CENTRAL"
	Write-Host "Example 4: C:\admin\powershell> C:\admin\powershell\reorganiseVMs.ps1 -cluster $clusterName -executeMode readonly -action both -if documentVMGuests.csv -datacenter Customer_CENTRAL"
	Write-Host "Example 5: C:\admin\powershell> C:\admin\powershell\reorganiseVMs.ps1 -cluster $clusterName -executeMode readonly -action rponly -if documentVMGuests.csv -datacenter Customer_CENTRAL"
	Write-Host "Example 6: C:\admin\powershell> C:\admin\powershell\reorganiseVMs.ps1 -cluster $clusterName -executeMode readonly -action vfolderonly -if documentVMGuests.csv -datacenter Customer_CENTRAL"
	exit;
}

function MoveToVCFolder {
	param([string]$vmname="", [string]$folderName="", [string]$targetDatacenter="", [string]$targetCluster="")

	if ($vmname -eq "" -or $folderName -eq "" -or $targetDatacenter -eq "" -or $targetCluster -eq "")
	{
		Write-Host "Unable to process this VM [name="$vmname",resourcePoolName="$resourcePoolName",targetDatacenter"$targetDatacenter",targetCluster="$targetCluster"]" -ForegroundColor Red;
	} else {
		if ($executeMode -eq "readonly") {
			Write-Host "Move-VM -VM (Get-VM -Name "$vmname" -Location "$targetCluster") -Destination (Get-Folder -Name "$folderName" -Location "$targetDatacenter")"
		} else { 
			Write-Host "Move-VM -VM (Get-VM -Name "$vmname" -Location "$targetCluster") -Destination (Get-Folder -Name "$folderName" -Location "$targetDatacenter")"
			Move-VM -VM (Get-VM -Name "$vmname" -Location $targetCluster) -Destination (Get-Folder -Name "$folderName" -Location $targetDatacenter)
		}
	}
}

function MoveToRP {
	param([string]$vmname="", [string]$resourcePoolName="", [string]$targetDatacenter="", [string]$targetCluster="")
	
	if ($vmname -eq "" -or $resourcePoolName -eq "" -or $targetDatacenter -eq "" -or $targetCluster -eq "")
	{
		Write-Host "Unable to process this VM [name="$vmname",resourcePoolName="$resourcePoolName",targetDatacenter="$targetDatacenter",cluster="$targetCluster"]" -ForegroundColor Red;
	} else {
		#Move-VM -VM (Get-VM -Name XP_VC_Tech) -Destination (Get-Folder -Name Marketing-VM)
		if ($executeMode -eq "readonly") {
			Write-Host "Move-VM -VM (Get-VM -Name "$vmname" -Location="$targetCluster") -Destination (Get-ResourcePool -Name "$resourcePoolName" -Location "$targetCluster")"
		} else {
			Write-Host "Move-VM -VM (Get-VM -Name "$vmname" -Location="$targetCluster") -Destination (Get-ResourcePool -Name "$resourcePoolName" -Location "$targetCluster")"
			Move-VM -VM (Get-VM -Name "$vmname" -Location $targetCluster) -Destination (Get-ResourcePool -Name "$resourcePoolName" -Location $targetCluster)
		}
	}
}

if ($if -eq "" -or $datacenter -eq "" -or $cluster -eq "" -or $executeMode -eq "" -or $action -eq "")
{
	Showsyntax -clusterName "TEST_CLUSTER";
}

#if (!$srvConnection)
#{ 
#	$vcenterName = Read-Host "Enter virtual center server name"
#	Write-Host "Connecting to virtual center server $vcenterName.."
#	$srvConnection = Connect-VIServer -Server $vcenterName
#	$disconnectOnExist = $true;	
#} else {
#	$disconnectOnExist = $false;
#}

if ((Test-Path -path $logDir) -ne $true) {
	New-Item -type directory -Path $logDir
}

$of = $logDir + "\reorganiseVMs.csv"
Write-Host "This script log to " $of -ForegroundColor Yellow 
Write-Host "Host is running in processing mode: " $executeMode -ForegroundColor Black -BackgroundColor Red;


Write-Host "Reading in input file " $if -ForegroundColor Cyan;
$csvImport = Import-Csv $if;
if (!$csvImport)
{ 
	Write-Host "Invalid input file, the input file should be in the same format as"
	exit;
}

switch ($executeMode)
{
	"readonly" {
		Write-Host "Script running in [readonly] mode.." -ForegroundColor Yellow
	}
	"doit" { 
		Write-Host "Executing this script in write mode. Changes will be executed automatically" 
		$answer = Read-Host "Are you sure you want to continue [y/n]?" 
		if ($answer -eq "n" -or $answer -eq "no")
		{
			Write-Host "User Abort..."
			exit;
		}
	}
	default { 
		Write-Host "Invalid execution mode. Choose either [ readonly | doit ]"; 
		Write-Host "Aborting..."
		exit;
	}
}


foreach ($row in $csvImport) {

	$guestname = $row
	switch ($action)
	{
	"vfoldersonly" {
		Write-host "Moving"$row.GuestName" to vFolder ["$row.VCFolder "] specified in the input file "$if -ForegroundColor Cyan
		MoveToVCFolder -vmname $row.GuestName -folderName $row.VCFolder -targetCluster  $cluster -targetDatacenter $datacenter
	}
	"rpsonly" {
		Write-host "Moving"$row.GuestName" to ResourcePools ["$row.ResourcePool"] as specified in the input file "$if -ForegroundColor Cyan
		MoveToRP -vmname $row.GuestName -resourcePoolName $row.ResourcePool -targetCluster  $cluster -targetDatacenter $datacenter
	}
	"both" {
		Write-host "Moving" $row.GuestName "to both ResourcePools [" $row.ResourcePool "] and vFolder ["$row.VCFolder"] specified in the input file "$if -ForegroundColor Cyan
		MoveToVCFolder -vmname $row.GuestName -folderName $row.VCFolder -targetCluster  $cluster -targetDatacenter $datacenter
		MoveToRP -vmname $row.GuestName -resourcePoolName $row.ResourcePool -targetCluster $cluster -targetDatacenter $datacenter
	}
	default {
		Write-Host "Invalid execution mode. Choose either [ readonly | doit ]"; 
		Write-Host "Aborting..."
		exit;}
	} 
}

#$Report | Export-Csv $of -NoTypeInformation
#Write-Output "" >> $of
#Write-Output "" >> $of
#Write-Output "Collected on $(get-date)" >> $of

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}
