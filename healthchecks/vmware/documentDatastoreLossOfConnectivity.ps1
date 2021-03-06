#This file is an output from command
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[string]$lastDays=1,[string]$eventString="Lost access to volume")
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
  Write-Host "Current value of srvConnection is $srvConnection"
    Write-Host "Type of srvConnection is $($srvConnection.GetType())"
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
    $tempof = $logDir + "\"+$filename+"-"+$vcenterName+"_temp.csv"
} else {
	$of = $logDir + "\"+$runtime+"_"+$vcenterName.ToUpper()+"_"+$filename+"-"+$comment+".csv"
    $tempof = $logDir + "\"+$filename+"-"+$comment+"_temp.csv"
}
Write-Host "This script log to " $of -ForegroundColor $global:colours.Information 

#$vcenterName = "vsvwin2008e102"
 = Get-VC $vcenterName
#$logDir = "D:\INF-VMware\Logs\vmware\Performance Export before and after SVC to XIV Migrations"


#D:\Inf-vmware\scripts\documentEvents.ps1 -srvConnection $srvConnection -logDir $logDir -comment $srvConnection.Name
#$inFile = $logDir + "\documentEvents"+$srvConnection.Name+".csv"
Write-Host "Exporting the last $lastDays days worth of events containing string ""$eventString"".."
$startDate = (Get-Date).AddDays(-$lastDays)

$report = @()
$srvConnection | %{
    #Remove-Variable events
    
    $srvConnectionName = $_.Name
    Write-Host "Processing events from vCenter $srvConnectionName" -ForegroundColor $global:colours.Information
    $vIEvents = Get-VIEvent -Start $startDate -MaxSamples ([int]::MaxValue) -Server $_ | ?{$_.FullFormattedMessage -match $eventString} | select-object vCenterName,CreatedTime,Datacenter,ComputeResource,Host,FullFormattedMessage
    $events = @()
    if ($vIEvents) {
        Write-Host "$($vIEvents.Count) events found";
        Write-Host "Processing events" -NoNewline;
        $vIEvents | %{
            Write-Host "." -NoNewline;
        	$row = $_;
        	$msg1,$msg2 = $_.FullFormattedMessage.Split('('); 
        	$datastoreName,$mgs3 = $msg2.Split(')'); 
        	#$_.Datastore = $datastoreName;
        	$memberAlreadyExists = $row | Get-member -Name "Datastore"
        	if ($memberAlreadyExists)
        	{
        		$row.Datastore = $datastoreName
        	}else {
        		$row | Add-Member -Type NoteProperty -Name "Datastore" -Value $datastoreName;
        	}
        	$events += $row;
        }
        
        Write-Host ""
        #$of =  $logDir+"\datastoreLossConnectivityLogs.csv"
        #$events | Export-CSV -NoTypeInformation $of
        Remove-Variable row
        $eventsSanitised = @()
        $events | group Datastore | select Name,Count  | %{
            $row = $_;
            $memberAlreadyExists = $row | Get-member -Name "vCenter"
        	if ($memberAlreadyExists)
        	{
        		$row.vCenter = $srvConnectionName
        	}else {
        		$row | Add-Member -Type NoteProperty -Name "vCenter" -Value $srvConnectionName;
        	}
        	$eventsSanitised += $row;
            
        }
        $report += $eventsSanitised
    } else {
        Write-Host "No events found for this vcenter $srvConnectionName."
    }
}
$report | sort "Count" -Descending | Export-CSV -NoTypeInformation $of
Write-Host ""
#$events | sort-object Count -Descending | Export-CSV -NoTypeInformation $of
Write-Host "The filtered logs for Loss of datastore connectivity has been placed at location $of"