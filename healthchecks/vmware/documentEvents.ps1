# Exports all Events objects 
#Version : 0.1
#Updated : 9th May 2012
#Author  : teiva.rodiere-at-gmail.com

param([object]$srvConnection,[string]$logDir="output",[string]$comment="",[string]$lastDays=7,[string]$errorType="",[string]$eventString="",[string]$VM)

Function Get-LDAPUser ($UserName) {
    $queryDC = (get-content env:logonserver).Replace('\','');
    $domain = new-object DirectoryServices.DirectoryEntry `
        ("LDAP://$queryDC")
    $searcher = new-object DirectoryServices.DirectorySearcher($domain)
    $searcher.filter = "(&(objectClass=user)(sAMAccountName=$UserName))"
    return $searcher.FindOne().Properties.displayname
} 

Write-Host "Executing script $($MyInvocation.MyCommand.path)" -ForegroundColor  green;
Write-Host "Current path is $($pwd.path)" -ForegroundColor  yellow;



$disconnectOnExist = $true;

if (!$srvConnection -or ( ($srvconnection.GetType().Name -ne "VIServerImpl") -and ($srvconnection.GetType().Name -ne "Object[]") ) )
{ 
    Write-Host "Current value of srvConnection is $srvConnection"
    Write-Host "Type of srvConnection is $($srvConnection.GetType())"
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


$filename = ($($MyInvocation.MyCommand.Name)).TrimEnd('.ps1');
Write-Host "$filename";
if ($comment -eq "" ) {
	$of = $logDir + "\"+$filename+"-"+$vcenterName+".csv"
} else {
	$of = $logDir + "\"+$filename+"-"+$comment+".csv"
}
Write-Host "This script log to " $of -ForegroundColor Yellow 

$startDate = (get-date).AddDays(-$lastDays)

Write-Host "Exporting the last $lastDays days worth of events containing string $eventString from $srvConnection..."


$Report = $srvConnection | %{
    $vCenter = $_
    Write-Host "Export events from $_..."
    if ($eventString)
    {
        if ($VM)
	{	
		$vIEvents = Get-VIEvent -Entity $VM -Start $startDate  -MaxSamples ([int]::MaxValue) -Server $vCenter | ?{$_.FullFormattedMessage -match $eventString}
	} else {
		$vIEvents = Get-VIEvent -Start $startDate  -MaxSamples ([int]::MaxValue) -Server $vCenter | ?{$_.FullFormattedMessage -match $eventString}
	}
    } else {
	if ($VM)
	{
	        $vIEvents = Get-VIEvent -Entity $VM -Start $startDate  -MaxSamples ([int]::MaxValue) -Server $vCenter
	} else {
	        $vIEvents = Get-VIEvent -Start $startDate  -MaxSamples ([int]::MaxValue) -Server $vCenter
	}
    }
    Write-Host "Processing results..."
	$index=1
    $vIEvents |  %{
		Write-Progress -activity "Processing results" -status "% complete ($index/$($vIEvents.Count)" -percentcomplete ($index/$vIEvents.Count*100)
       	$events = "" | Select-Object "vCenterName";
        $events.vCenterName = $vCenter.Name;
       	$events | Add-Member -Type NoteProperty -Name "TicketType" -Value $_.TicketType;
        $events | Add-Member -Type NoteProperty -Name "Template" -Value $_.Template;
        $events | Add-Member -Type NoteProperty -Name "Key" -Value $_.Key;
        $events | Add-Member -Type NoteProperty -Name "ChainId" -Value $_.ChainId;
        $events | Add-Member -Type NoteProperty -Name "CreatedTime" -Value $_.CreatedTime;
        $events | Add-Member -Type NoteProperty -Name "UserName" -Value $_.UserName;
        $username = ($_.UserName).Replace((get-content env:userdomain),'').Replace('\','');
        $UserDisplayName = "";
        if ($username) {
            $UserDisplayName = Get-LDAPUser $username;
        }
        $events | Add-Member -Type NoteProperty -Name "DisplayName" -Value $UserDisplayName; 
        $events | Add-Member -Type NoteProperty -Name "SourceIpAddress" -Value $_.IpAddress;
        $events | Add-Member -Type NoteProperty -Name "Datacenter" -Value $_.Datacenter.Name;
        $events | Add-Member -Type NoteProperty -Name "ComputeResource" -Value $_.ComputeResource.Name;
        $events | Add-Member -Type NoteProperty -Name "Host" -Value $_.Host.Name;
        $events | Add-Member -Type NoteProperty -Name "Vm" -Value $_.Vm.Name;
        $events | Add-Member -Type NoteProperty -Name "Ds" -Value $_.Ds;
        $events | Add-Member -Type NoteProperty -Name "Net" -Value $_.Net;
        $events | Add-Member -Type NoteProperty -Name "Dvs" -Value $_.Dvs;
        $events | Add-Member -Type NoteProperty -Name "FullFormattedMessage" -Value $_.FullFormattedMessage;
        $events
		$index++;
    }
}

Write-Output $Report | Export-Csv $of -NoTypeInformation
Write-Output "" >> $of
Write-Output "" >> $of
Write-Output "Collected on $(get-date)" >> $of

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}