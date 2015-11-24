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
$script=$MyInvocation.MyCommand.Path
$scriptsLoc=$(Split-Path $script)
#Set-Variable -Scope Global -Name silent -Value $silent
Import-Module ".\generic\genericModule.psm1" -Force

function readConfiguration ([Parameter(Mandatory=$true)][string]$inifile)
{
	logThis -msg "Reading in configurations from file $inifile"
	$configurations = @{}
	Get-Content $inifile | Foreach-Object{
		if ($_ -notlike "#*")
		{
			$var = $_.Split('=')
			#logThis -msg $var
			#Write-Host $var[0]
			if ($var.Count -gt 1)
			{
				$name=$var[0]
				#Write-Host "$($var[0]) $($var[1])"
				if ($var[1] -eq "true")
				{
					#$configurations.Add($var[0],$true)
					$value=$true
					#New-Variable -Name $var[0] -Value $true
				} elseif ($var[1] -eq "false")
				{
					#$configurations.Add($var[0],$false)
					$value=$false
					#New-Variable -Name $var[0] -Value $false
				} else {
					if ($var[1] -match ',')
					{
						$value = $var[1] -split ','
						#New-Variable -Name $var[0] -Value ($var[1] -split ',')
					} else {
						$value = $var[1]
						#New-Variable -Name $var[0] -Value $var[1]
					}
				}
				$configurations.Add($name,$value)
			}
		}
	}
	
	if ($configurations)
	{
		# Perform post processing by replace all strings with  $ sign in them with the content of their respective Content.
		# for example: replaceing $customer with the actual customer name specified by the key $configurations.customer
		$postProcessConfigs = @{}
		$configurations.Keys | %{
			$keyname=$_
			#Write-Host $keyname
			# just in case the value is an array, process each
			$updatedValue=""
			$updatedField = $configurations.$keyname | %{
				$curr_string = $_				
				if ($curr_string -match '$')
				{
					# replace the string with a $ sign in it with the content of the variable it is expected
					$newstring=""
					$newstring_array = $curr_string -split ' ' | %{
						$word = $_
						#Write-Host "`tBefore $word"
						if ($word -like '*$*')
						{
							$key=$word -replace '\$'
							$configurations.$key							
						} elseif ($word -eq "True") {
							$true
						} elseif ($word -eq "False") {
							$false
						} else {
							$word
						}
					}
					$updatedValue = [string]$newstring_array
				} else {
					$updatedValue = $curr_string
				}
				$updatedValue
			}
			$postProcessConfigs.Add($keyname,$updatedField)
		}
		$postProcessConfigs.Add("inifile",$inifile)
		#return $configurations,$postProcessConfigs
		return $postProcessConfigs
	} else {
		return $null
	}
}

function startProcess()
{	
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
	#$logDir="$($global:configs.scriptsLoc)\$($global:configs.vmwareScriptsHomeDir)\output\TEMP\$runtimeDate" # Where you want the final HTML reports to exist
	$defaultOutputReportDirectory="$($global:configs.scriptsLoc)\$($global:configs.customer -replace ' ','_')" # Where you want the final HTML reports to exist
	#$runtimeDate="23-03-2015" # Uncomment this line if you are generating reports from a previous audit with overwriteRuntimeDate as the date "Day-Month-Year"
	if (!$global:configs.outputDirectory)
	{
		# keeping this around whilst I am resolving the cross-script issue wth this variable changing un-predictably
		$global:logDir = "$defaultOutputReportDirectory\$runtimeDate"
		#$logDir="$defaultOutputReportDirectory\$runtimeDate"
		#$outputDirectory="$defaultOutputReportDirectory\$runtimeDate"
		$global:configs.Add("runtime_log_directory","$($global:configs.outputDirectory)\$runtimeDate")
	} else {
		# keeping this around whilst I am resolving the cross-script issue wth this variable changing un-predictably
		$global:logDir="$($global:configs.outputDirectory)\$runtimeDate"
		#$logDir = "$($global:configs.outputDirectory)\$runtimeDate" 
		#$outputDirectory="$($global:configs.outputDirectory)\$runtimeDate" 
		$global:configs.Add("runtime_log_directory","$($global:configs.outputDirectory)\$runtimeDate")
	}
	if ((Test-Path -path $global:configs.runtime_log_directory) -ne $true) {
		New-Item -type directory -Path $global:configs.runtime_log_directory
		#$childitem = Get-Item -Path $global:configs.runtime_log_directory
		#$global:configs.runtime_log_directory = $childitem.FullName
	}
	$logfile="$($global:configs.runtime_log_directory)\documentCustomer.log"
	

	if (!$global:configs.Silent)
	{
		Invoke-Item $global:configs.runtime_log_directory
	}

	if (Test-Path $logfile)
	{
		Remove-Item $logFile
	}	
	
	#InitialiseGenericModule -parentScriptName -logDir $runtime_log_directory

	###########################################################################
	#
	# VMWARE REPORTING :- 
	#
	###########################################################################
	if ($global:configs.collectVMwareReports)
	{
		
		$vcCredentialsFileDirectory = Split-Path $global:configs.vcCredentialsFile
		if (!$vcCredentialsFileDirectory)
		{
			$global:configs.vcCredentialsFile="$(Split-Path $inifile)\$($global:configs.vcCredentialsFile)"
		}
		
		try 
		{	
			$filepath=$global:configs.vcCredentialsFile | Resolve-Path -ErrorAction Stop
			
			$passwordFile = "$($($filepath).Path)"	
			#$passwordFile
			#pause
		} Catch {		
			#$ErrorMessage = $_.Exception.Message
	    		#$FailedItem = $_.Exception.ItemName
			#showError -msg $ErrorMessage
			$global:configs.vcCredentialsFile
			#pause
			set-mycredentials -Filename $global:configs.vcCredentialsFile
			$passwordFile = $global:configs.vcCredentialsFile
			#break
		}	

		Set-Location "$($global:configs.scriptsLoc)\$($global:configs.vmwareScriptsHomeDir)"
		
		if (!$srvconnection)
		{
			logThis -msg ">>>>" -ForegroundColor Yellow
			logThis -msg "$($global:configs.vCenterServers)"
			logThis -msg ">>>>" -ForegroundColor Yellow
			#$credentials = & "$($global:configs.scriptsLoc)\$($global:configs.vmwareScriptsHomeDir)\get-mycredentials-fromFile.ps1" -User $vcUser -SecureFileLocation  $passwordFile
			$credentials = getmycredentialsfromFile -User $global:configs.vcUser -SecureFileLocation $passwordFile
			$global:configs.vCenterServers=$global:configs.vCenterServers -split ','
			$srvconnection= Connect-VIServer -Server @($global:configs.vCenterServers) -Credential $credentials
			
		}
		Import-Module -Name "$($global:configs.scriptsLoc)\$($global:configs.vmwareScriptsHomeDir)\vmwareModules.psm1" -Force
		#Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
		
		InitialiseModule -logDir $global:configs.runtime_log_directory -parentScriptName $($MyInvocation.MyCommand.name)
		
		logThis -msg "Collecting VMware Reports ($runtime_log_directory)" -logfile $logfile 
		#$($global:configs.scriptsLoc)\$($global:configs.vmwareScriptsHomeDir)="C:\admin\scripts\vmware" # requires interacting with VMware vCenter server
		if ($srvconnection)
		{
			###########################################################################
			#
			# REPORT 1 :- The main collector - simplified for reporting
			#
			###########################################################################
			if ($global:configs.capacity)
			{
				$thisReportLogdir="$($global:configs.runtime_log_directory)\Capacity_Reports" # Where all the CSVs are output by collectAll
				$reportHeader="VMware Infrastructure Capacity Reports for $($global:configs.customer)"
				$reportIntro="The objective of this document is to provide $($global:configs.customer) with information about its VMware Infrastructure(s). The report was prepared by $itoContactName and generated on $(get-date). A total of $($srvconnection.count) x vCenter Servers were audited for this report."
				if (!$reportOnly)
				{
					logThis -msg "`t-> Collecting capacity information to location: $thisReportLogdir" -logfile $logfile 
					if ($scriptParams) {remove-variable scriptParams}
					$scriptParams = @{
						'logProgressHere'=$logfile;
						'srvconnection'=$srvconnection;
						'logDir'=$thisReportLogdir;
						'runCapacityReports' = [bool]$global:configs.capacity;
						'runPerformanceReports' = $false;
						'runExtendedReports' = [bool]$global:configs.runExtendedVMwareReports;
						'vms' = [bool]$global:configs.vmsToCheckPerformance;
						'showPastMonths' = [int]$global:configs.previousMonths;
						'runJobsSequentially' = [bool]$global:configs.runJobsSequentially
					}
					
					& "$($global:configs.scriptsLoc)\$($global:configs.vmwareScriptsHomeDir)\collectAll.ps1" @scriptParams
					#& "$($global:configs.scriptsLoc)\$($global:configs.vmwareScriptsHomeDir)\collectAll.ps1" -logProgressHere $logfile -srvConnection $srvconnection -logDir $thisReportLogdir -runCapacityReports $true -runPerformanceReports $false -runExtendedReports $runExtendedVMwareReports -vms $vmsToCheckPerformance -showPastMonths $previousMonths
					
				} else {
					# work in progress.. read from on disk report already.
					$htmlReport = "No report"
				}
				
				
				if(!$global:configs.stopReportGenerator)
				{
					logThis -msg "`t-> Generating Capacity Report from input directory $thisReportLogdir to output directory $runtime_log_directory" -logfile $logfile 
					if ($scriptParams) {remove-variable scriptParams}
					$scriptParams = @{
						'inDir' = $thisReportLogdir;
						'logDir' = $global:configs.outputDirectory;
						'reportHeader' = $global:configs.reportHeader;
						'reportIntro' = $global:configs.reportIntro;
						'farmName' = $global:configs.customer;
						'openReportOnCompletion'= [bool]$global:configs.openReportOnCompletion;
						'createHTMLFile' = [bool]$global:configs.createHTMLFile;
						'emailReport' = [bool]$global:configs.emailReport;
						'verbose' = $false;
						'itoContactName' = $global:configs.itoContactName;
					}
					#$thisReportLogdir
					#pause
					$htmlReport = & "$($global:configs.scriptsLoc)\$($global:configs.vmwareScriptsHomeDir)\generateInfrastructureReports.ps1" -inDir $thisReportLogdir -logDir $global:configs.outputDirectory -reportHeader $reportHeader -reportIntro $reportIntro -farmName $customer -openReportOnCompletion  $openReportOnCompletion -createHTMLFile $global:configs.createHTMLFile -emailReport $global:configs.emailReport -verbose $false -itoContactName $itoContactName
					# its not working for some reason
					#& "$($global:configs.scriptsLoc)\$($global:configs.vmwareScriptsHomeDir)\generateInfrastructureReports.ps1" @scriptParams
				}
				
				if ($global:configs.emailReport)
				{
					if ($scriptParams) {remove-variable scriptParams}
		
					$scriptParams = @{
						'inDir' = $thisReportLogdir;
						'logDir' = $global:configs.outputDirectory;
						'reportHeader' = $global:configs.reportHeader;
						'reportIntro' = $global:configs.reportIntro;
						'farmName' = $global:configs.customer;
						'setTableStyle' = 'aITTablesytle';
						'itoContactName' = $global:configs.itoContactName;						
						'openReportOnCompletion' = [bool]$global:configs.openReportOnCompletion;
						'createHTMLFile' = [bool]$global:configs.createHTMLFile;
						'emailReport' = [bool]$global:configs.emailReport;
						'verbose' = [bool]$false;
					}
					
					$htmlReportFilename = & "$($global:configs.scriptsLoc)\$($global:configs.vmwareScriptsHomeDir)\generateInfrastructureReports.ps1" -inDir $thisReportLogdir -logDir $global:configs.outputDirectory -reportHeader $reportHeader -reportIntro $reportIntro -farmName $customer -openReportOnCompletion $global:configs.openReportOnCompletion -createHTMLFile $global:configs.createHTMLFile -emailReport $global:configs.emailReport -verbose $false -itoContactName $itoContactName
					
					if ($scriptParams) {remove-variable scriptParams}
					$scriptParams = @{ 
						'subject' = $global:configs.subject;
						'smtpServer' = $global:configs.smtpServer;
						'smtpDomainFQDN' = $global:configs.smtpDomainFQDN;
						'replyToRecipients' = $global:configs.replyToRecipients;
						'fromRecipients' = $global:configs.fromRecipients;
						'fromContactName'=Reporting Services
						'toRecipients' = $global:configs.toRecipients;
						'body' = (get-content $htmlReportFilename);
						'attachements' = $null
					}
					
					
					# This routine sends the email
					#function emailContact ([string] $smtpServer,  [string] $from, [string] $replyTo, [string] $toAddress ,[string] $subject, [string] $htmlPage) {
					sendEmail @scriptParams
					
					# its not working for some reason
					#& "$($global:configs.scriptsLoc)\$($global:configs.vmwareScriptsHomeDir)\generateInfrastructureReports.ps1" @scriptParams
				} 
				
			}
			
			###########################################################################
			#
			# REPORT 2 :- Some kind of HealthCheck on Each VM (Performances, Configurations etc..) lovely
			#
			###########################################################################
			if ($global:configs.perfChecks)
			{
				$thisReportLogdir="$($global:configs.runtime_log_directory)\Performance_Reports" # Where all the CSVs are output by collectAll
				$reportHeader="Performance Reports"
				$reportIntro="Find below a list of comprehensive capacity report produced by $itoContactName for $customer. $($srvconnection.count) VMware Infrastructure(s) have been audited as part of this report."	
				if (!$global:configs.$reportOnly)
				{	
					if ($scriptParams) {remove-variable scriptParams}
					$scriptParams = @{
						'logProgressHere' = $logfile;
						'srvConnection' = $srvconnection;
						'logDir' = $thisReportLogdir;
						'runCapacityReports' = $false;
						'runPerformanceReports' = $true;
						'runExtendedReports' = $false;
						'vms' = [bool]$global:configs.vmsToCheckPerformance;
						'showPastMonths' = [int]$global:configs.previousMonths;
						'runJobsSequentially' = [bool]$global:configs.runJobsSequentially
					}
					logThis -msg "`t-> Collecting Performance information to location: $thisReportLogdir" -logfile $logfile 
					& "$($global:configs.scriptsLoc)\$($global:configs.vmwareScriptsHomeDir)\collectAll.ps1" @scriptParams 
				}
				
				logThis -msg "`t-> Generating Performance Checks Report" -logfile $logfile 
				if ($global:configs.emailReport)				
				{
					if ($scriptParams) {remove-variable scriptParams}
					$scriptParams = @{
						'inDir' = $thisReportLogdir;
						'logDir' = $global:configs.outputDirectory;
						'reportHeader' = $global:configs.reportHeader;
						'reportIntro' = $global:configs.reportIntro;
						'farmName' = $global:configs.customer;
						'openReportOnCompletion' = [bool]$global:configs.openReportOnCompletion;
						'createHTMLFile' = [bool]$global:configs.createHTMLFile;
						'emailReport' = [bool]$global:configs.emailReport;
						'verbose' = $false;
						'itoContactName' = $global:configs.itoContactName;
					}
					#& "$($global:configs.scriptsLoc)\$($global:configs.vmwareScriptsHomeDir)\generateInfrastructureReports.ps1" -inDir $thisReportLogdir -logDir $global:configs.outputDirectory -reportHeader $reportHeader -reportIntro $reportIntro -farmName $customer -openReportOnCompletion $openReportOnCompletion -createHTMLFile $global:configs.createHTMLFile -emailReport $true -verbose $false -itoContactName $itoContactName
					& "$($global:configs.scriptsLoc)\$($global:configs.vmwareScriptsHomeDir)\generateInfrastructureReports.ps1" @scriptParams
				} 
				if(!$global:configs.stopReportGenerator)
				{
					if ($scriptParams) {remove-variable scriptParams}
					$scriptParams = @{
						'inDir' = $thisReportLogdir;
						'logDir' = $global:configs.outputDirectory;
						'reportHeader' = $global:configs.reportHeader;
						'reportIntro' = $global:configs.reportIntro;
						'farmName' = $global:configs.customer;
						'openReportOnCompletion' = [bool]$global:configs.openReportOnCompletion;
						'createHTMLFile' = [bool]$global:configs.createHTMLFile;
						'emailReport' = [bool]$global:configs.emailReport;
						'verbose' = $false;
						'itoContactName' = $global:configs.itoContactName;
					}
					#& "$($global:configs.scriptsLoc)\$($global:configs.vmwareScriptsHomeDir)\generateInfrastructureReports.ps1" -inDir $thisReportLogdir -logDir $global:configs.outputDirectory -reportHeader $reportHeader -reportIntro $reportIntro -farmName $customer -openReportOnCompletion  $openReportOnCompletion -createHTMLFile $global:configs.createHTMLFile -emailReport $global:configs.emailReport -verbose $false -itoContactName $itoContactName
					& "$($global:configs.scriptsLoc)\$($global:configs.vmwareScriptsHomeDir)\generateInfrastructureReports.ps1" @scriptParams
				}
			}


			###########################################################################
			#
			# REPORT 3 :- Perform an Infrastructure Wide Health Check (Performances, Configurations etc..) lovely
			#
			###########################################################################

			if ($global:configs.healthCheck -and !$global:configs.reportOnly)
			{
				$thisReportLogdir="$($global:configs.runtime_log_directory)\Issues_Report" # Where all the CSVs are output by collectAll
				$reportHeader="Health Check & Issues Report"
				$reportIntro="This report forms a Health Check report for $customer’s VMware infrastructure(s). $($srvconnection.count) VMware Infrastructure(s) have been audited as part of this report."
				
				& "$($global:configs.scriptsLoc)\$($global:configs.vmwareScriptsHomeDir)\Issues_Report.ps1" -srvConnection $srvconnection -logDir $thisReportLogdir -saveReportToDirectory $global:configs.outputDirectory -reportHeader $reportHeader -reportIntro $reportIntro -headerType 2 -ensureTheseFieldsAreFieldIn $ensureTheseFieldsAreFieldIn -performanceLastDays 7 -showPastMonths $previousMonths -vmsToCheck $vmsToCheckHealthCheck -excludeThinDisks $global:configs.excludeThinDisks
				
				if(!$global:configs.stopReportGenerator)
				{
					if ($scriptParams) {remove-variable scriptParams}
					$scriptParams = @{
						'inDir' = $thisReportLogdir;
						'logDir' = $global:configs.outputDirectory;
						'reportHeader' = $global:configs.reportHeader;
						'reportIntro' = $global:configs.reportIntro;
						'farmName' = $global:configs.customer;
						'openReportOnCompletion' = [bool]$global:configs.openReportOnCompletion;
						'createHTMLFile' = [bool]$global:configs.createHTMLFile;
						'emailReport' = [bool]$global:configs.emailReport;
						'verbose' = $false;
						'itoContactName' = $global:configs.itoContactName;
					}
					#& "$($global:configs.scriptsLoc)\$($global:configs.vmwareScriptsHomeDir)\generateInfrastructureReports.ps1" -inDir $thisReportLogdir -logDir $global:configs.outputDirectory -reportHeader $reportHeader -reportIntro $reportIntro -farmName $customer -openReportOnCompletion  $openReportOnCompletion -createHTMLFile $global:configs.createHTMLFile -emailReport $global:configs.emailReport -verbose $false -itoContactName $itoContactName
					& "$($global:configs.scriptsLoc)\$($global:configs.vmwareScriptsHomeDir)\generateInfrastructureReports.ps1"  @scriptParams
				}
			}
			

			###########################################################################
			#
			# REPORT 4 :- Create a audit of each Virtual Machine - Intensive & Detailed output HealthCheck -- Cool too
			#
			###########################################################################
			if ($global:configs.generatePerVMReport -and !$global:configs.reportOnly)
			{
				$thisReportLogdir="$($global:configs.runtime_log_directory)\VMs_HealthChecks"
				$enable=$true
				# check only VMs specified in vmsToCheck. vmsToCheck is set in the customer INI file (Comma delimited)
				if ($global:configs.vmsToCheckHealthCheck -and $global:configs.vmsToCheckHealthCheck -ne "*")
				{
					logThis -msg "`t-> Generating Individual VM Checks For $([string]$global:configs.vmsToCheckHealthCheck)" -logfile $logfile 
					$global:configs.vmsToCheckHealthCheck -split "," | %{
						& "$($global:configs.scriptsLoc)\$($global:configs.vmwareScriptsHomeDir)\exportVMDetails.ps1" -srvConnection $srvconnection -guestName $_ -includeSectionSysInfo $enable -includeSectionPerfStats $true -includeTasks $enable -includeErrors $enable -includeAlarms $enable -includeVMEvents $enable -includeVMSnapshots $enable -launchBrowser $false -showIndividualDevicesStats $false -logDir $thisReportLogdir -showPastMonths $global:configs.previousMonths
					}
				} else {
					logThis -msg "`t-> Generating VM Checks for ALL VMs" -logfile $logfile 
					#Get-VM * -Server $srvconnection | %{ 
						& "$($global:configs.scriptsLoc)\$($global:configs.vmwareScriptsHomeDir)\exportVMDetails.ps1" -srvConnection $srvconnection -includeSectionSysInfo $enable -includeSectionPerfStats $true -includeTasks $enable -includeErrors $enable -includeAlarms $enable -includeVMEvents $enable -includeVMSnapshots $enable -launchBrowser $false -showIndividualDevicesStats $false -logDir $thisReportLogdir -showPastMonths $previousMonths
					#}
				}
			}
		}  else {
			logThis -msg ">>" -ForegroundColor Red  -logfile $logfile 
			logThis -msg ">> Unable to connect to vCenter Server(s) ""$($global:configs.vCenterServers)""."  -ForegroundColor Red  -logfile $logfile 
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
	Set-Location $($global:configs.scriptsLoc)	
	# NOT WORKING!!!
	if ($global:configs.collectSANReports)
	{
		$passwordFile = "$($($global:configs.sanV7000SecurePasswordFile | Resolve-Path).Path)"
		logThis -msg "Collecting SAN Reports"  -logfile $logfile 
		###########################################################################
		#
		# REPORT 1 :- IBM V7000 ARRAYS
		#
		###########################################################################
		
		if ($global:configs.sanV7000collectReports)
		{
			$reportHeader="Storage Health Check"
			$reportIntro="This report was prepared by $itoContactName for $($global:configs.customer) as a review of its Storage Systems."	
			$thisReportLogdir="$($global:configs.runtime_log_directory)\Storage"
	        
	        if ($global:configs.sanV7000User -and $global:configs.sanV7000SecurePasswordFile -and !$global:configs.sanV700password)
	        {
	            #$credentials = & "$($global:configs.scriptsLoc)\$sanV7000scriptsHomeDir\get-mycredentials-fromFile.ps1" -User $sanV7000User -SecureFileLocation $passwordFile
			  $credentials = get-mycredentials-fromFile -User $global:configs.sanV7000User -SecureFileLocation $passwordFile
	            #$credentials
	            #pause
	        }
			if ($global:configs.sanV7000User -and $global:configs.sanV700password -and $global:configs.sanV7000ArraysIPs)
			{    
				$credentials = Get-Credential -UserName  $global:configs.sanV7000User -Message "Please specify a password for user account ""$($global:configs.sanV7000User)"" to use to authenticate against arrays [string]$($global:configs.sanV700ArraysIPs)"
	            #$deviceList = (($sanV7000ArraysIPs -split ',' -replace '^','"') -replace '$','"') -join ','
	            $deviceList = $global:configs.sanV7000ArraysIPs -split ','
	            #$deviceList
	            #pause
	            & "$($global:configs.scriptsLoc)\$($global:configs.sanV7000scriptsHomeDir)\ibmstorwize-checks.ps1" -logDir $thisReportLogdir -username $global:configs.sanV7000User -cpassword $sanV700password -arrayOfTargetDevices $deviceList

			}


	        if(!$stopReportGenerator)
			{
				& "$($global:configs.scriptsLoc)\$($global:configs.vmwareScriptsHomeDir)\generateInfrastructureReports.ps1" -inDir $thisReportLogdir -logDir $global:configs.outputDirectory -reportHeader $global:configs.reportHeader -reportIntro $global:configs.reportIntro -farmName $global:configs.customer -openReportOnCompletion  $global:configs.openReportOnCompletion -createHTMLFile $global:configs.createHTMLFile -emailReport $global:configs.emailReport -verbose $false -itoContactName $global:configs.itoContactName
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
			$sanIOSscriptsHomeDir="$($global:configs.scriptsLoc)\$($global:configs.brocadeIOSscriptsHomeDir)"
		}
	}

	###########################################################################
	#
	# XEN REPORTS :- 
	#
	###########################################################################
	Set-Location $($global:configs.scriptsLoc)	
	if ($global:configs.collectXenReports)
	{
		logThis -msg "Collecting XEN Reports"
		$xenScriptsHomeDir="$($global:configs.scriptsLoc)\$($global:configs.xenscriptsHomeDir)" # requires interacting with master server
	}

	###########################################################################
	#
	# HYPERV-V REPORTS :- 
	#
	###########################################################################
	Set-Location $($global:configs.scriptsLoc)	
	if ($global:configs.collectHYPERVReports)
	{
		logThis -msg "Collecting Hyper-V Reports"  -logfile $logfile 
		$hypervScriptsHomeDir="$($global:configs.scriptsLoc)\$($global:configs.hyperVscriptsHomeDir)" # requires interacting with master server
	}

	###########################################################################
	#
	# WMI REPORTS :- 
	#
	###########################################################################
	Set-Location $($global:configs.scriptsLoc)	
	if ($global:configs.collectWMIReports)
	{
		logThis -msg "Collecting Windows WMI Reports"  -logfile $logfile 
		$wmiScriptsHomeDir="$($global:configs.scriptsLoc)\$($global:configs.wmiScriptsHomeDir)" # requires interacting with Windows via network 
	}

	###########################################################################
	#
	# Linux Servers REPORTS :- 
	#
	###########################################################################
	Set-Location $($global:configs.scriptsLoc)	
	if ($global:configs.collectLinuxReports)
	{
		logThis -msg "Collecting Linux Systems Reports"  -logfile $logfile 
		$wmiScriptsHomeDir="$($global:configs.scriptsLoc)\$($global:configs.linuxScriptsHomeDir)" # requires interacting with Windows via network 
	}

	# Set the location back to the original directory
	Set-Location $($global:configs.scriptsLoc)
}

# MAIN
if ($configObj) {Remove-Variable configObj -Scope All }
if ($global:configs) {Remove-Variable configs -Scope Global }
$configObj = readConfiguration -inifile $inifile
if ($configObj)
{	
	#$configObj
	#pause
	$configObj.Add("Silent",$silent)
	$configObj.Add("scriptsLoc",$scriptsLoc)
	$global:configs = $configObj	
	startProcess	
} else {
	Write-Host "Invalid Configurations"
}