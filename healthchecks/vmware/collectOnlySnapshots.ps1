# Scripts scans vCenter for Snapshot details
# Documents a cluster configuration
#Version : 0.1
#Updated : 4th October 2010
#Author  : teiva.rodiere-at-gmail.com
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$verbose=$true,[bool]$outToScreen=$false,[string]$appendOutputToFile="")
if ($verbose) 
{ 
	Write-Host "Executing script $($MyInvocation.MyCommand.path)" -ForegroundColor  green;
	Write-Host "Current path is $($pwd.path)" -ForegroundColor  yellow;
}
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


$filename = ($($MyInvocation.MyCommand.Name)).TrimEnd('.ps1');
if ($verbose) 
{ 
	Write-Host "$filename";
}
if ($comment -eq "" ) {
	$of = $logDir + "\"+$filename+"-"+$vcenterName+".csv"
} else {
	$of = $logDir + "\"+$filename+"-"+$comment+".csv"
}


if ($appendOutputToFile) {
	$of = $appendOutputToFile;
}

if ($verbose) 
{ 
	Write-Host "This script log to " $of -ForegroundColor $global:colours.Information 
}


# do the job here#####################################
$snapshots = Get-Snapshot * | Select-Object *;  
if (!$snapshots)
{
	#Write-Host "Yes" -foreground green;
	$count = "0";
} 
elseif ($snapshots -and !$snapshots.Count)
{
	#Write-Host "Yes" -foreground green;
	$count = "1";
} else {
	$count = $snapshots.Count;
}

if ($outToScreen)
{
	Write-Host "Snaphosts in $comment ( $count found)" -ForegroundColor $global:colours.Error
	$snapshots;
	Write-Host "";
}  
if ($appendOutputToFile) {
	Write-Output "Snaphosts in $comment ( $count found)" >> $of
	$snapshots >> $of; 
	Write-Output "" >> $of;
} else {
	Get-Snapshot * | Select-Object * |  Export-Csv $of -NoTypeInformation
}

if ($verbose) 
{ 
	Write-Output "" >> $of
	Write-Output "" >> $of
	Write-Output "Collected on $(get-date)" >> $of
}

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}