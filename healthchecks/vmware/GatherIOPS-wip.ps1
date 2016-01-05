################################################################################
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$showOnlyTemplates=$false,[bool]$skipEvents=$true,[bool]$verbose=$false, [int]$numsamples=90)
Write-Host "Executing script $($MyInvocation.MyCommand.path)" -ForegroundColor  green;
Write-Host "Current path is $($pwd.path)" -ForegroundColor  yellow;

$disconnectOnExist = $true;

#$username = read-host -prompt "Please enter local user account for host access"
#read-host -prompt "Please enter password for host account" -assecurestring | convertfrom-securestring | out-file cred.txt
#$password = get-content cred.txt | convertto-securestring
#$credentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $username,$password
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




#[vSphere PowerCLI] D:\INF-VMware\scripts> $viEvent = $vms | Get-VIEvent -Types info | where { $_.Gettype().Name -eq "VmBeingDeployedEvent"}
$runtime="$(date -f dd-MM-yyyy)"
$filename = ($($MyInvocation.MyCommand.Name)).TrimEnd('.ps1');
Write-Host "$filename";
if ($comment -eq "" ) {
	$of = $logDir + "\"+$runtime+"_"+$vcenterName.ToUpper()+"_"+$filename+".csv"
} else {
	$of = $logDir + "\"+$runtime+"_"+$vcenterName.ToUpper()+"_"+$filename+"-"+$comment+".csv"
}

Write-Host "This script log to " $of -ForegroundColor $global:colours.Information 


# add VMware PS snapin
if (-not (Get-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) {
    Add-PSSnapin VMware.VimAutomation.Core
}

# connect vCenter server session
#Connect-VIServer $srvconnection -NotDefault -WarningAction SilentlyContinue | Out-Null
#



$IOPSReport = @()
$datastores = @()
if (!$datastores)
{
	$datastores = Get-Datastore -Server $srvconnection
}

foreach ($currDatastore in $datastores) 
{
	# Grab datastore and find VMs on that datastore
	#$currDatastore = Get-Datastore -Name $datastore -server $srvconnection
	echo "me -> $currDatastore"
  	$currVMs = Get-VM -Datastore $currDatastore -server $srvConnection | Where {$_.PowerState -eq "PoweredOn"}
	if($currVMs)
	{  	
	  	$dataArray = @(); # Gather current IO snapshot for each VM
	  	foreach ($vm in $currVMs) {
		  	$data = “” | Select "VM", "Interval (minutes)", "Avg Write IOPS", "Avg Read IOPS","Status"
		  	$data."VM" = $vm.name
		  	$data."Interval (minutes)" = ($numsamples*20)/60
			
			## Get WRites Stats
			#$vmhost = get-vmhost $vm.host.name
			#$rawVMStats = get-stat -entity	$vm -server $vmhost -stat $stat -maxSamples $samples
			$rawVMStats = get-stat -Entity	$vm -stat "disk.numberWrite.summation" -datastore $currDatastore -maxSamples $numsamples
			
			$results = @()
			
			foreach ($stat in $rawVMStats) {
				if ($stat.instance.Equals($currDatastoreID)) {
					$results += $stat.Value
				}
			}

			$totalIOPS = 0
			foreach ($res in $results) {
				$totalIOPS += $res	
			}			
		  	$data."Avg Write IOPS" = $totalIOPS / $numsamples / 20
			
			
			## Get Reads Stats
			$rawVMStats = get-stat -entity	$vm -stat "disk.numberRead.summation" -maxSamples $numsamples
			$results = @()
			foreach ($stat in $rawVMStats) {
				if ($stat.instance.Equals($currDatastoreID)) {
					$results += $stat.Value
				}
			}
			$totalIOPS = 0
			foreach ($res in $results) {
				$totalIOPS += $res	
			}
		  	$data."Avg Read IOPS" =$totalIOPS / $numsamples / 20			
		  	$dataArray += $data
	  	}
		

	  	# Do something with the array of data
  		$IOPSReport += $dataArray
  	}
}

$IOPSReport
$IOPSReport | Export-CSV $of -NoType