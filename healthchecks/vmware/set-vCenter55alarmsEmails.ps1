# Lists all VMs compute settings, Resevations and limits
# Sets the alarm triggers via email for 
#Version : 0.1
#Updated : 21st January 2015
#Author  : teiva.rodiere@andersenit.com.au
# Usage :
#       Get-AlarmDefinition * | select Name | %{\$_ | Add-Member -Name Priority -Type NoteProperty -Value "unset"; write-output \$_} | Export-Csv .\output\current-alarms-names.csv -NoTypeInformation

param([object]$srvConnection="",[string]$logfile="",[string]$alarmDefCSVPath="")

$lowEmailAddress="anz.system.alerts@henryschein.com.au"
$mediumEmailAddress="anz.system.alerts@henryschein.com.au"
$highEmailAddress="anz.system.alerts@henryschein.com.au","group-7627@directsms.com.au"

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


if (!(get-module -name gmsTeivaModules))
{
	Write-Host "Importing Module .\vmwareModules.psm1"
	Import-Module -Name .\vmwareModules.psm1
}
if (!$global:logFileName)
{
	logThis -msg "Setting log file: SetmyLogFile -filename `"$logfile`""
	SetmyLogFile -filename $logfile
}

$of = $logfile

$alarmDefCSV = Import-CSV $alarmDefCSVPath

#Write-Host $alarmDefCSV 

if ($alarmDefCSV)
{
	$Report = $alarmDefCSV | %{
		$alarmName = $_.Name
		$alarmPriority = $_.Priority.ToLower()
		logThis -msg "Reviewing $alarmName"
		$processThisAlarm = $false
		switch ($alarmPriority)
		{
			medium {
				logThis -msg "`t$_" -ForegroundColor "blue"
				logThis -msg "`tUser choose to reconfigure this alarm " -ForegroundColor "blue"
				Get-AlarmDefinition -Name "$alarmName" | Get-AlarmAction -ActionType SendEmail| Remove-AlarmAction -Confirm:$false
				Set-AlarmDefinition "$alarmName" -ActionRepeatMinutes (60 * 24) # 24 Hours
    				Get-AlarmDefinition -Name "$alarmName" | New-AlarmAction -Email -To @($mediumEmailAddress)
    				Get-AlarmDefinition -Name "$alarmName" | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Green" -EndStatus "Yellow"
    				Get-AlarmDefinition -Name "$alarmName" | Get-AlarmAction -ActionType SendEmail | Get-AlarmActionTrigger | Select -First 1 | Remove-AlarmActionTrigger -Confirm:$false
    				Get-AlarmDefinition -Name "$alarmName" | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Yellow" -EndStatus "Red" -Repeat
    				Get-AlarmDefinition -Name "$alarmName" | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Red" -EndStatus "Yellow"
    				Get-AlarmDefinition -Name "$alarmName" | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Yellow" -EndStatus "Green"
			}
			high {
				logThis -msg "`t$_" -ForegroundColor "blue"
				logThis -msg "`tUser choose to reconfigure this alarm " -ForegroundColor "blue"
				Get-AlarmDefinition -Name "$alarmName" | Get-AlarmAction -ActionType SendEmail| Remove-AlarmAction -Confirm:$false
 				Set-AlarmDefinition "$alarmName" -ActionRepeatMinutes (60 * 2) # 2 hours
    				Get-AlarmDefinition -Name "$alarmName" | New-AlarmAction -Email -To @($highEmailAddress)
    				Get-AlarmDefinition -Name "$alarmName" | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Green" -EndStatus "Yellow"
    				Get-AlarmDefinition -Name "$alarmName" | Get-AlarmAction -ActionType SendEmail | Get-AlarmActionTrigger | Select -First 1 | Remove-AlarmActionTrigger -Confirm:$false
    				Get-AlarmDefinition -Name "$alarmName" | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Yellow" -EndStatus "Red" -Repeat
    				Get-AlarmDefinition -Name "$alarmName" | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Red" -EndStatus "Yellow"
    				Get-AlarmDefinition -Name "$alarmName" | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Yellow" -EndStatus "Green"
			}
			low { 
				logThis -msg "`t$_" -ForegroundColor "blue"
				logThis -msg "`tUser choose to reconfigure this alarm " -ForegroundColor "blue"
				Get-AlarmDefinition -Name "$alarmName" | Get-AlarmAction -ActionType SendEmail| Remove-AlarmAction -Confirm:$false
 				#Set-AlarmDefinition "$alarmName" -ActionRepeatMinutes 0 # 2 hours
    			Get-AlarmDefinition -Name "$alarmName" | New-AlarmAction -Email -To @($lowEmailAddress)
    			Get-AlarmDefinition -Name "$alarmName" | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Green" -EndStatus "Yellow"
    			#Get-AlarmDefinition -Name "$alarmName" | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Yellow" -EndStatus "Red"  # This ActionTrigger is enabled by default.
				Get-AlarmDefinition -Name "$alarmName" | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Red" -EndStatus "Yellow"
    				Get-AlarmDefinition -Name "$alarmName" | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Yellow" -EndStatus "Green" 
			}
			unset {
				logThis -msg "`t$_" -ForegroundColor "Blue"
				logThis -msg "`tDisabeling the Email trigger for this alarm" -ForegroundColor "Blue"
				Get-AlarmDefinition -Name "$alarmName" | Get-AlarmAction -ActionType SendEmail| Remove-AlarmAction -Confirm:$false
			} 
			ignore {
				logThis -msg "`t$_" -ForegroundColor "yellow"
				logThis -msg "`tIgnoring this one, skipping it" -ForegroundColor "yellow"
			}
			default { 
				logThis -msg "`t$_" -ForegroundColor "Green"
				logThis -msg "`tInvalid Priority -- should be unset,low,medium,high and nothing else, skipping this one" -ForegroundColor "red"
			}
		}
		logThis -msg "`n`r"
	}
} else {
	logThis -msg "A probblem was encountered during the import of $alarmDefCSVPath" -ForegroundColor "red"
	exit;
}


if ($Report)
{	
	Write-Output $Report | Export-Csv $of -NoTypeInformation
}
Write-Output "" >> $of
Write-Output "" >> $of
Write-Output "Collected on $(get-date)" >> $of

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}