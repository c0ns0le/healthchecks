
# Sample script to demonstrate how to copy alarm definitions defined on the root folder between vcenter servers
##
# The script has a filter so it only copies certain Alarms. Modify in Line 92
##
# Written by Horst Mundt (hmundt@vmware.com)
# Based on an example provided by Alket Memushaj
###################################################################################
#DISCLAIMER:
# Limitations of Warranties and Liability:
#
# THIS SCRIPT IS PROVIDED AS AN EXAMPLE ONLY. VMWARE MAKES NO EXPRESS CLAIMS REGARDING
# ITS FUNCTIONALITY OR ITS PERFORMANCE. THE SCRIPT IS PROVIDED “AS IS” WITHOUT ANY
# WARRANTIES OF ANY KIND. TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, VMWARE
# DISCLAIMS ANY IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, ANY IMPLIED WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT OF INTELLECTUAL
# PROPERTY RIGHTS.
#
# TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, IN NO EVENT WILL VMWARE BE LIABLE
# FOR ANY LOST PROFITS OR BUSINESS OPPORTUNITIES, LOSS OF USE, BUSINESS INTERRUPTION,
# LOSS OF DATA, OR ANY OTHER INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
# ARISING OUT OF THE SCRIPT OR YOUR USE OF THE SCRIPT, UNDER ANY THEORY OF LIABILITY,
# WHETHER BASED IN CONTRACT, TORT, NEGLIGENCE, PRODUCT LIABILITY, OR OTHERWISE. BECAUSE
# SOME JURISDICTIONS DO NOT ALLOW THE EXCLUSION OR LIMITATION OF LIABILITY FOR CONSEQUENTIAL
# OR INCIDENTAL DAMAGES, THE PRECEDING LIMITATION MAY NOT APPLY TO YOU.
#
# VMWARE’S LIABILITY ARISING OUT OF THE SCRIPT PROVIDED HEREUNDER WILL NOT, IN ANY EVENT, EXCEED US$5.00.
#
# THE FOREGOING LIMITATIONS SHALL APPLY TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW,
# REGARDLESS OF WHETHER VMWARE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES AND REGARDLESS
# OF WHETHER ANY REMEDY FAILS OF ITS ESSENTIAL PURPOSE.
#
#########################################################################
# Changes:
#    - 26/02/2012 - Teiva Rodiere - Added params, logging, Syntax
#    - 31/08/2012 - Teiva Rodiere - added -deleteAllDestinationFirst
param([string]$srvconnection="",[string]$destVCenter="",[bool]$deleteAllAtDestinationFirst=$false,[bool]$readonly=$false,[string]$filter="",[string]$logDir="output",[string]$comment="")
Write-Host "Executing script $($MyInvocation.MyCommand.path)" -ForegroundColor  green;
Write-Host "Current path is $($pwd.path)" -ForegroundColor  yellow;

$disconnectOnExist = $true;

Write-Host "Forcing disconnections of existing vCenter servers (Ignore error if you were not connected to vCenter yet)..." -ForegroundColor  Red -BackgroundColor Yellow
Disconnect-VIServer -Server * -Force -Confirm:$false
Write-Host "Done! (Ignore error if you were not connected to vCenter yet)..." -ForegroundColor  Red -BackgroundColor Yellow

if ($srvconnection -eq "" -or $destVCenter -eq "" )
{
    Write-host "please specify a source vcenter server name and a destination vcenter name";
    Write-host "Syntax to read only: copyalarms.ps1 -sourceVCenter <name> -destVCenter <name> -readonly $true"
	Write-host "Syntax to execute: copyalarms.ps1 -sourceVCenter <name> -destVCenter <name> -readonly $false"
    Write-host "Syntax: copyalarms.ps1 -sourceVCenter <name> -destVCenter <name> -deleteAllAtDestinationFirst $true|$false -filter <empty|string>"
    exit;
}

if ((Test-Path -path $logDir) -ne $true) {
	New-Item -type directory -Path $logDir
}

$filename = ($($MyInvocation.MyCommand.Name)).TrimEnd('.ps1');
Write-Host "$filename";
if ($comment -eq "" ) {
	$of = $logDir + "\"+$filename+"-AlarmsExport-"+$destVCenter+".csv"
} else {
	$of = $logDir + "\"+$filename+"-AlarmsExport-"+$comment+".csv"
}
# Requires vcenter 4.0 or higher
# Powercli version must be compatible with the highest release of vcenter server.
# If you are copying from vcenter 4.0 to vcenter 4.1 , PowerCli must be 4.1
# vc1 is the source vcenter
$vc1 = $srvconnection
# vc2 is the destination vcenter
$vc2 = $destVCenter

# Disconnect existinv connecionts if required
if ($vc1conn) {
    Disconnect-VIServer $vc1 -confirm:$false
}

if ($vc2conn) {
    Disconnect-VIServer $vc2 -confirm:$false
}

# do you want to modify existing alarms or just import new ones?
$mod=$True

# Note the script will NOT delete any alarms in the dest vcenter, even if they do not exist in the src vcenter

function get_counterid([VMware.Vim.PerfCounterInfo] $perfcounterinfo, $availableperfcounters)
{
	# This is needed to 'translate' metrics between vcenter servers.
	# Alarms definiton are based on performance counter Ids.
	# But performance counter IDs may differ bteween vcenter servers.
	# Function takes two parameters. First one is a Vmware.Vim.Perfcounterinfo object representing the performance counter used for the original alarm expression
	# 2nd param is an array containing all perfcounters in the destination vcenter
	# Function returns the id of the perfcounter in the des vcenter that matches the perfcounter in the src vcenter
	$found = $false
	$cid = -1
	$i = 0
	while (($found -eq $false) -and ($i -lt $availableperfcounters.count ))
	{
		if (($availableperfcounters[$i].NameInfo.Key -eq $perfcounterinfo.Nameinfo.Key) -and  ($availableperfcounters[$i].GroupInfo.Key -eq $perfcounterinfo.Groupinfo.Key) -and  ($availableperfcounters[$i].UnitInfo.Key -eq $perfcounterinfo.UnitInfo.Key) -and ($availableperfcounters[$i].RollupType -eq $perfcounterinfo.RollupType)    )
		{
			$found = $true
			$cid = $availableperfcounters[$i].Key
		}
		$i++
	}
	$cid
}
###
#Get started
####
Write-Host "Connecting to source vCenter server $vc1"
$vc1conn = get-vc -server $vc1

if ($vc1conn)
{
    Write-Host " get service instance for source vCenter"
    $vc1serviceinstance = get-view serviceinstance -server $vc1

    WRite-Host " get rootFolder object for source vCenter"
    $vc1root=$vc1serviceinstance.content.rootFolder

    Write-Host " get the alarm view for source vCenter"
    $vc1alMgrView = get-view $vc1serviceinstance.content.alarmManager
    $vc1alarms = $vc1alMgrView.GetAlarm($vc1root)
    $vc1alarmsView  =  Get-View $vc1alarms
    Write-Host " get the performance manager (needed for metrics alarms) for source vCenter"
    $vc1perfMgr = Get-View $vc1serviceinstance.Content.PerfManager

    Write-Host " copying all alarms from $vc1..."
    $sourceAlarms = New-Object system.Collections.arraylist
    if ($sourceAlarmsMetrics)
	{
		Remove-Variable sourceAlarmsMetrics
	}
    $sourceAlarmsMetrics = @{}
    #$vc1alarms | %{
    $vc1alarmsView | %{

     	# We don't want to copy all alarms , just the ones starting with "MY" for demonstartion purposes
    	# Replace the regex with something suitable for your environment
    	# If you want to copy everything just replace the next line with 'if ( $true )'
    	#if( $_.Info.Name -match "^MY.*")
        if ( $true )
     	{
    		#$alarm = $_
            #$alarmView = Get-View $_
            $alarmView = $_
    		$sourceAlarms.add($_)

    		# We need to check for MetricAlarmExpressions.
    		# It seems that Alarms containing MetricAlarmExpression will always have either an OrAlarmExpression or an AndAlarmExpression, even if tehy just have a single trigger
    		# But unfortunately we cannot assume that every alarm will have one of those. It looks like Event alarms sometimes only have a singleton AlarmExpression. Phew.
    		if (($alarmView.Info.Expression.GetType().FullName -eq "VMware.Vim.OrAlarmExpression") -or ($alarmView.Info.Expression.GetType().FullName -eq "VMware.Vim.AndAlarmExpression"))
    		{
    			# We need to determine all metric alarm (sub-)expression. We need to save the metrics into an array for future use
    			# First we determine how many triggers (expressions) the alarm is based on
    			$numexps = $alarmView.Info.Expression.Expression.Count
    			# Then we define an array to hold the perfcounters for that alarm
    			$thisperfcounters = New-Object Vmware.Vim.PerfCounterInfo[] $numexps
    			# Then we retrieve all counters  for those triggers , if they are metrics (not StateAlarmexpressions)
    			for ($i=0; $i -lt $numexps; $i++)
    			{
    				if ($alarmView.Info.Expression.Expression[$i].getType().FullName -eq "VMware.Vim.MetricAlarmExpression")
    				{
    					# The alarm expression only contains a  numeric counter id.
    					# We need to get the complete counter semantic, so we can look up the appropriate counter id in the destination vcenter
    					$thisperfcounters[$i]=$vc1perfmgr.QueryPerfCounter($alarmView.Info.Expression.Expression[$i].Metric.Counterid)[0]
    				}
    			}

    			# we now save the complete perfcounters corresponding to the metrics IDs .
    			$sourceAlarmsMetrics[$alarmView.Info.Key] = New-Object Vmware.Vim.PerfCounterInfo[] $numexps
    			$sourceAlarmsMetrics[$alarmView.Info.Key] = $thisperfcounters
    		}
     	}
    }

    Write-Host " Disconnect from the src $vc1..."
    Disconnect-VIServer $vc1 -Confirm:$false -force

    Remove-Variable  vc1*
    # ... and connect to the dest vc

    # comment out for real action
    #Remove-Variable vc2*
    #$vc2="vsvwin2008e102.corporate.transgrid.local"

    Write-Host " Connect to target vc $vc2"
    $vc2conn = get-vc $vc2
    if ($vc2conn)
    {
        Write-Host " get the service instance from target vCenter"
        $vc2serviceInstance = Get-view serviceinstance -server $vc2

        Write-Host " get the inventory root folder at target vCenter"
        $vc2root = $vc2serviceInstance.content.rootFolder

        Write-Host "  get the alarm manager at target vCenter"
        $vc2alMgr  = $vc2serviceInstance.content.alarmManager
        $vc2alMgrView = get-view $vc2alMgr
        $vc2alarms = (get-view $vc2alMgr).GetAlarm($vc2root)

        $vc2alarmsView = Get-View $vc2alarms

        Write-Host "  get the performance manager at target vCenter"
        $vc2perfMgr = Get-View $vc2serviceInstance.Content.PerfManager

        Write-Host " ... and the available performance counters at target vCenter"
        $vc2counters = $vc2perfMgr.PerfCounter

        Write-Host " Exporting to CSV $of.."
        #$sourceAlarmsView = Get-View $sourceAlarms
        $sourceAlarmsView = $sourceAlarms
        $sourceAlarmsView | select -expand info | Export-Csv $of -NoTypeInformation

        Write-Host " Importing alarms into array for processing"
        $importedalarms = $sourceAlarmsView

        Write-Host "$($importedalarms.count) alarms to process"
        $index = 1;
        foreach ($importedAlarm in $importedalarms) {
          Write-Host "-> Processing imported alarm $index/$($importedalarms.count)"
          $create=$True
          foreach ($existingAlarm in $vc2alarmsView) {
            if ($importedAlarm.Info.name -eq $existingAlarm.Info.name) {
              Write-Host "an existing alarm with the same name was found, don't create but modify if $mod has been set to 1"
              $create = $False
              if ($mod) {
                $alSpec = new-object VMware.Vim.AlarmSpec
                $alSpec.Name = $importedAlarm.Info.name
                $alSpec.Action = $importedAlarm.Info.Action
        		$numactions = $importedAlarm.Info.Action.Action.Count
        		if ($numactions -gt 0)
        		{
        		$alSpec.Action = New-Object vmware.vim.GroupAlarmAction
        		$alSpec.Action.Action = new-object VMware.Vim.AlarmTriggeringAction[] $numactions
        		# we need to copy every alarm action
        			for ($i=0; $i -lt $numactions; $i++)
        			{
        				$alSpec.Action.Action[$i] = New-Object VMware.Vim.AlarmTriggeringAction
        				$alSpec.Action.Action[$i].Action = New-Object $importedAlarm.Info.Action.Action[$i].Action.GetType().Fullname
        				$alSpec.Action.Action[$i].Action = $importedAlarm.Info.Action.Action[$i].Action
        				$tspecs = $importedAlarm.Info.Action.Action[$i].TransitionSpecs.Count
        				if ($tspecs -gt 0)
        				{
        					$alSpec.Action.Action[$i].TransitionSpecs = New-Object VMware.Vim.AlarmTriggeringActionTransitionSpec[] $tspecs
        					for ($j = 0 ; $j -lt $tspecs ; $j++ )
        					{
        						$alSpec.Action.Action[$i].TransitionSpecs[$j] = New-Object VMware.Vim.AlarmTriggeringActionTransitionSpec
        						$alSpec.Action.Action[$i].TransitionSpecs[$j] = $importedAlarm.Info.Action.Action[$i].TransitionSpecs[$j]
        					}
        				}
        				$alSpec.Action.Action[$i].Green2yellow = $importedAlarm.Info.Action.Action[$i].Green2yellow
        				$alSpec.Action.Action[$i].Red2yellow = $importedAlarm.Info.Action.Action[$i].Red2yellow
        				$alSpec.Action.Action[$i].Yellow2red = $importedAlarm.Info.Action.Action[$i].Yellow2red
        				$alSpec.Action.Action[$i].Yellow2green = $importedAlarm.Info.Action.Action[$i].Yellow2green

        			}
        		}
                $alSpec.Enabled = $importedAlarm.Info.Enabled
                $alSpec.Description = $importedAlarm.Info.Description
                $alSpec.ActionFrequency = $importedAlarm.Info.ActionFrequency
        		$setting = New-Object VMware.Vim.AlarmSetting
        		$setting.ToleranceRange = $importedAlarm.Info.Setting.ToleranceRange
        		$setting.ReportingFrequency = $importedAlarm.Info.Setting.ReportingFrequency
                $alSpec.Setting = $setting
        		$alSpec.Expression = New-Object VMware.Vim.AlarmExpression
                $alSpec.Expression = $importedAlarm.Info.Expression
        		if (($importedAlarm.Info.Expression.GetType().FullName -eq "VMware.Vim.OrAlarmExpression") -or ($importedAlarm.Info.Expression.GetType().FullName -eq "VMware.Vim.AndAlarmExpression") )
        		{
        			# We need to figure out the matching perfcounter id in the target vcenter for all MetricAlarmExpressions
        			$numexps = $importedAlarm.Info.Expression.Expression.Count

        			for ($i=0; $i -lt $numexps; $i++)
        			{
        				if ($importedalarm.Info.Expression.Expression[$i].getType().FullName -eq "VMware.Vim.MetricAlarmExpression")
        				{
        					$vc1counterid = $sourceAlarmsMetrics[$importedAlarm.Info.Key][$i]
        					$alSpec.Expression.Expression[$i].Metric.Counterid = get_Counterid $vc1counterid $vc2counters
        					# get_counterid will return -1 if the counter does not exist in the dest vcenter
        					# in that case the reconfigureAlarm action will fail
        					# Hey, this is a sample script. Feel free to add a more graceful error handling
        				}
        			}
        		}
                if ($readonly)
				{
					write-host "Executing[readonly]: $ existingAlarm. ReconfigureAlarm ( $alSpec )" -ForegroundColor Green
				} else
				{
					write-host "Executing: $ existingAlarm. ReconfigureAlarm ( $alSpec )" -ForegroundColor Blue
					$existingAlarm.ReconfigureAlarm($alSpec)
				}
              }
            }
          }
          # if we didn't find an existing alarm with the same name then let's create it
          if ($create) {
            $alSpec = new-object VMware.Vim.AlarmSpec
            $alSpec.Name = $importedAlarm.Info.name
        	$alSpec.Action = $importedAlarm.Info.Action
        	$numactions = $importedAlarm.Info.Action.Action.Count
        	if ($numactions -gt 0)
        	{
        	$alSpec.Action = New-Object vmware.vim.GroupAlarmAction
        	$alSpec.Action.Action = new-object VMware.Vim.AlarmTriggeringAction[] $numactions
        	# we need to copy every alarm action
        		for ($i=0; $i -lt $numactions; $i++)
        		{
        			$alSpec.Action.Action[$i] = New-Object VMware.Vim.AlarmTriggeringAction
        			$alSpec.Action.Action[$i].Action = New-Object $importedAlarm.Info.Action.Action[$i].Action.GetType().Fullname
        			$alSpec.Action.Action[$i].Action = $importedAlarm.Info.Action.Action[$i].Action
        			$tspecs = $importedAlarm.Info.Action.Action[$i].TransitionSpecs.Count
        			if ($tspecs -gt 0)
        			{
        				$alSpec.Action.Action[$i].TransitionSpecs = New-Object VMware.Vim.AlarmTriggeringActionTransitionSpec[] $tspecs
        				for ($j = 0 ; $j -lt $tspecs ; $j++ )
        				{
        					$alSpec.Action.Action[$i].TransitionSpecs[$j] = New-Object VMware.Vim.AlarmTriggeringActionTransitionSpec
        					$alSpec.Action.Action[$i].TransitionSpecs[$j] = $importedAlarm.Info.Action.Action[$i].TransitionSpecs[$j]
        				}
        			}
        			$alSpec.Action.Action[$i].Green2yellow = $importedAlarm.Info.Action.Action[$i].Green2yellow
        			$alSpec.Action.Action[$i].Red2yellow = $importedAlarm.Info.Action.Action[$i].Red2yellow
        			$alSpec.Action.Action[$i].Yellow2red = $importedAlarm.Info.Action.Action[$i].Yellow2red
        			$alSpec.Action.Action[$i].Yellow2green = $importedAlarm.Info.Action.Action[$i].Yellow2green

        		}
        	}

            $alSpec.Enabled = $importedAlarm.Info.Enabled
            $alSpec.Description = $importedAlarm.Info.Description
            $alSpec.ActionFrequency = $importedAlarm.Info.ActionFrequency
            $alSpec.setting = New-Object VMware.Vim.AlarmSetting
        	$alSpec.Setting = $importedAlarm.Info.Setting
        	$alSpec.Expression = New-Object VMware.Vim.AlarmExpression
            $alSpec.Expression = $importedAlarm.Info.Expression
        	if (($importedAlarm.Info.Expression.GetType().FullName -eq "VMware.Vim.OrAlarmExpression") -or ($importedAlarm.Info.Expression.GetType().FullName -eq "VMware.Vim.AndAlarmExpression") )
        		{
        			# We need to figure out the matching perfcounter id in the target vcenter for all MetricAlarmExpressions
        			$numexps = $importedAlarm.Info.Expression.Expression.Count

        			for ($i=0; $i -lt $numexps; $i++)
        			{
        				if ($importedalarm.Info.Expression.Expression[$i].getType().FullName -eq "VMware.Vim.MetricAlarmExpression")
        				{
        					$vc1counterid = $sourceAlarmsMetrics[$importedAlarm.Info.Key][$i]
        					$alSpec.Expression.Expression[$i].Metric.Counterid = get_Counterid $vc1counterid $vc2counters
        				}
        				# get_counterid will return -1 if the counter does not exist in the dest vcenter
        				# in that case the CreateAlarm action will fail
        				# Hey, this is a sample script. Feel free to add a more graceful error handling
        			}
        		}

             Write-Host "Creating alarm"
             #$vc2alMgr.CreateAlarm($vc2root,$alSpec)
             $vc2alMgrView.CreateAlarm($vc2root,$alSpec)
             #exit
          }
          $index++;
        }
        Write-Host "Disconnecting from target vCenter $vc2"
        Disconnect-VIServer $vc2 -confirm:$false
        Write-Host "Completed"
    } else {
        Write-Host "Could not connect destination vCenter $vc2"
        Write-Host "not changes implemented"
    }

    ###############
} else {
    Write-Host "Was not able to connect to source vCenter $vc1"
}
if ($vc1conn) {
    Disconnect-VIServer $vc1 -confirm:$false
}

if ($vc2conn) {
    Disconnect-VIServer $vc2 -confirm:$false
}

#Clean up for next round
Remove-Variable vc1*
Remove-Variable vc2*