# Export Datastore and their scsi devices including multipath information, target SAN controllers, path info
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$showDate=$false,[int]$lastMonths=3)
Write-Host s"Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global
$global:logfile
$global:outputCSV

# Want to initialise the module and blurb using this 1 function
#InitialiseModule

$datastores = Get-Datastore * -Server $srvconnection
$report = Get-VMHost * -Server $srvconnection | %{
	$esxServer = $_
	$scsiLuns = $esxServer | Get-ScsiLun -LunType disk
	$clusterName = $(Get-Cluster -VMHost $esxServer).Name
	$scsiLuns | %{
		$scsiLun = $_		
		$cname = $scsiLun.CanonicalName
		$mpol = $scsiLun.MultipathPolicy
		$sruntimename = $scsiLun.RuntimeName
		$datastoreName = ($datastores | ?{$_.ExtensionData.Info.Vmfs.Extent.DiskName -eq $cname}).Name
		
		Write-Host "Processing volume $($esxServer.name)\$datastoreName" -ForegroundColor Yellow
		$scsiPaths = $scsiLun | Get-ScsiLunPath
		$scsiPaths | %{	
			$scsiPath = $_
			$row = "" | select Datastore
			$row.Datastore = $datastoreName
			$row | Add-Member -Type NoteProperty -Name "ESX" -Value $esxServer.Name
			$row | Add-Member -Type NoteProperty -Name "CName" -Value $cname
			$row | Add-Member -Type NoteProperty -Name "Policy" -Value $mpol
			$row | Add-Member -Type NoteProperty -Name "RuntimeName" -Value $sruntimename
			#$row | Add-Member -Type NoteProperty -Name "PathState" -Value $scsiPath.ExtensionData.PathState
			$row | Add-Member -Type NoteProperty -Name "State" -Value  $scsiPath.State
			$row | Add-Member -Type NoteProperty -Name "IsWorkingPath" -Value $scsiPath.ExtensionData.IsWorkingPath
			$row | Add-Member -Type NoteProperty -Name "Adapter" -Value $scsiPath.ExtensionData.Adapter
			$row | Add-Member -Type NoteProperty -Name "CtrlPort" -Value $scsiPath.SanId			
			$row | Add-Member -Type NoteProperty -Name "Cluster" -Value $clusterName
			Write-Host $row -ForegroundColor Green
			$row
		}
	}
}

Write-Host "############################" -ForegroundColor Yellow
Write-Host "[ Report SUMMARY ] "  -ForegroundColor Yellow
$report | Get-Member -MemberType NoteProperty  | select Name | %{
	#$report | select $_ -Unique | measure -Property $_
	Write-Host "$(($report | select $($_.Name) -Unique | measure -Property $($_.Name)).Count) $($_.Name)(s) found"  -ForegroundColor Yellow
}

ExportCSV -table $Report

if ($showDate) {
	Write-Output "" >> $of
	Write-Output "" >> $of
	Write-Output "Collected on $(get-date)" >> $of
}
logThis -msg "Logs written to " $of -ForegroundColor  yellow;

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}