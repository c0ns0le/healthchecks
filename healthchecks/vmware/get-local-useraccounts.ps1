# Scripts scans vCenter for Snapshot details
# Documents a cluster configuration
#Version : 0.2
#Updated : 22th Aug 2011
#Author  : teiva.rodiere@gmail.com
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[string]$serverName="")
Write-Host "Executing script $($MyInvocation.MyCommand.path)" -ForegroundColor  green;
Write-Host "Current path is $($pwd.path)" -ForegroundColor  yellow;

$disconnectOnExist = $true;

if (!$srvConnection -and ($serverName -eq ""))
{ 
	$serverName = Read-Host "Enter server name"
} 

# if both $serverName and $srvConnection are declared the later wins.
if ($srvConnection.Name -ne "")
{
	$serverName = $srvConnection.Name;
}

if ((Test-Path -path $logDir) -ne $true) {
	New-Item -type directory -Path $logDir
}

$filename = ($($MyInvocation.MyCommand.Name)).TrimEnd('.ps1');
Write-Host "$filename";
if ($comment -eq "" ) {
	$of = $logDir + "\"+$filename+"-"+$serverName+".csv"
} else {
	$of = $logDir + "\"+$filename+"-"+$comment+".csv"
}
Write-Host "This script log to " $of -ForegroundColor Yellow 

# Main function
iex ".\wmi-user-core-utilities.ps1"
$report = $srvConnection | %{
    Get-LocalUser -ComputerName $_.Name | Select-Object Name,FullyQualifiedName,FullName,Description,LastLogonDate,LockedOut,Disabled,ComputerName 
}
$report | Export-Csv $of -NoTypeInformation

Write-Output "" >> $of
Write-Output "" >> $of
Write-Output "Collected on $(get-date)" >> $of
Write-Host "Log file written to $of" -ForegroundColor Yellow