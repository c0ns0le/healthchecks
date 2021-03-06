# Scripts to centralises the calling of many other powershell scripts into a single execution. This collectall version collects only VMware related scripts
# Add and remove as required.
# Syntax: $scriptsLoc\collectAll.ps1 -srvconnection $srvconnection -logDir "C:\temp\yourpath" -exportExtendedReports $true
# Version : 7.6
# Author : 9/11/2015, by teiva.rodiere-at-gmail.com
param(
	[object]$srvConnection,
	[string]$vcenterName="",
	[string]$userid="",
	[bool]$promptForCredentials=$true,
	[string]$logDir="output",
	[string]$comment,
	[string]$logProgressHere,
	[bool]$runExtendedReports=$false,
	[bool]$runCapacityReports=$true,
	[bool]$runPerformanceReports=$false,
	[bool]$runIssuesReports=$false,
	[bool]$disconnectOnExit=$false,
	[bool]$generateHTMLReport=$false,
	[bool]$runDevReports=$false,
	[int]$showPastMonths=6,
	[object]$vms,
	[bool]$silent=$false,
	[bool]$runJobsSequentially=$true,
	[bool]$outpuToXML=$false,
	[bool]$outpuToCSV=$false,
	[bool]$outpuToHTML=$false,
	[bool]$returnResultsOnly=$true
)

$scriptsLoc=$(Split-Path $($MyInvocation.MyCommand.Path))
if (!$silent) { logThis -msg  "Importing Module vmwareModules.psm1 (force)" }
Import-Module -Name "$scriptsLoc\vmwareModules.psm1" -Force
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global

Set-Variable -Name reportIndex -Value "$logDir\index.txt" -Scope Global
Set-Variable -Name runningJobIndexFile -Value "$logDir\job-index.txt" -Scope Global
Set-Variable -Name runningJobListFile -Value "$logDir\job-list.txt" -Scope Global

logThis -msg "$global:runtimeCSVMetaFile" -ForegroundColor $global:colours.Information -BackgroundColor $global:colours.Error -logFile $logFile

$errorActionPreference = "silentlycontinue"
# Want to initialise the module and blurb using this 1 function


Set-Variable -Name logDir -Value $logDir -Scope Global
$global:jobs = @()
$global:runningJobCount = 0
$global:completedJobCount = 0

function callJob ($scrpt,$params)
{
	Invoke-Expression -Command "$scrpt $params"
}

function collectJobs { 
#Detects jobs with status of Completed or Stopped.
#Collects jobs output to log file, increments the "done jobs" count, 
#Then rebuilds the $jobs array to contain only running jobs.
#Modifies variables in the script scope.
	$completedJobArray = @(); #Completed jobs 
	
	$completedJobArray += $global:jobs | ? {$_.State -match "Completed|Stopped|Failed|Blocked"} ;
	[string]$('$completedJobArray.count = ' + $completedJobArray.count + ' ; Possible number of jobs completed in this colleciton cycle.') | Out-File $global:runningJobIndexFile -Append;
	if ($completedJobArray[0] -ne $null) { #First item in done jobs array should not be null.
		$global:runningJobCount += $completedJobArray.count; #increment job count
		[string]$('$global:runningJobCount = ' + $global:runningJobCount + ' ; Total number of completed jobs.') | Out-File $global:runningJobIndexFile -Append;
		$completedJobArray | Receive-Job | Out-File $global:runningJobIndexFile -Append; #log job output to file
		$completedJobArray | Remove-Job -Force;
		Remove-Variable completedJobArray;
		$global:jobs = @($global:jobs | ? {$_.State -eq "Running"}) ; #rebuild jobs arr
		[string]$('$global:jobs.count = ' + $global:jobs.Count + ' ; Exiting function...') | Out-File $global:runningJobIndexFile -Append
	} else {
		[string]$('$completedJobArray[0] is null.  No jobs completed in this cycle.') | Out-File $global:runningJobIndexFile -Append
	}
}


########################################################################
#
# FUNCTIONS
#
########################################################################

function executeReports ([string]$type,[Object]$collection)
{
	$index = 1;
	$global:results["Reports"][$type]=@{}
	$localReportIndex=0
	$collection | %{
		
		if ($_.GetType().Name -eq "Object[]")
		{
        	$subScriptName = $_[0].Trim()
			
			if($_[1]) { 
				$additionalParameters = $_[1].Trim() 
				$parameters=" $additionalParameters"
			}
		} else {
			$subScriptName = $_.Trim()
		}
		Write-Progress -Id 1 -Activity "Processing $type reports" -CurrentOperation "$index/$($collection.Count) - $subScriptName" -PercentComplete $($index/$($collection.Count)*100)
		
		$global:results["Runtime"]["Index"][$global:reportIndexCount] = $subScriptName
		#break

		if ($subScriptName -and ($subScriptName -like "*.ps1*") )
		{
			# EXtra checks to ensure log dir is in there
			$params = @{}
			$params.Add('srvconnection',$srvConnection)
			$params.Add('logDir',$logDir)
			$params.Add('returnResults',$returnResultsOnly)
			
			#$parameters +=' -srvconnection $srvconnection '
			#if (!($parameters -match "-logDir"))
			#{
				#$parameters += ' -logDir $global:logDir'
			#}
			#if (!($parameters -match "-comment") -and $comment)
			#{
			#	$parameters += ' -comment $comment'
			#}
			
			if ($parameters)
			{
				$parameters -split '-' | %{
					$paramName,$paramValue = $_.Trim() -split ' '
					if ($paramName)
					{
						$params.Add($paramName.Trim(),$paramValue.Trim())
					}
				}
			}
			#$params
			#
			updateReportIndexer -string $($subScriptName.Replace("$scriptsLoc\","").Replace("ps1","csv"))
			#logThis -msg "##########################################################################"  -ForegroundColor $global:colours.Information
			#logThis -msg "# Processing report $index/$($collection.Count)"  -ForegroundColor $global:colours.Information  
			#logThis -msg "# $subScriptName  "  -ForegroundColor $global:colours.Information 
			#logThis -msg "# $parameters"  -ForegroundColor $global:colours.Information  
			#logThis -msg "###########################################################################" -ForegroundColor $global:colours.Information 
			#logThis -msg "`t`t-> Executing [$index/$($collection.Count)] :- $subScriptName $parameters " -logFile $logProgressHere
			
			
			
			# Execute the script
			#[string]$cmd = 
			#Invoke-Command -ScriptBlock { param($scrpt,[Object]$p); Invoke-Expression -Command "$scrpt @p" } -ArgumentList $subScriptName,$params
			$startTime=Get-Date
			if ($runJobsSequentially)
			{	
				$datatable,$metadata,$logs = & $subScriptName @params
				
			} else {
				$jobName = (Split-Path $subScriptName -Leaf) 		
				#$job = Start-Job -Name $jobName -ScriptBlock $script -ArgumentList $name,$tableParameters
				$global:jobs += Start-Job -ScriptBlock {param($s,$p)
					& $s @p
				} -ArgumentList $subScriptName,$params -Name $jobName
				 #+= $job
				#$global:jobs | Out-File "$logDir\jobs.txt" -Append
				#$global:jobs | fl | Out-File $global:runningJobListFile -Append
			}
			$endTime=Get-Date
			
			if ($datatable)
			{
				#if ($metadata)
				#{
				#	$reportName = (($metadata | select-String "tableHeader") -split '=') | Select -Last 1					
				#} else {				
				#$reportName = $subScriptName				
				#}				[]
				
				$global:results["Reports"][$type][$localReportIndex]=@{}
				$global:results["Reports"][$type][$localReportIndex]["Metadata"] = $metadata
				$global:results["Reports"][$type][$localReportIndex]["DataTable"] = $datatable
				$global:results["Reports"][$type][$localReportIndex]["Runtime"] = @{}
				$global:results["Reports"][$type][$localReportIndex]["Runtime"]["StartTime"] = $startTime
				$global:results["Reports"][$type][$localReportIndex]["Runtime"]["EndTime"] = $endTime
				$global:results["Reports"][$type][$localReportIndex]["Runtime"]["TotalRuntime"] = $(getTimeSpanFormatted -timespan (New-TimeSpan -Seconds ($endTime-$startTime).TotalSeconds))
				$global:results["Reports"][$type][$localReportIndex]["Runtime"]["Logs"] = $logs
			}
			$localReportIndex++
			$global:reportIndexCount++
			
		} elseif ($subScriptName -and !($subScriptName -like "*.ps1*") )		
		{
			# a command that is past without .ps1 extension will be treated as a function
			iex "setSectionHeader $parameters"
		} else {
			logthis -msg "No subScriptname found"
		}
        	$index++;
        	Remove-variable additionalParameters 
		Remove-variable subScriptName 
		Remove-variable parameters
		
		
		logThis -msg "Total Runtime: $(getTimeSpanFormatted -timespan (New-TimeSpan -Seconds ($endTime-$startTime).TotalSeconds))" -ForegroundColor $global:colours.Information
		logThis -msg "`t`t`tTotal Runtime: $(getTimeSpanFormatted -timespan (New-TimeSpan -Seconds ($endTime-$startTime).TotalSeconds))" -foregroundcolor Black -logFile $logProgressHere
    }
}

#logThis -msg $logProgressHere
#if (!$logProgressHere) { $logProgressHere="$logDir\$($global:scriptName -replace '.ps1','.log')" }
########################################################################
#
# DEFINITIONS
#
########################################################################
#reportIndex is a file in which the name of the script found below will be placed in sequential order that they get called
# This file will be used by generateInfrastructureReport.ps1 that it may display the output raw data (CSV) in the order specified below
# If you want to change the report display order then change the order of scripts below
$vmReportFilter=""
$performanceFilters=""

if (!$vms -or $vms -eq "*")
{
	$vmReportFilter ="*"
	#$params.Add("vms","*")
} else {
	$vmReportFilter+="$([string]$vms -replace '\s',',')"
	#$params.Add("vms",$([string]$vms -replace '\s',','))
}

logThis -msg $global:reportIndex

#Write-Output "" > $global:reportIndex

## Default reports
$capacityReports =  @(
					#(<script name>,<additional_parameters>)
					#("","-title 'Infrastructure' -type h3 -text 'This section provides capacity and usage reports for all reported environments.' "),
					("$scriptsLoc\Infrastructure_Summary.ps1","-headerType 3"),
					("$scriptsLoc\Infrastructure_Summary_Per_Software_Datacenter.ps1","-headerType 3"),
					("$scriptsLoc\VMware_vCenter_Server.ps1","-headerType 3"),
					("$scriptsLoc\VMware_Licences.ps1","-headerType 3"),
					("$scriptsLoc\Hypervisors_Hosts_Short_List.ps1","-headerType 3"),
					("$scriptsLoc\Hypervisors_Hosts_By_Model.ps1","-headerType 3"),
                    ("$scriptsLoc\Hypervisors_Hosts_By_Version.ps1","-headerType 3"),
                    ("$scriptsLoc\Hypervisors_Hosts_By_Manufacturer.ps1","-headerType 3"),
					("$scriptsLoc\Cluster_Details.ps1","-headerType 3"),
					("$scriptsLoc\Network_Standard_Networks.ps1","-headerType 3"),
					("$scriptsLoc\Network_Distributed_VSwitches.ps1","-headerType 3"),
					("$scriptsLoc\Summary_Virtual_Machines.ps1","-headerType 3"),
					("$scriptsLoc\Virtual_Machines_Short_List.ps1","-headerType 3"),
					("$scriptsLoc\Virtual_Machines_By_Operating_System_Types.ps1","-headerType 3"),
					("$scriptsLoc\Virtual_Machines_By_CPU.ps1","-headerType 3"),
					("$scriptsLoc\Virtual_Machines_By_Memory.ps1","-headerType 3"),
					("$scriptsLoc\Virtual_Machines_By_Hardware_Version.ps1","-headerType 3"),
					("$scriptsLoc\Virtual_Machines_By_VMware_Tools.ps1","-headerType 3"),
					("$scriptsLoc\Virtual_Machines_Compute_Usage_By_BusinessGroups.ps1","-headerType 3"),
					("$scriptsLoc\Virtual_Machines_List_With_VMware_Tools_Issues.ps1","-headerType 3"),
					("$scriptsLoc\Virtual_Machines_With_Snapshots.ps1","-headerType 3"),	
					("$scriptsLoc\Virtual_Machines_With_Reservations_Or_Limits_Set.ps1","-headerType 3"),
					("$scriptsLoc\Virtual_Machines_With_vSphere_Replication_Configurations.ps1","-headerType 3"),
					("$scriptsLoc\Datastores_Configurations.ps1","-headerType 3")
                    );
$performanceReports = @(
					#(<script name>,<additional_parameters>)					
					("$scriptsLoc\Cluster_Performance.ps1","-showPastMonths $showPastMonths -headerType 3"),
					("$scriptsLoc\Hypervisors_Performance.ps1","-showPastMonths $showPastMonths -headerType 3"),
					("$scriptsLoc\Virtual_Machines_Performance.ps1","-vms $vmReportFilter -showPastMonths $showPastMonths -headerType 3")
					<#,
					("$scriptsLoc\Virtual_Machines_Disk_WritesMBps_Over_Last_7_Days.ps1","-headerType 3"),
					("$scriptsLoc\Virtual_Machines_Disk_ReadsMBps_Over_Last_7_Days.ps1","-headerType 3"),
					("$scriptsLoc\Virtual_Machines_CPU_ReadyPerc_Over_Last_7_Days.ps1","-headerType 3"),
					("$scriptsLoc\Virtual_Machines_CPU_Usage_Over_Last_7_Days.ps1","-headerType 3"),
					("$scriptsLoc\Virtual_Machines_MEM_Usage_Over_Last_7_Days.ps1","-headerType 3")
					#>
					);

#  Working progress scripts - they currently take a long time because they were not enhanced with sharing of Objects between scripts.
$extendedReports =  @(
					#(<script name>,<additional_parameters>)
					#("$scriptsLoc\Summary_Physical_Datacenters.ps1"),
					#("$scriptsLoc\Storage_Arrays.ps1"),
					("$scriptsLoc\Infrastructure_Compute_Summary.ps1"),										
					("$scriptsLoc\Datacenter_Permissions_And_Security.ps1"),
					("$scriptsLoc\Hypervisors_Networking.ps1"),
					("$scriptsLoc\Hypervisors_Detailed_Configurations.ps1"),
					("$scriptsLoc\vCenter_Dynamic_Resource_Scheduler_Configurations.ps1"),
					("$scriptsLoc\Resource_Pools_Configurations.ps1"),
                        #Not present("$scriptsLoc\Summary_vSphere_Hypervisors.ps1"),
					("$scriptsLoc\Virtual_Machines_Snapshots_Capacity_Calculator.ps1"),                        
					("$scriptsLoc\Virtual_Machines_Detailed_Configurations.ps1"),
					("$scriptsLoc\Virtual_Machines_Templates.ps1"),
                        #("$scriptsLoc\Virtual_Machines_IO_Statistics.ps1"),
					("$scriptsLoc\Virtual_Machines_Creation_Trends_vCenterEvents.ps1"),
					#("$scriptsLoc\Virtual_Machines_Deployments_Trends.ps1"),
					#("$scriptsLoc\Virtual_Machines_By_Snapshots_Trends.ps1"),					
					("$scriptsLoc\VMware_Inventory_Summary_vSphereHosts.ps1"),
					("$scriptsLoc\Compute_Summary_Per_Datacenter.ps1"),
					("$scriptsLoc\Compute_Summary_Per_Cluster.ps1"),
					("$scriptsLoc\documentCapacityReport-AllDepartments.ps1"),
					#("$scriptsLoc\documentEvents.ps1","","-comment ALL-Last7Days -lastDays 7"),
					#missing ("$scriptsLoc\vSphere_ESXMaintenanceActivity.ps1"),
					#Missing ("$scriptsLoc\Summary_VM_Deployments_Trends.ps1"),
					#needs Fixing("$scriptsLoc\documentVMNetwork.ps1"),
                        #("$scriptsLoc\documentDatastoreLossOfConnectivity.ps1","ALL-last1Day","","1"),
                        #("$scriptsLoc\documentDatastoreLossOfConnectivity.ps1","ALL-last7Days","","7"),
                        #("$scriptsLoc\documentDatastoreLossOfConnectivity.ps1","ALL-last30Days","","30"),
                        #("$scriptsLoc\documentDatastoreLossOfConnectivity.ps1","ALL-last60Days","","60"),
                        #("$scriptsLoc\documentDatastoreLossOfConnectivity.ps1","ALL-last90Days","","90"),
					#("$scriptsLoc\documentEvents.ps1","ALL-Last30Days","","30"),
					("$scriptsLoc\get-local-useraccounts.ps1"),
					("$scriptsLoc\documentUserLogons.ps1"),                        
					("$scriptsLoc\Summary_Storages.ps1")
				);

# Reports for health checks
$issuesReports = @( 
					("$scriptsLoc\Issues_Report_Datastores.ps1","-headerType 3"),
					("$scriptsLoc\Issues_Report_Datastores_NFSOnly.ps1","-headerType 3"),
					("$scriptsLoc\Issues_Report_Clusters.ps1","-headerType 3"),
					("$scriptsLoc\Issues_Report_Datacenters.ps1","-headerType 3")
					);

# only used for testing
#$devReports
$capacityReports2 = @(	
					("$scriptsLoc\Infrastructure_Summary.ps1","-headerType 3"),				
					("$scriptsLoc\Cluster_Performance.ps1","-showPastMonths $showPastMonths -headerType 3")
					); 


########################################################################
#
# MAIN 
#
########################################################################
$global:reportIndexCount=0
$sec=3
if ($srvConnection)
{
	logThis -msg "Connected to $srvConnection" -ForegroundColor $global:colours.Information     	
	$global:results = @{}
	$global:results["Runtime"]=@{}
	$global:results["Runtime"]["StartTime"]=Get-Date
	$global:results["Runtime"]["vCenters"]=$srvConnection
	$global:results["Runtime"]["outpuToXML"]=$outpuToXML
	$global:results["Runtime"]["outpuToCSV"]=$outpuToCSV
	$global:results["Runtime"]["outpuToHTML"]=$outpuToHTML
	$global:results["Runtime"]["returnResultsOnly"]=$returnResultsOnlys	
	$global:results["Runtime"]["Index"]=@{}
	$global:results["Reports"]=@{}
	if ($runCapacityReports)
	{
		executeReports -type "Capacity" -collection $capacityReports
		

		if (!$runJobsSequentially)
		{
			$global:jobs | select Name,State,Command | Export-Csv "$logDir\job-list.csv" -NoTypeInformation
			while ($global:jobs.Count -gt 0) { # Problem here as some "done jobs" are not getting captured.
				#clear
				logThis -msg "Checking for Job progress (every $sec seconds):"
				$global:jobs | Select Name,State
				collectJobs
				Start-Sleep -Seconds $sec
			}
		}
		#$global:jobs | Remove-Job
	}
	if ($runPerformanceReports)
	{		
		executeReports -type "Performance" -collection $performanceReports
	}
	if ($runExtendedReports)
	{	
		executeReports -type "Extended" -collection $extendedReports
	} 
	if ($runDevReports)
	{
		executeReports -type "Development" -collection $devReports
	}
	if ($runIssuesReports)
	{
		executeReports -type "Issues" -collection $issuesReports
	}
	if ($disconnectOnExit)
	{
		Disconnect-VIServer $srvConnection -Confirm:$false;
		logThis -msg "Disconnected from $srvConnection.Name " -ForegroundColor $global:colours.Information
	}
	$global:results["Runtime"]["EndTime"] = Get-Date
	if ($global:results -and $outpuToXML)
	{
		# blah
	} elseif ($global:results -and $outpuToCSV)
	{
		# blah
	} elseif ($global:results -and $outpuToHTML)
	{
		# blah
	} elseif ($global:results -and $returnResultsOnly)
	{	
		# Append MyFileAdd2.txt to exiting Zip file Text.zip
		return $global:results
	}
} else { 
	logThis -msg "Could not connect to virtual infrastructure. Check the connetion settings and try again";
	exit;
}