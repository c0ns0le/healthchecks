# THis is the scheduler script which allows to be called in a script
# The script runs as a Windows Task on either a management server or vCenter server.
# 
# The username is defined by $userId below and password in an encrypted string from $securestring
# To create the secure string, run the "Set-myCredntials.ps1 -File $userId" whilst logged on as $userId
#
param(	[Parameter(Mandatory=$true)][string]$configFile="",
		[string]$logDir="output",
		[string]$logfile=$null,
		[bool]$skipEvents=$true,
		[bool]$verboser=$false
	)

Import-Module -Name ".\vmwareModules.psm1" 
#loadSessionSnapings 

$runtime=(Get-Date)
#$errorActionPreference = "silentlycontinue"
if (!$logfile)
{
	#$log = "$logDir\collectAll-scheduler.log";
	$logfile = ($($MyInvocation.MyCommand.Name)).TrimEnd('.ps1');
}

Name = $null
SetmyLogFile -filename $logFile
Write-Host "Setting log file: SetmyLogFile -filename `"$global:logFileName`" [$runtime]"


# Delete previous logs
if ((Test-Path -path $logDir) -ne $true) {
	Write-Host "Creating output directory as [" $logDir "]";
	New-Item -type directory -Path $logDir
} else {
	#rm -recurse -force "$logDir\*"
	#----- define parameters -----#
	#----- get current date ----#
	$Now = Get-Date 
	#----- define amount of days ----#
	$Days = "5"
	#----- define extension ----#
	$Extension = "*.csv"
	#----- define LastWriteTime parameter based on $Days ---#
	$LastWrite = $Now.AddDays(-$Days)
	#----- get files based on lastwrite filter and specified folder ---#
	$Files = Get-Childitem $logDir -Include $Extension -Recurse | Where {$_.LastWriteTime -le "$LastWrite"}

	foreach ($File in $Files) 
    {
	    if ($File -ne $NULL) {
        	write-host "Deleting File $File" -ForegroundColor "DarkRed"
        	Remove-Item $File.FullName | out-null
        } else {
	        Write-Host "No more files to delete!" -foregroundcolor "Green"
	    }
    }
}

logThis -msg "Running script $($MyInvocation.MyCommand.path) from $($env:computername) [$runtime]"

$vcenterServers = @();
Set-PowerCLIConfiguration -DefaultVIServerMode Multiple -Confirm:$false

foreach ($environment in (Import-CSV $configFile) )
{
    LogThis -msg "vCenter $($environment.vCenterSrvName) [user=$($environment.LoginUser), password file = $($environment.SecurePasswordFile)"
	$vcenterServers += $environment.vCenterSrvName;
	if ($environment.LoginUser -and $environment.SecurePasswordFile)
	{
		LogThis -msg "`t--> Special credentials required for $($environment.vCenterSrvName)"
		$mycreds = GetmyCredentialsFromFile -User $environment.LoginUser -File $environment.SecurePasswordFile ;
		if (!$mycreds)
		{
			logThis -msg "`t--> [Somethingis wrong :- CREDENTIALS ARE EMPTY ]" -forgroundColor "red" 
			return
		}
		LogThis -msg "`t--> Connecting using $mycreds"
		Connect-VIServer -Server $environment.vCenterSrvName -Credential $mycreds -SaveCredentials
		if ($?)
    	{
			logThis -msg "`t--> [Connected]" -ForegroundColor "blue"
		} else {
			logThis -msg "`t--> [NOT Connected]" -ForegroundColor "red"
		}
	} else {
		# it will connect to the vcenter server with credentials of the user it is running right now. -- Passthrough credentials
		Connect-VIServer -Server $environment.vCenterSrvName
	}
}
#logThis -msg "List of vCenter servers to report: "  
#$vcenterServers 


if ($vcenterServers)
{	
	logThis -msg "Connecting to all vCenters once more and store the connection settings into the `$srvconnections variable"
	Set-PowerCLIConfiguration -DefaultVIServerMode Multiple -Confirm:$false
   	$srvConnections = Connect-VIServer -Server $vcenterServers
    if ($?)
    {
        logThis -msg "-------------------------------------------------------------------"
        logThis -msg "Executing the below scripts against Infrastructure(s) $srvConnections"
        s 
		logThis -msg "Executing .\generateInfrastructureReports.ps1 -srvConnection $srvconnections -emailReport $true -verboseHTMLFilesToFile $false" 
    	.\generateInfrastructureReports.ps1 -srvConnection $srvConnections -emailReport $true -verboseHTMLFilesToFile $false
    } else {
        logThis -msg "`r`nError: Not connected to any vCenter Servers" 
    }
} else  { 
	logThis -msg "Unable to read in the secure string from file $($environment.SecurePasswordFile)";
}

Remove-Module gmsTeivaModules