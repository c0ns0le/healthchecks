# Exports Virtual Machine Quick Stats
#Version : 0.1
#Author : 23/08/2012, by teiva.rodiere-at-gmail.com
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$verbose=$false,[int]$lastDays=5)
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


$metrics = @("cpu.usage.average","mem.active.average")
$start = (get-date).AddDays(-$lastDays) 



$filename = ($($MyInvocation.MyCommand.Name)).TrimEnd('.ps1');
Write-Host "$filename";
if ($comment -eq "" ) {
	$of = $logDir + "\"+$filename+"-"+$vcenterName+"-Last"+$lastDays+"days.csv"
} else {
	$of = $logDir + "\"+$filename+"-"+$comment+"-Last"+$lastDays+"days.csv"
}
Write-Host "This script log to " $of -ForegroundColor $global:colours.Information 


$report = @()
$Report = $srvConnection | %{
    $vCenterServer = $_.Name
    Write-Host "Exporting list of Powered On system from vCenter server"
    $vms = Get-Vm -Server $vCenterServer | where {$_.PowerState -eq "PoweredOn"} 
    Write-Host "$($vms.Count) found"

    Write-Host "Exporting stats for the last $lastDays Days all VMs found (this will take a while depending on the number of systems found)..."
    $vmStats = Get-Stat -Entity ($vms[0]) -start $start -stat $metrics | Group-Object -Property EntityId
    #$vmStats = Get-Stat -Entity ($vms) -start $start -stat $metrics | Group-Object -Property EntityId

    Write-Host "Processing stats"
    $vmStats | %{
        $vmStat = $_;
        Write-Host "Processing VM $index/$($vmStats.Count) - $($_.Group[0].Entity.Name)" -ForegroundColor $global:colours.Information
        $row = ""| Select "Name" # "MinCpu", "AvgCpu", "MaxCpu", "MemAlloc", "MinMem", "AvgMem", "MaxMem", "vCenter"
        $row.Name = $_.Group[0].Entity.Name
        $row | Add-Member -Type NoteProperty -Name "Timestamp" -Value ($_.Group | Sort-Object -Property Timestamp)[0].Timestamp
        $row | Add-Member -Type NoteProperty -Name "vCPU" -Value $_.Group[0].Entity.NumCpu
        $row | Add-Member -Type NoteProperty -Name "MemAlloc" -Value $_.Group[0].Entity.MemoryMB
        foreach ($metric in $metrics)
        {
            $hardware,$type,$measure = $_.split(".");
            $objStat = $vmStat.Group | where {$_.MetricId -eq $metric} | Measure-Object -Property Value -Minimum -Maximum -Average
            Write-Host $objStat
            $min = "{0:f2}" -f ($objStat.Minimum)
            $avg = "{0:f2}" -f ($objStat.Average)
            $max = "{0:f2}" -f ($objStat.Maximum)
            
            $row | Add-Member -Type NoteProperty -Name "Min$hardware$type" -Value $min
            $row | Add-Member -Type NoteProperty -Name "Avg$hardware$type" -Value $avg
            $row | Add-Member -Type NoteProperty -Name "Max$hardware$type" -Value $max

            #$memStat = $_.Group | where {$_.MetricId -eq "mem.active.average"} | Measure-Object -Property Value -Minimum -Maximum -Average    
            #$row.MinMem = "{0:f2}" -f ($memStat.Minimum)
            #$row.AvgMem = "{0:f2}" -f ($memStat.Average)
            #$row.MaxMem = "{0:f2}" -f ($memStat.Maximum)
        }
        if ($verbose)
        {
            Write-host $row
        }
        $row
    }
}

$Report | Export-Csv $of -NoTypeInformation -UseCulture
