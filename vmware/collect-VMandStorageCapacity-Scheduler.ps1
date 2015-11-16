# THis is the scheduler script which allows to be called in a script
# The script runs as a Windows Task on either a management server or vCenter server.
# 
# The username is defined by $userId below and password in an encrypted string from $securestring
# To create the secure string, run the "Set-myCredntials.ps1 -File $userId" whilst logged on as $userId
#
param([string]$configFile="",[string]$logDir="output",[string]$logfile="",[bool]$skipEvents=$true,[bool]$verbose=$false)
#Add-pssnapin VMware.VimAutomation.Core
if (!(get-module -name gmsTeivaModules))
{
	Import-Module -Name E:\scripts\vmwareModules.psm1
}
if (!$global:logFileName)
{
	logThis -msg "Setting log file: SetmyLogFile -filename `"$logfile`""
	#SetmyLogFile -filename $logfile
}
#$errorActionPreference = "silentlycontinue"
if (!$logfile)
{
	#$logFile= "$logDir\collectAll-scheduler.log";
	$logFile= ($($MyInvocation.MyCommand.Name)).TrimEnd('.ps1');
}
if (!$configFile) {
	logThis -msg "Specify a configuration file *.ini"
	exit
}

# Delete previous logs
if ((Test-Path -path $logDir) -ne $true) {
	logThis -msg "Creating output directory as [" $logDir "]";
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
        	logThis -msg "Deleting File $File" -ForegroundColor "DarkRed"
        	Remove-Item $File.FullName | out-null
        } else {
	        logThis -msg "No more files to delete!" -foregroundcolor "Green"
	    }
    }
}

logThis -msg "Running script $($MyInvocation.MyCommand.path) from $($env:computername)"
logThis -msg "$(get-date)"
$vcenterServers = @();
foreach ($environment in (Import-CSV $configFile) )
{
    $vcenterServers += $environment.vCenterSrvName;
	if ($environment.LoginUser -and $environment.SecurePasswordFile)
	{
		#.\Get-myCredentials.ps1 
		$mycreds = GetmyCredentialsFromFile -User $environment.LoginUser -File $environment.SecurePasswordFile
		#$mycreds
		Connect-VIServer -Server $environment.vCenterSrvName -Credential $mycreds -SaveCredentials
	} 
}
#logThis -msg "List of vCenter servers to report: "  | out-file -filepath $logFile -append
#$vcenterServers | out-file -filepath $logFile -append


if ($vcenterServers)
{	
   	$srvConnection = Connect-VIServer -Server $vcenterServers -NotDefault
    if ($?)
    {        
        logThis -msg "Documenting Infrastructure for $srvConnection"
        logThis -msg $srvConnection
		logThis -msg "Executing .\export-daily-capacity.ps1 -srvConnection $srvConnection -logDir $logDir -logFile $logfile"
    	.\export-daily-capacity.ps1 -srvConnection $srvConnection -logDir $logDir -logFile $logfile
    } else {
        logThis -msg "`r`nError: Not connected to any vCenter Servers"
    }
} else  { 
	Write-Output "Unable to read in the secure string from file $environment.SecurePasswordFile";
}

if (get-module -name gmsTeivaModules)
{
	Remove-Module gmsTeivaModules
}