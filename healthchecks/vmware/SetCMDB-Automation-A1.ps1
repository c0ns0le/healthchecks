# THis is the scheduler script which allos collect-All.ps1 to be called in a script
# The script runs as a Windows Task on either a management server or vCenter server.
# 
# The username is defined by $userId below and password in an encrypted string from $securestring
# To create the secure string, run the "Set-myCredntials.ps1 -File $userId" whilst logged on as $userId
#
param([object]$logDir="output",[string]$logDir="output",[string]$comment="",[bool]$showDate=$false,[int]$lastMonths=3,[bool]$includeThisMonth=$false)
Add-pssnapin VMware.VimAutomation.Core
#$errorActionPreference = "silentlycontinue"
$logDir = ".\scheduler\ventyx_dev_vmware"
$log = "$logDir\SetCMDB-scheduler.log"

# Delete previous logs
if ((Test-Path -path $logDir) -ne $true) {
	Write-Host "Creating output directory as [" $logDir "]";
	New-Item -type directory -Path $logDir
} else {
	#rm -recurse -force $log
	rm -recurse -force "$logDir\SetCMDB-*"
}
Write-Output "Running script $($MyInvocation.MyCommand.path) from $($env:computername)" | out-file -filepath $log
get-date  | out-file -filepath $log -append
$vcenterServers = @();

foreach ($environment in (Import-CSV ".\customerEnvironmentSettings-DEV.ini") )
{
        $vcenterServers += $environment.vCenterSrvName;
}
Write-Output "List of vCenter servers to report: "  | out-file -filepath $log -append
$vcenterServers | out-file -filepath $log -append


if ($vcenterServers)
{
	# no need for this one because the account used by the service account GMS\svc-autobot has credentials in Managed Services
	 = Connect-VIServer $environment.vCenterSrvName -Credential $mycred
	
    $srvConnection = Connect-VIServer -Server $vcenterServers -NotDefault
    if ($?)
    {
        Write-Output  "" | out-file -filepath $log -append
        Write-Output "Processing Infrastructure for:"  | out-file -filepath $log -append
        $srvConnection | out-file -filepath $log -append
		
		##################################################
		# Set special AR Systems Remedy Custom Attributes 
		##################################################
		#Write-Output "Starting SetCMDB-CustomAttributes.ps1 at $(get-date)" | out-file -filepath $log -append
        .\SetCMDB-CustomAttributes.ps1 -srvConnection $srvConnection -logDir $logDir -verbose $false -showSkipped $false -readonly $false -showDate $true -processHosts $true -processVMs $true -promptForConfirmation $false -disconnectOnExist $false| out-file -filepath $log -append
		#Write-Output "Completed at $(get-date)" | out-file -filepath $log -append
		
		####################################################
		# Set Commissioning by/date and Last changes By/Date
		# The values are adjusted from UTC to EAST (+10)
		####################################################
		Write-Output "Starting set-VM-CommissionDetails.ps1 at $(get-date)" | out-file -filepath $log -append
		#.\set-VM-CommissionDetails.ps1 -srvConnection $srvconnection  -logDir $logDir -reportOnly $true -verbose $true -overwrite $true -disconnectOnExist $true -debugFile "$logDir/SetCMDB-CustomAttribute-Commission-DEBUG.log" 
        .\set-VM-CommissionDetails.ps1 -srvConnection $srvconnection  -logDir $logDir -reportOnly $false -verbose $true -overwrite $false -disconnectOnExist $true 
		Write-Output "Completed at $(get-date)" | out-file -filepath $log -append		
    } else {
        Write-Output  "`r`nError: Not connected to any vCenter Servers" | out-file -filepath $log -append
    }
} else  { 
	Write-Output "Unable to read in the secure string from file $environment.SecurePasswordFile" | out-file -filepath $log -append;
}