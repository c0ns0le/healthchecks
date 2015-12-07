# Exports Alarm actions and associated definitions from vCenter. The output can be used with configureAlarmActions.ps1 to import them into vCenter
#Version : 0.1
#Last Updated : 31th Jul 2012, teiva.rodiere-at-gmail.com
#Author : teiva.rodiere-at-gmail.com 
#Syntax:  .\documentAlarmActions.ps1
#         .\documentAlarmActions.ps1 -srvConnection $srvConnection -comment "mycomment" -logDir "D:\temp"
#Inputs: vcenter server name, username, and password
#Output file: "documentVMHost.csv"
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="")
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

Write-Host $srvConnection.Name;

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
Write-Host "This script log to " $of -ForegroundColor Yellow 
function logThis ([string] $msg, [string] $colour = "yellow", [string] $logFile=$of)
{
	Write-Host $msg -ForegroundColor $colour;
	$msg  | out-file -filepath $logFile -append
}

logThis `Get-Date`
logThis "Export all the available alarms for this version of vSphere vCenter..."
$eventMan = get-view eventManager
$eventMan.get_Description() | select -expand Eventinfo | Export-Csv -NoTypeInformation $ofCapability

logThis ""
logThis "Enumerating Currently configured Alarm Actions..."
$alarms = Get-AlarmAction -Server $srvConnection | sort -expand ExtensionData

if ($alarms)
{
    if ($alarms.Count)
    {
        logThis "$alarms.Count Alams found"
    } else {
        logThis "1 Alarm found"
    }
    logThis "BEGIN"
    $arr = "" | Select "Name"
        $definition = Get-AlarmDefinition $alarm.AlarmDefinition | select -expand ExtensionData
        $arr.Name = $definition.Name
        $arr | Add-Member -Type NoteProperty -Name "Description" -Value $definition.Description;
        $arr | Add-Member -Type NoteProperty -Name "Enabled" -Value $definition.Enabled;
        Write-Host $arr
        $arr
    
}

Write-Output $Report | Export-Csv $of -NoTypeInformation
Write-Output "" >> $of
Write-Output "" >> $of
Write-Output "Collected on $(get-date)" >> $of


if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}