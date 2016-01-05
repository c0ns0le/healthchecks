# Scripts to collect lot's of information
param([object]$srvConnection="",[string]$vcenterName="",[string]$userid="",[bool]$promptForCredentials=$true,[string]$logDir="",[string]$comment="",[string]$logProgressHere="collectAll.log",[int]$hours=4)
$errorActionPreference = "silentlycontinue"

function Get-Session
{
	$Global:SI = Get-View ServiceInstance	
	$Global:SM = Get-View $SI.Content.SessionManager
	Return $SM.SessionList
}

function Stop-Session
{
	Process
	{
		ForEach ($Session in $_)
		{
			If ($Session.Key -ne $SM.CurrentSession.Key)
			{
    				$Key = $session.Key
    				$SM.TerminateSession($Key)
    				Write-Host “Session $Key terminated.”
    				$Key = $null
   			}
    			Else
    			{
				Write-Warning “Cannot terminate current session.”
    			}
    		}
    	}
}

#Clear-Host;
Write-Host "Executing script $($MyInvocation.MyCommand.path)" -ForegroundColor  green;
Write-Host "Current path is $($pwd.path)" -ForegroundColor  yellow;
Write-Host "Comment is $comment" -BackgroundColor $global:colours.Highlight;
if ($srvConnection -eq "") {
	if ($vcenterName -eq "" -or $userid -eq "") 
	{
		Write-Host "Syntax: .\collectAll.ps1 [-srvConnection srvConnection | -vcenterName <name> -userid name]";
		exit;
	}
} else {
	$vcenterName = $srvConnection.Name;
}


if ($logDir -eq "") {
	$logDir = $pwd.path + "\" + (get-date -format "dd-MM-yyyy");
}
Write-Host "Logs will be written to $($logDir)" -ForegroundColor $global:colours.Information;

if ((Test-Path -path $logDir) -ne $true) {
	Write-Host "Creating output directory as [" $logDir "]";
	New-Item -type directory -Path $logDir
}

if ($srvConnection -eq "") {
	if ($promptForCredentials -eq $true) 
	{
		if ($userid -eq "" -or $pass -eq "") 
		{
			$credential = Get-Credential 
		} else {
			$credential = Get-Credential -Credential $userid
		}
		if (!$credential)
		{
			Write-Host "Invalid credentials"
			exit
		}
	}
}

Write-Host "Connecting to vCenter server ["$vcenterName"]..." -ForegroundColor $global:colours.Information;
if ($srvConnection -eq "") {
	if ($promptForCredentials) {
		$srv = Connect-VIServer -Server $vcenterName -Credential $credential
	} else { 
		$srv = Connect-VIServer -Server $vcenterName 
	}
} else {
	$srv = $srvConnection.Name;
}

if ($srv)
{
	Write-Host "Connected to $srv" -ForegroundColor Black -BackgroundColor $global:colours.Highlight; 
	Get-Session | Where { ((Get-Date) – $_.LastActiveTime).TotalHours -ge $hours } | Stop-Session
	Disconnect-VIServer $srvConnection -Confirm:$false;
	Write-Host "Disconnected from $srvConnection.Name " -ForegroundColor Black -BackgroundColor $global:colours.Highlight;

} else { 
	Write-Host "Error while connecting to $srv using userid" $userid;
	exit;
}











