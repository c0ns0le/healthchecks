# Documents a cluster configuration
#Version : 0.6
#Updated : 12th Feb 2010
#Author  : teiva.rodiere-at-gmail.com
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="")
Write-Host "Executing script $($MyInvocation.MyCommand.path)" -ForegroundColor  green;
Write-Host "Current path is $($pwd.path)" -ForegroundColor  yellow;

$disconnectOnExist = $true;

if (!$srvConnection)
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


$filename = ($($MyInvocation.MyCommand.Name)).TrimEnd('.ps1');
Write-Host "$filename";
if ($comment -eq "" ) {
	$of = $logDir + "\"+$filename+"-"+$vcenterName+".csv"
} else {
	$of = $logDir + "\"+$filename+"-"+$comment+".csv"
}
Write-Host "This script log to " $of -ForegroundColor $global:colours.Information 

Write-Host "Enumerating datacenters..."
$Report = Get-Datacenter -Server $srvConnection | %{
	$dc = $_.Name
	Write-Host "Enumerating all Clusters in datacenter $dc..."
	Get-Cluster -Location $_.Name  | Get-View | foreach-object { 
		$clusterConfig = "" | Select-Object "Datacenter";
		$clusterConfig.Datacenter = $dc		
		$clustname = $clusterConfig.Name;
		Write-Host "Exporting cluster settings for $clustname datacenter $dc..."
		$clusterConfig | Add-Member -Type NoteProperty -Name "Cluster" -Value $_.Name;
		$clusterConfig | Add-Member -Type NoteProperty -Name "Server Count" -Value $_.Summary.NumHosts;
		$clusterConfig | Add-Member -Type NoteProperty -Name "Server Used" -Value $_.Summary.NumEffectiveHosts;
		$clusterConfig | Add-Member -Type NoteProperty -Name "CPU Cores" -Value $_.Summary.NumCpuCores;
		$clusterConfig | Add-Member -Type NoteProperty -Name "CPU Threads" -Value $_.Summary.NumCpuThreads;
		$clusterConfig | Add-Member -Type NoteProperty -Name "CPU Actual (Mhz)" -Value $_.Summary.TotalCpu ;
		$clusterConfig | Add-Member -Type NoteProperty -Name "CPU Usable (Mhz)" -Value $_.Summary.EffectiveCpu;
		$clusterConfig | Add-Member -Type NoteProperty -Name "RAM Actual (GB)" -Value "$([math]::ROUND($_.Summary.TotalMemory / 1024))";
		$clusterConfig | Add-Member -Type NoteProperty -Name "RAM Usable (GB)" -Value "$([math]::ROUND($_.Summary.EffectiveMemory /1024))";
		$clusterConfig
	} 
}


Write-Output $Report | Export-Csv $of -NoTypeInformation
Write-Output "" >> $of
Write-Output "" >> $of
Write-Output "Collected on $(get-date)" >> $of

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}