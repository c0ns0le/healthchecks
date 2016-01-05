# GatherIOPS.ps1 -srvconnection $srvconnection
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",$datastores=(Get-Datastore),[int]$numsamples=([int]::MaxValue),[int]$numPastDays=7,[bool]$verbose=$true,[int]$sampleIntevalsMinutes=5)

#$username = read-host -prompt "Please enter local user account for host access"
#read-host -prompt "Please enter password for host account" -assecurestring | convertfrom-securestring | out-file cred.txt
#$password = get-content cred.txt | convertto-securestring
#$credentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $username,$password


# add VMware PS snapin
if (-not (Get-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) {
    Add-PSSnapin VMware.VimAutomation.Core
}
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

Write-Host "This script log to " $of -ForegroundColor $global:colours.Information 

$IOPSReport = @()

#foreach ($datastore in $datastores) {

# Grab datastore and find VMs on that datastore
#$myDatastore = Get-Datastore -Name $datastore -server $server
$myVMs = Get-VM -server $srvconnection | Where {$_.PowerState -eq "PoweredOn"}
Write-Host "$($myVMs.Count) found" -BackgroundColor $global:colours.Error -ForegroundColor $global:colours.Information
$vmIndex=1;
$IOPSReport = $myVMs | %{
	$vm = $_;	
	# Gather current IO snapshot for each VM
	#$dataArray = @()
	#foreach ($vm in $myVMs) {
	Write-Host "$vmIndex/$($myVMs.Count) :- $($vm.Name)"
	$row = "" | Select "VM"
	$row."VM" = $vm.name
	#$row | Add-Member -Type NoteProperty -Name "Interval (minutes)" = ($numsamples*20)/60
	$stats=@();
	#$row | Add-Member -Type NoteProperty -Name "Interval (minutes)" = 
	#$stats = Get-Stat -Entity $vm -Stat disk.numberWrite.summation -MaxSamples $numsamples -Start (Get-Date).AddDays(-$numPastDays)
	$stats = Get-Stat -Entity $vm -Stat disk.write.average -MaxSamples $numsamples -Start (Get-Date).AddDays(-$numPastDays) -IntervalMins $sampleIntevalsMinutes
	#$stats = Get-Stat -Entity $vm -Stat disk.write.average -Start (Get-Date).AddDays(-$numPastDays)
	if ($stats)
	{
		$statsMeasured = $stats | measure -Property Value -Sum -Average -Maximum -Minimum
		#$row | Add-Member -Type NoteProperty -Name "Avg Write IOPS" = GetAvgStat -vmhost $vm.host.name -vm $vm.name -ds $datastore -samples $numsamples -stat disk.numberWrite.summation
		$row | Add-Member -Type NoteProperty -Name "Write Avg Per Second" -Value "$([math]::Round($statsMeasured.Average,2))"	
		$row | Add-Member -Type NoteProperty -Name "Write Peak Per Second" -Value "$([math]::Round($statsMeasured.Maximum,2))"
		$row | Add-Member -Type NoteProperty -Name "Write Min Per Second" -Value "$([math]::Round($statsMeasured.Minimum,2))"
		$interval = -$($stats[1].Timestamp - $stats[0].Timestamp).TotalSeconds/60
		$row | Add-Member -Type NoteProperty -Name "Write Samples " -Value "$($statsMeasured.Count) samples over $numPastDays Days at $interval minutes intervals"
		$row | Add-Member -Type NoteProperty -Name "Write Stats Description"  -Value $stats[0].Description;
		#$row | Add-Member -Type NoteProperty -Name "Avg Read IOPS" = GetAvgStat -vmhost $vm.host.name -vm $vm.name -ds $datastore -samples $numsamples -stat disk.numberRead.summation		
	}

	$stats=@();
	#$stats = Get-Stat -Entity $vm -Stat disk.numberRead.summation -MaxSamples $numsamples -Start (Get-Date).AddDays(-$numPastDays)
	$stats = Get-Stat -Entity $vm -Stat disk.read.average -MaxSamples $numsamples -Start (Get-Date).AddDays(-$numPastDays) -IntervalMins $sampleIntevalsMinutes
	#$stats = Get-Stat -Entity $vm -Stat disk.read.average -Start (Get-Date).AddDays(-$numPastDays)
	if ($stats)
	{
		$statsMeasured=$stats | measure -Property Value -Sum -Average -Maximum -Minimum
		#$row | Add-Member -Type NoteProperty -Name "Avg Write IOPS" = GetAvgStat -vmhost $vm.host.name -vm $vm.name -ds $datastore -samples $numsamples -stat disk.numberWrite.summation
		$row | Add-Member -Type NoteProperty -Name "Read Avg Per Second" -Value "$([math]::Round($statsMeasured.Average,2))"
		$row | Add-Member -Type NoteProperty -Name "Read Peak Per Second" -Value "$([math]::Round($statsMeasured.Maximum,2))"
		$row | Add-Member -Type NoteProperty -Name "Min Read Per Second" -Value "$([math]::Round($statsMeasured.Minimum,2))"
		$interval = -$($stats[1].Timestamp - $stats[0].Timestamp).TotalSeconds/60
		$row | Add-Member -Type NoteProperty -Name "Read Samples" -Value "$($statsMeasured.Count) samples over $numPastDays Days at $interval minutes intervals"
		$row | Add-Member -Type NoteProperty -Name "Read Description" -Value $stats[0].Description;
		#$row | Add-Member -Type NoteProperty -Name "Avg Read IOPS" = GetAvgStat -vmhost $vm.host.name -vm $vm.name -ds $datastore -samples $numsamples -stat disk.numberRead.summation		
	}
	$row | Add-Member -Type NoteProperty -Name "vCenter" -Value $srvConnection.Name.ToUpper()
	#$dataArray += $row
	if ($verbose) {Write-Host $row}
	#$dataArray;
	$row;
	$vmIndex++;
}

#$IOPSReport
$IOPSReport | Export-CSV $of -NoType
if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
	Write-Host  "-> Disconnected from $srvConnection <-"
}

Write-host "Log file written to $of"