# This scripts provides common performance statistics information about VMs from a specified location
# Last updated: 31 March 2011
# Author: teiva.rodiere-at-gmail.com
#
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[string$location="")
Write-Host "Executing script $($MyInvocation.MyCommand.path)" -ForegroundColor  green;
Write-Host "Current path is $($pwd.path)" -ForegroundColor  yellow;

$disconnectOnExist = $true;

if (!$srvConnection)
{ 
	$vcenterName = Read-Host "Enter virtual center server name"
	Write-Host "Connecting to virtual center server $vcenterName.."
	$srvConnection = Connect-VIServer -Server $vcenterName
	$disconnectOnExist = $true;	
} else {
	$disconnectOnExist = $false;
}

if ((Test-Path -path $logDir) -ne $true) {
	New-Item -type directory -Path $logDir
}

$filename = ($($MyInvocation.MyCommand.Name)).TrimEnd('.ps1');
Write-Host "$filename";
if ($comment -eq "" ) {
	$of = $logDir + "\"+$filename+"-"+$vcenterName+".csv"
} else {
	$of = $logDir + "\"+$filename+"-"+$comment+".csv"
}
Write-Host "This script log to " $of -ForegroundColor $global:colours.Information 

if ($location -eq "")
{
	Write-Host "Please specify a folder, resource pool, cluster to export VM stats for" -Forground red;
	exit;
}

# For the last 7 day
$startdate=$(Get-date -date (Get-date).adddays(-7) -format d); 
$enddate=$(get-date -format d);  

Get-VM -Location $location | %{ Get-Stat -Entity $_.name -start $startdate  -Finish $enddate -Common -IntervalSecs 1200 | Export-Csv "C:\admin\powershell\scheduler\Customer_AXIS\$_-weekly-st
ats.csv" -NoTypeInformation}