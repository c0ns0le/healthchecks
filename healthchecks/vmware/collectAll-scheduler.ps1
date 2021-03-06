# THis is the scheduler script which allos collect-All.ps1 to be called in a script
# The script runs as a Windows Task on either a management server or vCenter server.
# 
# The username is defined by $userId below and password in an encrypted string from $securestring
# To create the secure string, run the "Set-myCredntials.ps1 -File $userId" whilst logged on as $userId
#
param([string]$configFile="",[string]$logDir="output",[string]$logfile="",[bool]$skipEvents=$true,[bool]$verbose=$false,[bool]$exportExtendedReports=$false)
if (!(get-pssnapin VMware.VimAutomation.Core))
{
	Add-pssnapin VMware.VimAutomation.Core
}
#$errorActionPreference = "silentlycontinue"
if ($logfile)
{
	$log = $logfile;
} else {
	#$log = "$logDir\collectAll-scheduler.log";
	$log = ($($MyInvocation.MyCommand.Name)).TrimEnd('.ps1');
}
if (!$configFile) {
	Write-Host "Specify a configuration file *.ini"
	exit
}

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

Write-Output "Running script $($MyInvocation.MyCommand.path) from $($env:computername)" | out-file -filepath $log
get-date  | out-file -filepath $log -append
$vcenterServers = @();
foreach ($environment in (Import-CSV $configFile) )
{
        $vcenterServers += $environment.vCenterSrvName;
}
Write-Output "List of vCenter servers to report: "  | out-file -filepath $log -append
$vcenterServers | out-file -filepath $log -append

if ($environment.LoginUser -and $environment.SecurePasswordFile)
{
	$mycred = .\Get-myCredentials.ps1 -User $environment.LoginUser -File $environment.SecurePasswordFile;
} else {
	if ($mycred) 
	{
		Remove-Variable  mycred
	}
}
if ($vcenterServers)
{
	if ($mycred)
	{
		$srvConnection = Connect-VIServer $environment.vCenterSrvName -Credential $mycred
    } else {
		$srvConnection = Connect-VIServer -Server $vcenterServers -NotDefault
	}	
    if ($?)
    {
        Write-Output  "" | out-file -filepath $log -append
        Write-Output "Documenting Infrastructure for:"  | out-file -filepath $log -append
        $srvConnection | out-file -filepath $log -append
    	#.\collectAll.ps1 -srvConnection $srvConnection -logDir $logDir -comment $environment.MoreInfo  | out-file -filepath $log -append
        .\collectAll.ps1 -srvConnection $srvConnection -logDir $logDir -exportExtendedReports $exportExtendedReports | out-file -filepath $log -append
    } else {
        Write-Output  "`r`nError: Not connected to any vCenter Servers" | out-file -filepath $log -append
    }
} else  { 
	Write-Output "Unable to read in the secure string from file $environment.SecurePasswordFile";
}