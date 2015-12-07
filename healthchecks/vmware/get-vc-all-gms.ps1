# THis is the scheduler script which allows to be called in a script
# The script runs as a Windows Task on either a management server or vCenter server.
# 
# The username is defined by $userId below and password in an encrypted string from $securestring
# To create the secure string, run the "Set-myCredntials.ps1 -File $userId" whilst logged on as $userId
#
#param([Parameter(Mandatory=$true)][string]$configFile="E:\scripts\customerEnvironmentSettings-ALL.ini")
param([string]$configFile="E:\scripts\customerEnvironmentSettings-ALL.ini")


$vcenterServers = @();
$srvConnections = $null;
Set-PowerCLIConfiguration -DefaultVIServerMode Multiple -Confirm:$false
foreach ($environment in (Import-CSV $configFile) )
{
	$vcenterServers += $environment.vCenterSrvName;
}
#logThis -msg "List of vCenter servers to report: "  
#$vcenterServers 

if ($vcenterServers)
{	
   	$srvConnections = Connect-VIServer -Server $vcenterServers
    if ($?)
    {
		return $srvConnections
    } else {
        logThis -msg "`r`nError: Could not connect to one or more vCenter Servers specified in $configFile" 
    }
} else  { 
	logThis -msg "Unable to read a list of vCenter Servers from $configFile";
}