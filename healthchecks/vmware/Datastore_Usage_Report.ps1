# This script exports common performance stats and outputs to 2 output document
# Output 1: It looks at averages, min and peak information for an entire period defined in variable "lastMonths"
# Output 2: It looks at averages, min and peak information for each month over the period defined in variable "lastMonths"
# for the entire period and averages out 
# Full compresensive list of metrics are available here: http://communities.vmware.com/docs/DOC-560
# maintained by: teiva.rodiere@gmail.com
# version: 3
#
#   Step 1) $srvconnection = get-vc <vcenterServer>
#	Step 2) Run this script using examples below
#			Datastore_Usage_report.ps1 -srvconnection $srvconnection
#
param(	[object]$srvConnection="",
		[string]$logDir="output",
		[string]$comment="",
		[bool]$includeThisMonthEvenIfNotFinished=$true,
		[int]$showPastMonths=6,
		[int]$headerType=1,
		[bool]$returnResults=$true,
		[Object]$datastore,
		[Object]$vcenter,
		[bool]$resultsForCharting=$true # if you want to chart the results, then set that to true so values will be returned as GB not as text. ie: '1,300.00' instead of '1,300.00 GB'
)

#$([int]::MaxValue),
logThis -msg "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru -Verbose:$false
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global

#Write-Host "vCenter Name: $($srvConnection.Name)"
#Write-Output "ScriptName: $($global:scriptName)" | Out-File "C:\admin\OUTPUT\AIT\19-11-2015\Capacity_Reports\$($global:scriptName).txt"
#Write-Output "vCenter: $($srvConnection.Name)" | Out-File "C:\admin\OUTPUT\AIT\19-11-2015\Capacity_Reports\$($global:scriptName).txt" -Append
#Write-Output "LogDir: $logDir" | Out-File "C:\admin\OUTPUT\AIT\19-11-2015\Capacity_Reports\$($global:scriptName).txt" -Append

#$global:logfile
#$global:outputCSV

# Want to initialise the module and blurb using this 1 function
InitialiseModule -logDir $logDir -parentScriptName $($MyInvocation.MyCommand.name)

$now = get-date #(get-date).AddMonths(-1) #use now but because we are half way thought the month, i only want up to the last day of the previous month

if ($datastore)
{
	if (!$datastore.vCenter)
	{
		$datastore | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenter.Name
	}
	$datastores = $datastore
	#$datastores | ft
	#$datastores.vCenter
	#pause

} else {
	$datastores = ($srvConnection | %{ 
		$vcenter=$_; get-datastore -server $_ | %{ 
			$_ | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vcenter.Name; 
			$_
		}  | sort -Property Name
	})
}

#$datastores
if (!$datastores)
{
	showError "No datastores found"
} else {
	$title="Datastore Capacity Usage"
	logThis -msg "Collecting usage stages for datastores on a monthly basis for the past $showPastMonths Months..." -foregroundcolor Green	
	$today = Get-Date
	$reportLastDay = $today
	$reportFirstDay = forThisdayGetFirstDayOfTheMonth -day ($today.AddMonths(-$showPastMonths))
	
	$metrics = "disk.capacity.latest","disk.provisioned.latest","disk.used.latest"
	
	$dataTable = $datastores | %{
		
		$ds=$_
		$myvCenter = $srvConnection | ?{$_.Name -eq $ds.vCenter}
		logThis -msg "Processing $($_.Name)"
		$report = @()
		$row = New-Object System.Object
		$row | Add-Member -MemberType NoteProperty -Name "Datastore" -Value $ds.Name
		#Write-Host $ds.Name
		#pause
		$tmp = Get-Stat2 -entity $ds -stat $metrics -interval "HI2" -vcenter $myvCenter -start $reportFirstDay -finish $reportLastDay;
		#$tmp = Get-Stat2 -entity $ds.ExtensionData -stat $metrics -interval "HI2" -vcenter $myvCenter -start $reportFirstDay -finish $reportLastDay;
		$tmp | %{ $_.Timestamp = get-date $_.Timestamp}
		$report = $tmp | sort-Object -Property Timestamp | group-Object -Property Timestamp | %{
			New-Object PSObject -Property @{
				"Datastore" = $ds.Name
				Timestamp = $_.Name
				"Capacity (GB)" = [Math]::Round(($_.Group |	where {$_.CounterName -eq "disk.capacity.latest"}).Value/1MB,2)
				"Used (GB)" = [Math]::Round(($_.Group |	where {$_.CounterName -eq "disk.used.latest"}).Value/1MB,2)
				"Allocated (GB)" = [Math]::Round(($_.Group | where {$_.CounterName -eq "disk.provisioned.latest"}).Value/1MB,2)				
			}
		}
		$maxDSSizeGB=($report."Capacity (GB)" | measure -Maximum).Maximum
		if (!$resultsForCharting)
		{
			$row | Add-Member -MemberType NoteProperty -Name "Size" -Value (getSize -unit GB -val $maxDSSizeGB)
		} else {
			$row | Add-Member -MemberType NoteProperty -Name "Size (GB)" -Value $maxDSSizeGB
		}
		
		$prevMonthCapacityGB=0
		$prevMonthName=""
		$lastMonthCapacityGB=0
		$erroractionpreference  = "SilentlyContinue"
		if ($showPastMonths -gt 0)
		{
			$monthIndex = $showPastMonths
			while ($monthIndex -le $showPastMonths -and $monthIndex -gt 0)
			{
				$firstDay = forThisdayGetFirstDayOfTheMonth -day $today.AddMonths(-$monthIndex)
				$lastDay = forThisdayGetLastDayOfTheMonth -day $today.AddMonths(-$monthIndex)
				$currMonthName = getMonthYearColumnFormatted($firstDay)
				logThis -msg "`t- For $currMonthName [$firstDay -> $lastDay]";
				$currMaxCapacityGB = ($report | ?{(Get-Date $_.Timestamp) -ge $firstDay -and (Get-Date $_.Timestamp) -le $lastDay } | measure -Property "Used (GB)" -Maximum).Maximum
				$currSizeGB = ($report | ?{(Get-Date $_.Timestamp) -ge $firstDay -and (Get-Date $_.Timestamp) -le $lastDay } | measure -Property "Capacity (GB)" -Maximum).Maximum
				$fieldName="Used in $currMonthName"
				if ($currMaxCapacityGB -and $currSizeGB)
				{
					$value = ("{0:n2}" -f ($currMaxCapacityGB/$currSizeGB*100))
				} else {
					$value = "-"
				}
				if (!$resultsForCharting)
				{
					if ($value -ne "-")
					{
						$value="$value %"
					}
					$fieldName="$fieldName (%)"
				}
				$row | Add-Member -MemberType NoteProperty -Name $fieldName -Value $value
				
				if ($monthIndex -eq 1) 
				{
					$lastMonthName=$currMonthName
					$lastMonthCapacityGB=$currMaxCapacityGB
				}
				if ($monthIndex -eq 2) 
				{
					$secondLastMonthName=$currMonthName
					$secondLastMonthCapacityGB=$currMaxCapacityGB
				}
				$monthIndex--
			}
			
			if ($lastMonthCapacityGB -and $secondLastMonthCapacityGB)
			{
				$value=($lastMonthCapacityGB-$secondLastMonthCapacityGB)/$secondLastMonthCapacityGB*100
			} else {
				$latestIncreasedPerc="-"
			}
			
			if (!$resultsForCharting)
			{
				$row | Add-Member -MemberType NoteProperty -Name "$secondLastMonthName to $lastMonthName Increase" -Value ("{0:N2} %" -f $latestIncreasedPerc)
			} else {					
				$row | Add-Member -MemberType NoteProperty -Name "$secondLastMonthName to $lastMonthName Increase (%)" -Value ("{0:N2}" -f $latestIncreasedPerc)
			}
			
			$value=""
			$fieldName = "$currMonthName Increase"			
			if ($currMaxCapacityGB -and $lastMonthCapacityGB)
			{
				$value=("{0:n2}" -f ($currMaxCapacityGB-$lastMonthCapacityGB)/$lastMonthCapacityGB*100)
			} else {
				$value="-"
			}
			if (!$resultsForCharting)
			{
				if ($value -ne "-")
				{
					$value="$value %"
				}
				$fieldName="$fieldName (%)"
			}
			$row | Add-Member -MemberType NoteProperty -Name "$currMonthName Increase" -Value $value
					
		}
		
		
		
		if ($includeThisMonthEvenIfNotFinished)
		{
			######################################################
			# Get Stats for all the days so far in this month
			######################################################
			#New-Variable -Name $tableColumnHeaders[1] -Value ($sourceVIObject | Get-Stat -Stat $metric -Start (Get-Date).adddays(-7) -Finish (Get-Date) -MaxSamples $maxsamples -IntervalMins $sampleIntevalsMinutes | select *)
			
			$firstDayOfMonth = forThisdayGetFirstDayOfTheMonth($today)
			$currMonthName = "Last $(daysSoFarInThisMonth($today)) Days"
			logThis -msg "`t- The last $(daysSoFarInThisMonth($firstDay)) Days [$firstDayOfMonth -> now]";
			$currMaxCapacityGB = $($report | ?{(Get-Date $_.Timestamp) -ge $firstDayOfMonth -and (Get-Date $_.Timestamp) -le $today } | measure -Property "Used (GB)" -Maximum).Maximum
			$currSizeGB = $($report | ?{(Get-Date $_.Timestamp) -ge $firstDayOfMonth -and (Get-Date $_.Timestamp) -le $today } | measure -Property "Capacity (GB)" -Maximum).Maximum
			$fieldName = "Used in the $currMonthName"
			
			if ($currMaxCapacityGB -and $currSizeGB)
			{
				$value = ("{0:n2}" -f ($currMaxCapacityGB/$currSizeGB*100))
			} else {
				$value = "-"
			}
			if (!$resultsForCharting)
			{
				if ($value -ne "-")
				{
					$value="$value %"
				}
				$fieldName="$fieldName (%)"
			}
			$row | Add-Member -MemberType NoteProperty -Name $fieldName -Value $value
			
			$value=""
			$fieldName = "$currMonthName Increase"			
			if ($currMaxCapacityGB -and $lastMonthCapacityGB)
			{
				$value=("{0:n2}" -f ($currMaxCapacityGB-$lastMonthCapacityGB)/$lastMonthCapacityGB*100)
			} else {
				$value="-"
			}
			if (!$resultsForCharting)
			{
				if ($value -ne "-")
				{
					$value="$value %"
				}
				$fieldName="$fieldName (%)"
			}
			$row | Add-Member -MemberType NoteProperty -Name "$currMonthName Increase" -Value $value
		}
		$row
	}
	
	
	if ($dataTable)
	{
		#$dataTable $dataTable
		$objMetaInfo = @()
		$objMetaInfo +="tableHeader=$title"
		$objMetaInfo +="introduction=Find below the usage report for all datastores audited. "
		$objMetaInfo +="chartable=false"
		$objMetaInfo +="titleHeaderType=h$($headerType+1)"
		$objMetaInfo +="showTableCaption=false"
		$objMetaInfo +="displayTableOrientation=Table" # options are List or Table
		$metricCSVFilename = "$logdir\$($title -replace '\s','_').csv"
		$metricNFOFilename = "$logdir\$($title -replace '\s','_').nfo"
		if ($metaAnalytics)
		{
			$metaInfo += "analytics="+$metaAnalytics
		}	
		if ($returnResults)
		{
			return $dataTable,$metaInfo
		} else {
			ExportCSV -table $dataTable -thisFileInstead $metricCSVFilename 
			ExportMetaData -metadata $objMetaInfo -thisFileInstead $metricNFOFilename
			updateReportIndexer -string "$(split-path -path $metricCSVFilename -leaf)"
		}
	}
}

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}