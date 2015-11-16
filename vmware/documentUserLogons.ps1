# Exports all User loggon events
#Version : 0.1
#Updated : 9th May 2012
#Author  : teiva.rodiere@gmail.com
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$verbose=$false)
Write-Host "Executing script $($MyInvocation.MyCommand.path)" -ForegroundColor  green;
Write-Host "Current path is $($pwd.path)" -ForegroundColor  yellow;

$now = Get-Date
$reportPeriodInMonths = -5; # Months (period in months). Example -5 means the previous 5 months inclusive from today


Function Get-LDAPUser ($UserName) {
    $queryDC = (get-content env:logonserver).Replace('\','');
    $domain = new-object DirectoryServices.DirectoryEntry `
        ("LDAP://$queryDC")
    $searcher = new-object DirectoryServices.DirectorySearcher($domain)
    $searcher.filter = "(&(objectClass=user)(sAMAccountName=$UserName))"
    return $searcher.FindOne().Properties.displayname
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



$runtime="$(date -f dd-MM-yyyy)"
$filename = ($($MyInvocation.MyCommand.Name)).TrimEnd('.ps1');
Write-Host "$filename";
if ($comment -eq "" ) {
	$of = $logDir + "\"+$runtime+"_"+$vcenterName.ToUpper()+"_"+$filename+".csv"
} else {
	$of = $logDir + "\"+$runtime+"_"+$vcenterName.ToUpper()+"_"+$filename+"-"+$comment+".csv"
}
Write-Host "This script log to " $of -ForegroundColor Yellow 

#$events = Get-VIEvent -Server $srvConnection
#
$Report = $srvConnection | %{ 
    $vcenterServer = $_.Name;
    Write-Host "Exporting Last 1 month worth of User Logons from $($_.Name)..." -ForegroundColor Cyan
    $viEvents = Get-VIEvent -Start $now.AddMonths($reportPeriodInMonths) -MaxSamples ([int]::MaxValue) -Server $_.Name | where{$_.fullFormattedMessage -match "User(.*)@\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b logged in"}
    
    if ($viEvents)
    {
        $eventCount = 1; # default
        if ($viEvents -is [system.array])
        {
            $eventCount = $viEvents.Count
        } 
        
        Write-Host "$eventCount Found" -ForegroundColor Yellow
        $index=1;        
        $viEvents | %{
            Write-Host "Processing Event $index/$eventCount" -foregroundcolor Yellow
           	$events = "" | Select-Object "UserName";
            
            $username = ($_.UserName).Replace((get-content env:userdomain),'').Replace('\','');
            $UserDisplayName = Get-LDAPUser $username;
            
            $events.Username = $_.UserName;
           	
            $events | Add-Member -Type NoteProperty -Name "DisplayName" -Value $UserDisplayName; 
            $events | Add-Member -Type NoteProperty -Name "LogonTime" -Value $_.CreatedTime; 
            $events | Add-Member -Type NoteProperty -Name "SourceIpAddress" -Value $_.IpAddress;
            $events | Add-Member -Type NoteProperty -Name "Key" -Value $_.Key;
            $events | Add-Member -Type NoteProperty -Name "ChainId" -Value $_.ChainId;  
            $events | Add-Member -Type NoteProperty -Name "FullFormattedMessage" -Value $_.FullFormattedMessage;
            $events | Add-Member -Type NoteProperty -Name "vCenter" -Value $vcenterServer;
            if ($verbose)
            {
                Write-Host $events
            }
            $events
            $index++;
        }
    }
}


Write-Output $Report | Export-Csv $of -NoTypeInformation
Write-Output "" >> $of
Write-Output "" >> $of
Write-Output "Collected on $(get-date)" >> $of

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}