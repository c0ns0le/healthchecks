<#

.SYNOPSIS

Reads in a customer specific parameters from a given INI file.


.DESCRIPTION

<blah>

.PARAMETER initFile

a single file (<customer.ini>) which contains a comprehensive list of environmental parameters required for the script.


.EXAMPLE

Read customer settings form the init file. This is how to call the sript for a specific customer.

documentCustomer.ps1 -initFile "C:\admin\scripts\Customer_Settings\customer1.ini"

.NOTES

<coming>

#>
# This report is a collection of many health checks and HTML generating report
# Customise this for each customer and Voila
# Last Modified: 25 March 2015
# Author: teiva.rodiere@gmail.com
param(
	[Parameter(Mandatory=$true)][string]$inifile,
	[bool]$stopReportGenerator=$false,
	[bool]$silent=$false
)
$scriptsLoc=$(Split-Path $($MyInvocation.MyCommand.Path))
Set-Variable -Scope Global -Name silent -Value $silent
# Read in module
Get-Content $inifile | Foreach-Object{
	$var = $_.Split('=')
	#logThis -msg $var
	if ($var[0] -and $var[1] -and !$var[0].Contains("#"))
	{
		if ($var[1] -eq "true")
		{
			New-Variable -Name $var[0] -Value $true
		} elseif ($var[1] -eq "false")
		{
			New-Variable -Name $var[0] -Value $false
		} else {
			if ($var[1] -match ',')
			{
				New-Variable -Name $var[0] -Value ($var[1] -split ',')
			} else {
				New-Variable -Name $var[0] -Value $var[1]
			}
		}
		
	}
	#if ($var[0].Contains("#") -or $var[1].Contains("#"))
	#{
	#	logThis -msg "Found variable with HASH in it $($var[0])" -ForegroundColor Red
	#}
}

#[Parameter(Mandatory=$true)][object]$srvConnection,
#[object]$srvConnection,
###########################################################################
#
# DECLARATIONS :- Modify to suit installation
#
###########################################################################
#$sendAllEmailsTo="Teiva Rodiere <teiva.rodiere@gmail.com>" # Use this to overwrite for testing
# Runtime Variables
# $false to no launch on completion
# $false, should set to false if you are emailing using a cron job or something alike to avoid opening Web Browser
$runtimeDate="$(get-date -f dd-MM-yyyy)" # Get today's date to create the correct directory and file names -- Don't change this if you don't know what you are doing
#$logDir="$scriptsLoc\$vmwareScriptsHomeDir\output\TEMP\$runtimeDate" # Where you want the final HTML reports to exist
$defaultOutputReportDirectory="$(Split-Path $($MyInvocation.MyCommand.Path))\$customer" # Where you want the final HTML reports to exist

#$runtimeDate="23-03-2015" # Uncomment this line if you are generating reports from a previous audit with overwriteRuntimeDate as the date "Day-Month-Year"

############### MAIN ###########
if (!$outputDirectory)
{
	$global:logDir = "$defaultOutputReportDirectory\$runtimeDate"
	$logDir="$defaultOutputReportDirectory\$runtimeDate"
	$outputDirectory="$defaultOutputReportDirectory\$runtimeDate"
} else {
	$global:logDir="$outputDirectory\$runtimeDate"
	$logDir = "$outputDirectory\$runtimeDate" 
	$outputDirectory="$outputDirectory\$runtimeDate" 
}

if ((Test-Path -path $outputDirectory) -ne $true) {
	New-Item -type directory -Path $outputDirectory
	$childitem = Get-Item -Path $outputDirectory
	$outputDirectory = $childitem.FullName
}
$logfile="$outputDirectory\documentCustomer.log"

if (!$global:silent)
{
	#Invoke-Item $outputDirectory
}

if (Test-Path $logfile)
{
	Remove-Item $logFile
}

Import-Module ".\generic\genericModule.psm1" -Force
#InitialiseGenericModule -parentScriptName -logDir $outputDirectory

###########################################################################
#
# VMWARE REPORTING :- 
#
###########################################################################
if ($collectVMwareReports)
{
	$vcCredentialsFileDirectory = Split-Path $vcCredentialsFile
	if (!$vcCredentialsFileDirectory)
	{
		$vcCredentialsFile="$(Split-Path $inifile)\$vcCredentialsFile"		
	}
	
	try 
	{	
		$filepath=$vcCredentialsFile | Resolve-Path -ErrorAction Stop
		
		$passwordFile = "$($($filepath).Path)"	
		#$passwordFile
		#pause
	} Catch {		
		#$ErrorMessage = $_.Exception.Message
    		#$FailedItem = $_.Exception.ItemName
		#showError -msg $ErrorMessage
		$vcCredentialsFile
		pause
		set-mycredentials -Filename $vcCredentialsFile
		$passwordFile = $vcCredentialsFile
		#break
	}	

	Set-Location $scriptsLoc\$vmwareScriptsHomeDir
	
	#logThis -msg $(Split-Path $MyInvocation.MyCommand.Path) -BackgroundColor Red -ForegroundColor White
	if (!$srvconnection)
	{
		logThis -msg ">>>>" -ForegroundColor Yellow
		logThis -msg "$vCenterServers"
		logThis -msg ">>>>" -ForegroundColor Yellow
		#$credentials = & "$scriptsLoc\$vmwareScriptsHomeDir\get-mycredentials-fromFile.ps1" -User $vcUser -SecureFileLocation  $passwordFile
		$credentials = get-mycredentials-fromFile -User $vcUser -SecureFileLocation $passwordFile
		$vCenterServers=$vCenterServers -split ','
		$srvconnection= Connect-VIServer -Server @($vCenterServers) -Credential $credentials
		
	}
	Import-Module -Name "$scriptsLoc\$vmwareScriptsHomeDir\vmwareModules.psm1" -Force
	Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
	
	InitialiseModule -logDir $outputDirectory -parentScriptName $($MyInvocation.MyCommand.name)
	
	logThis -msg "Collecting VMware Reports ($outputDirectory)" -logfile $logfile 
	#$scriptsLoc\$vmwareScriptsHomeDir="C:\admin\scripts\vmware" # requires interacting with VMware vCenter server
	if ($srvconnection)
	{
		###########################################################################
		#
		# REPORT 1 :- The main collector - simplified for reporting
		#
		###########################################################################
		if ($capacity)
		{
			$thisReportLogdir="$logDir\Capacity_Reports" # Where all the CSVs are output by collectAll
			$reportHeader="VMware Infrastructure Capacity Reports for $customer"
			$reportIntro="The objective of this document is to provide $customer with information about its VMware Infrastructure(s). The report was prepared by $itoContactName and generated on $(get-date). A total of $($srvconnection.count) x vCenter Servers were audited for this sreport."			
			if (!$reportOnly)
			{
				logThis -msg "`t-> Collecting capacity information to location: $thisReportLogdir"-logfile $logfile 
				$scriptParams = @{
					'logProgressHere'=$logfile;
					'srvconnection'=$srvconnection;
					'logDir'=$thisReportLogdir;
					'runCapacityReports'=$true;
					'runPerformanceReports'=$false;
					'runExtendedReports'=$runExtendedVMwareReports;
					'vms'=$vmsToCheckPerformance;
					'showPastMonths'=$previousMonths
					'runJobsSequentially'=$runJobsSequentially;
				}
				
				& "$scriptsLoc\$vmwareScriptsHomeDir\collectAll.ps1" @scriptParams
				#& "$scriptsLoc\$vmwareScriptsHomeDir\collectAll.ps1" -logProgressHere $logfile -srvConnection $srvconnection -logDir $thisReportLogdir -runCapacityReports $true -runPerformanceReports $false -runExtendedReports $runExtendedVMwareReports -vms $vmsToCheckPerformance -showPastMonths $previousMonths
				
			}
			
			logThis -msg "`t-> Generating Capacity Report from input directory $thisReportLogdir to output directory $outputDirectory" -logfile $logfile 

			if ($emailReport)
			{
				$scriptParams = @{
					'inDir'=$thisReportLogdir;
					'logDir'=$outputDirectory;
					'reportHeader'=$reportHeader;
					'reportIntro'=$reportIntro;
					'farmName'=$customer;
					'openReportOnCompletion'=$openReportOnCompletion;
					'createHTMLFile'=$true;
					'emailReport'=$true;
					'verbose'=$false;
					'itoContactName'=$itoContactName;
				}
				& "$scriptsLoc\$vmwareScriptsHomeDir\generateInfrastructureReports.ps1" -inDir $thisReportLogdir -logDir $outputDirectory -reportHeader $reportHeader -reportIntro $reportIntro -farmName $customer -openReportOnCompletion $openReportOnCompletion -createHTMLFile $true -emailReport $true -verbose $false -itoContactName $itoContactName
				#& "$scriptsLoc\$vmwareScriptsHomeDir\generateInfrastructureReports.ps1" @scriptParams
			} 
			if(!$stopReportGenerator)
			{
				$scriptParams = @{
					'inDir'="C:\admin\OUTPUT\AIT\19-11-2015";
					'logDir'=$outputDirectory;
					'reportHeader'=$reportHeader;
					'reportIntro'=$reportIntro;
					'farmName'=$customer;
					'openReportOnCompletion'=$openReportOnCompletion;
					'createHTMLFile'=$true;
					'emailReport'=$false;
					'verbose'=$false;
					'itoContactName'=$itoContactName;
				}
				#$thisReportLogdir
				#pause
				& "$scriptsLoc\$vmwareScriptsHomeDir\generateInfrastructureReports.ps1" -inDir $thisReportLogdir -logDir $outputDirectory -reportHeader $reportHeader -reportIntro $reportIntro -farmName $customer -openReportOnCompletion  $openReportOnCompletion -createHTMLFile $true -emailReport $false -verbose $false -itoContactName $itoContactName
				#& "$scriptsLoc\$vmwareScriptsHomeDir\generateInfrastructureReports.ps1" @scriptParams
			}
		}
		
		
		
		###########################################################################
		#
		# REPORT 2 :- Some kind of HealthCheck on Each VM (Performances, Configurations etc..) lovely
		#
		###########################################################################

		if ($perfChecks)
		{
			$thisReportLogdir="$logDir\Performance_Reports" # Where all the CSVs are output by collectAll
			$reportHeader="Performance Reports"
			$reportIntro="Find below a list of comprehensive capacity report produced by $itoContactName for $customer. $($srvconnection.count) VMware Infrastructure(s) have been audited as part of this report."	
			if (!$reportOnly)
			{	
				$scriptParams
				$scriptParams = @{
					'logProgressHere'=$logfile
					'srvConnection'=$srvconnection
					'logDir'=$thisReportLogdir
					'runCapacityReports'=$false
					'runPerformanceReports'=$true
					'runExtendedReports'=$false
					'vms'=$vmsToCheckPerformance
					'showPastMonths'=$previousMonths
					'runJobsSequentially'=$true
				}
				logThis -msg "`t-> Collecting Performance information to location: $thisReportLogdir"	 -logfile $logfile 
				& "$scriptsLoc\$vmwareScriptsHomeDir\collectAll.ps1" @scriptParams 
			}
			
			logThis -msg "`t-> Generating Performance Checks Report" -logfile $logfile 
			if ($emailReport)				
			{
				$scriptParams = @{
					'inDir'=$thisReportLogdir;
					'logDir'=$outputDirectory;
					'reportHeader'=$reportHeader;
					'reportIntro'=$reportIntro;
					'farmName'=$customer;
					'openReportOnCompletion'=$openReportOnCompletion;
					'createHTMLFile'=$true;
					'emailReport'=$true;
					'verbose'=$false;
					'itoContactName'=$itoContactName;
				}
				#& "$scriptsLoc\$vmwareScriptsHomeDir\generateInfrastructureReports.ps1" -inDir $thisReportLogdir -logDir $outputDirectory -reportHeader $reportHeader -reportIntro $reportIntro -farmName $customer -openReportOnCompletion $openReportOnCompletion -createHTMLFile $true -emailReport $true -verbose $false -itoContactName $itoContactName
				& "$scriptsLoc\$vmwareScriptsHomeDir\generateInfrastructureReports.ps1" @scriptParams
			} 
			if(!$stopReportGenerator)
			{
				$scriptParams = @{
					'inDir'=$thisReportLogdir;
					'logDir'=$outputDirectory;
					'reportHeader'=$reportHeader;
					'reportIntro'=$reportIntro;
					'farmName'=$customer;
					'openReportOnCompletion'=$openReportOnCompletion;
					'createHTMLFile'=$true;
					'emailReport'=$false;
					'verbose'=$false;
					'itoContactName'=$itoContactName;
				}
				#& "$scriptsLoc\$vmwareScriptsHomeDir\generateInfrastructureReports.ps1" -inDir $thisReportLogdir -logDir $outputDirectory -reportHeader $reportHeader -reportIntro $reportIntro -farmName $customer -openReportOnCompletion  $openReportOnCompletion -createHTMLFile $true -emailReport $false -verbose $false -itoContactName $itoContactName
				& "$scriptsLoc\$vmwareScriptsHomeDir\generateInfrastructureReports.ps1" @scriptParams
			}
		}


		###########################################################################
		#
		# REPORT 3 :- Perform an Infrastructure Wide Health Check (Performances, Configurations etc..) lovely
		#
		###########################################################################

		if ($healthCheck -and !$reportOnly)
		{
			$thisReportLogdir="$logDir\Issues_Report" # Where all the CSVs are output by collectAll
			$reportHeader="Health Check & Issues Report"
			$reportIntro="This report forms a Health Check report for $customer’s VMware infrastructure(s). $($srvconnection.count) VMware Infrastructure(s) have been audited as part of this report."
			
			& "$scriptsLoc\$vmwareScriptsHomeDir\Issues_Report.ps1" -srvConnection $srvconnection -logDir $thisReportLogdir -saveReportToDirectory $outputDirectory -reportHeader $reportHeader -reportIntro $reportIntro -headerType 2 -ensureTheseFieldsAreFieldIn $ensureTheseFieldsAreFieldIn -performanceLastDays 7 -showPastMonths $previousMonths -vmsToCheck $vmsToCheckHealthCheck -excludeThinDisks $excludeThinDisks
			
			if(!$stopReportGenerator)
			{
				$scriptParams = @{
					'inDir'=$thisReportLogdir;
					'logDir'=$outputDirectory;
					'reportHeader'=$reportHeader;
					'reportIntro'=$reportIntro;
					'farmName'=$customer;
					'openReportOnCompletion'=$openReportOnCompletion;
					'createHTMLFile'=$true;
					'emailReport'=$false;
					'verbose'=$false;
					'itoContactName'=$itoContactName;
				}
				#& "$scriptsLoc\$vmwareScriptsHomeDir\generateInfrastructureReports.ps1" -inDir $thisReportLogdir -logDir $outputDirectory -reportHeader $reportHeader -reportIntro $reportIntro -farmName $customer -openReportOnCompletion  $openReportOnCompletion -createHTMLFile $true -emailReport $false -verbose $false -itoContactName $itoContactName
				& "$scriptsLoc\$vmwareScriptsHomeDir\generateInfrastructureReports.ps1"  @scriptParams
			}
		}
		

		###########################################################################
		#
		# REPORT 4 :- Create a audit of each Virtual Machine - Intensive & Detailed output HealthCheck -- Cool too
		#
		###########################################################################
		if ($generatePerVMReport -and !$reportOnly)
		{
			$thisReportLogdir="$logDir\VMs_HealthChecks"
			$enable=$true
			# check only VMs specified in vmsToCheck. vmsToCheck is set in the customer INI file (Comma delimited)
			if ($vmsToCheckHealthCheck -and $vmsToCheckHealthCheck -ne "*")
			{
				logThis -msg "`t-> Generating Individual VM Checks For $([string]$vmsToCheckHealthCheck)" -logfile $logfile 
				$vmsToCheckHealthCheck -split "," | %{
					& "$scriptsLoc\$vmwareScriptsHomeDir\exportVMDetails.ps1" -srvConnection $srvconnection -guestName $_ -includeSectionSysInfo $enable -includeSectionPerfStats $true -includeTasks $enable -includeErrors $enable -includeAlarms $enable -includeVMEvents $enable -includeVMSnapshots $enable -launchBrowser $false -showIndividualDevicesStats $false -logDir $thisReportLogdir -showPastMonths $previousMonths
				}
			} else {
				logThis -msg "`t-> Generating VM Checks for ALL VMs" -logfile $logfile 
				#Get-VM * -Server $srvconnection | %{ 
					& "$scriptsLoc\$vmwareScriptsHomeDir\exportVMDetails.ps1" -srvConnection $srvconnection -includeSectionSysInfo $enable -includeSectionPerfStats $true -includeTasks $enable -includeErrors $enable -includeAlarms $enable -includeVMEvents $enable -includeVMSnapshots $enable -launchBrowser $false -showIndividualDevicesStats $false -logDir $thisReportLogdir -showPastMonths $previousMonths
				#}
			}
		}
	}  else {
		logThis -msg ">>" -ForegroundColor Red  -logfile $logfile 
		logThis -msg ">> Unable to connect to vCenter Server(s) ""$vCenterServers""."  -ForegroundColor Red  -logfile $logfile 
		logThis -msg ">> Check the address, credentials, and network connectivity"  -ForegroundColor Red  -logfile $logfile 
		logThis -msg ">> between your script and the vCenter server and try again." -ForegroundColor Red  -logfile $logfile 
		logThis -msg ">>" -ForegroundColor Red  -logfile $logfile 
	}
}



###########################################################################
#
# SAN REPORTS :- 
#
###########################################################################
Set-Location $scriptsLoc	
# NOT WORKING!!!
if ($collectSANReports)
{
	$passwordFile = "$($($sanV7000SecurePasswordFile | Resolve-Path).Path)"
	logThis -msg "Collecting SAN Reports"  -logfile $logfile 
	###########################################################################
	#
	# REPORT 1 :- IBM V7000 ARRAYS
	#
	###########################################################################
	
	if ($sanV7000collectReports)
	{
		$reportHeader="Storage Health Check"
		$reportIntro="This report was prepared by $itoContactName for $customer as a review of its Storage Systems."	
		$thisReportLogdir="$logDir\Storage"
        
        if ($sanV7000User -and $sanV7000SecurePasswordFile -and !$sanV700password)
        {
            #$credentials = & "$scriptsLoc\$sanV7000scriptsHomeDir\get-mycredentials-fromFile.ps1" -User $sanV7000User -SecureFileLocation $passwordFile
		  $credentials = get-mycredentials-fromFile -User $sanV7000User -SecureFileLocation $passwordFile
            #$credentials
            #pause
        }
		if ($sanV7000User -and $sanV700password -and $sanV7000ArraysIPs)
		{    
			$credentials = Get-Credential -UserName  $sanV7000User -Message "Please specify a password for user account ""$sanV7000User"" to use to authenticate against arrays [string]$sanV700ArraysIPs"
            #$deviceList = (($sanV7000ArraysIPs -split ',' -replace '^','"') -replace '$','"') -join ','
            $deviceList = $sanV7000ArraysIPs -split ','
            #$deviceList
            #pause
            & "$scriptsLoc\$sanV7000scriptsHomeDir\ibmstorwize-checks.ps1" -logDir $thisReportLogdir -username $sanV7000User -cpassword $sanV700password -arrayOfTargetDevices $deviceList

		}


        if(!$stopReportGenerator)
		{
			& "$scriptsLoc\$vmwareScriptsHomeDir\generateInfrastructureReports.ps1" -inDir $thisReportLogdir -logDir $outputDirectory -reportHeader $reportHeader -reportIntro $reportIntro -farmName $customer -openReportOnCompletion  $openReportOnCompletion -createHTMLFile $true -emailReport $false -verbose $false -itoContactName $itoContactName
		}

	}

	###########################################################################
	#
	# REPORT 2 :- BROCADE SAN Fibre Switches IOS
	#
	###########################################################################
	$collectSanIosFibreSwitches = $true
	if ($collectSanIosFibreSwitches)
	{
		$sanIOSscriptsHomeDir="$scriptsLoc\$brocadeIOSscriptsHomeDir"
	}
}

###########################################################################
#
# XEN REPORTS :- 
#
###########################################################################
Set-Location $scriptsLoc	
if ($collectXenReports)
{
	logThis -msg "Collecting XEN Reports"
	$xenScriptsHomeDir="$scriptsLoc\$xenscriptsHomeDir" # requires interacting with master server
}

###########################################################################
#
# HYPERV-V REPORTS :- 
#
###########################################################################
Set-Location $scriptsLoc	
if ($collectHYPERVReports)
{
	logThis -msg "Collecting Hyper-V Reports"  -logfile $logfile 
	$hypervScriptsHomeDir="$scriptsLoc\$hyperVscriptsHomeDir" # requires interacting with master server
}

###########################################################################
#
# WMI REPORTS :- 
#
###########################################################################
Set-Location $scriptsLoc	
if ($collectWMIReports)
{
	logThis -msg "Collecting Windows WMI Reports"  -logfile $logfile 
	$wmiScriptsHomeDir="$scriptsLoc\$wmiScriptsHomeDir" # requires interacting with Windows via network 
}

###########################################################################
#
# Linux Servers REPORTS :- 
#
###########################################################################
Set-Location $scriptsLoc	
if ($collectLinuxReports)
{
	logThis -msg "Collecting Linux Systems Reports"  -logfile $logfile 
	$wmiScriptsHomeDir="$scriptsLoc\$linuxScriptsHomeDir" # requires interacting with Windows via network 
}

# Set the location back to the original directory
Set-Location $scriptsLoc