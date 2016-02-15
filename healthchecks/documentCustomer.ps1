<#
.SYNOPSIS
TO BE ADVISED. Reads in a customer specific parameters from a given INI file.
teiva.rodiere at gmail.com
.DESCRIPTION
<blah>

.PARAMETER initFile
a single file (<customer.ini>) which contains a comprehensive list of environmental parameters required for the script.

.EXAMPLE
Read customer settings form the init file. This is how to call the sript for a specific customer.

documentCustomer.ps1 -initFile "Customer_Settings\default.ini"

.NOTES
<coming>
#>
# This report is a collection of many health checks and HTML generating report
# Customise this for each customer and Voila
# Last Modified: 25 March 2015
# Author: teiva.rodiere-at-gmail.com
param(
	[Parameter(Mandatory=$false)][string]$inifile,
	[Parameter(Mandatory=$false)][string]$xmlFile,
	[bool]$stopReportGenerator=$false,
	[bool]$silent=$false	
)

$script=$MyInvocation.MyCommand.Path
$global:scriptName = Split-Path $MyInvocation.MyCommand.Path -Leaf
$scriptsLoc=$(Split-Path $script)

# Clear srvconnection if it already exists
if ($srvconnection -or $global:srvconnection)
{
	Remove-Variable srvconnection -Scope Global
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
	#$sendAllEmailsTo="Teiva Rodiere <teiva.rodiere-at-gmail.com>" # Use this to overwrite for testing
	# Runtime Variables
	# $false to no launch on completion
	# $false, should set to false if you are emailing using a cron job or something alike to avoid opening Web Browser
	$runtimeDate="$(get-date -f dd-MM-yyyy)" # Get today's date to create the correct directory and file names -- Don't change this if you don't know what you are doing
	
	
	#$logDir="$($global:report.Runtime.Configs.scriptsLoc)\$($global:report.Runtime.Configs.vmwareScriptsHomeDir)\output\TEMP\$runtimeDate" # Where you want the final HTML reports to exist
	$defaultOutputReportDirectory="$($global:report.Runtime.Configs.scriptsLoc)\$($global:report.Runtime.Configs.customer -replace ' ','_')" # Where you want the final HTML reports to exist
	#$runtimeDate="23-03-2015" # Uncomment this line if you are generating reports from a previous audit with overwriteRuntimeDate as the date "Day-Month-Year"
	if (!$global:report.Runtime.Configs.outputDirectory)
	{
		# keeping this around whilst I am resolving the cross-script issue wth this variable changing un-predictably
		$global:logDir = "$defaultOutputReportDirectory\$runtimeDate"
		#$logDir="$defaultOutputReportDirectory\$runtimeDate"
		#$outputDirectory="$defaultOutputReportDirectory\$runtimeDate"
		$global:report.Runtime.Configs.Add("runtime_log_directory","$($global:report.Runtime.Configs.outputDirectory)\$runtimeDate")		
	} else {
		# keeping this around whilst I am resolving the cross-script issue wth this variable changing un-predictably
		$global:logDir="$($global:report.Runtime.Configs.outputDirectory)\$runtimeDate"
		#$logDir = "$($global:report.Runtime.Configs.outputDirectory)\$runtimeDate" 
		#$outputDirectory="$($global:report.Runtime.Configs.outputDirectory)\$runtimeDate" 
		$global:report.Runtime.Configs.Add("runtime_log_directory","$($global:report.Runtime.Configs.outputDirectory)\$runtimeDate")
		
	}	

	if ((Test-Path -path $global:report.Runtime.Configs.runtime_log_directory) -ne $true) {
		New-Item -type directory -Path $global:report.Runtime.Configs.runtime_log_directory
		#$childitem = Get-Item -Path $global:report.Runtime.Configs.runtime_log_directory
		#$global:report.Runtime.Configs.runtime_log_directory = $childitem.FullName
	}
	$global:report["Runtime"]["LogDirectory"]=$global:report.Runtime.Configs.runtime_log_directory	
	$logfile="$($global:report.Runtime.Configs.runtime_log_directory)\documentCustomer.log"
	$global:report["Runtime"]["Logfile"]=$logfile
	
	if (!$global:report.Runtime.Configs.Silent)
	{
		#Invoke-Item $global:report.Runtime.Configs.runtime_log_directory
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
	if ($global:report.Runtime.Configs.collectVMwareReports)
	{
		$type="VMware"
		$global:report["$type"] = @{}
		$global:report["$type"]["Runtime"]=@{}
		$global:report["$type"]["DataTable"]=@{}
		$vcCredentialsFileDirectory = Split-Path $global:report.Runtime.Configs.vcCredentialsFile
		if (!$vcCredentialsFileDirectory)
		{
			$global:report.Runtime.Configs.vcCredentialsFile="$(Split-Path $inifile)\$($global:report.Runtime.Configs.vcCredentialsFile)"
		}
		
		try 
		{	
			$filepath=$global:report.Runtime.Configs.vcCredentialsFile | Resolve-Path -ErrorAction Stop
			
			$passwordFile = "$($($filepath).Path)"	
			#$passwordFile
			
		} Catch {		
			#$ErrorMessage = $_.Exception.Message
	    		#$FailedItem = $_.Exception.ItemName
			#showError -msg $ErrorMessage
			$global:report.Runtime.Configs.vcCredentialsFile
			
			set-mycredentials -Filename $global:report.Runtime.Configs.vcCredentialsFile
			$passwordFile = $global:report.Runtime.Configs.vcCredentialsFile
			#break
		}
		
		Set-Location "$($global:report.Runtime.Configs.scriptsLoc)\$($global:report.Runtime.Configs.vmwareScriptsHomeDir)"
		
		if (!$srvconnection)
		{
			logThis -msg ">>>>" -ForegroundColor $global:colours.Information
			logThis -msg "$($global:report.Runtime.Configs.vCenterServers)"
			logThis -msg ">>>>" -ForegroundColor $global:colours.Information
			#$credentials = & "$($global:report.Runtime.Configs.scriptsLoc)\$($global:report.Runtime.Configs.vmwareScriptsHomeDir)\get-mycredentials-fromFile.ps1" -User $vcUser -SecureFileLocation  $passwordFile
			$credentials = getmycredentialsfromFile -User $global:report.Runtime.Configs.vcUser -SecureFileLocation $passwordFile
			$global:report.Runtime.Configs.vCenterServers=$global:report.Runtime.Configs.vCenterServers -split ','
			$srvconnection= Connect-VIServer -Server @($global:report.Runtime.Configs.vCenterServers) -Credential $credentials			
		}
		
		$global:report["$type"]["Runtime"]["vCenters"]=$global:report.Runtime.Configs.vCenterServers
		$out = Import-Module -Name "$($global:report.Runtime.Configs.scriptsLoc)\$($global:report.Runtime.Configs.vmwareScriptsHomeDir)\vmwareModules.psm1" -Force -Verbose:$false
		
		#Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global		
	#	 # -logDir $global:report.Runtime.Configs.runtime_log_directory -parentScriptName $($MyInvocation.MyCommand.name)
		
		logThis -msg "Collecting VMware Reports ($runtime_log_directory)" -logfile $logfile 
		$global:report["$type"]["Runtime"]["Lofile"]=$logfile
		#$($global:report.Runtime.Configs.scriptsLoc)\$($global:report.Runtime.Configs.vmwareScriptsHomeDir)="C:\admin\scripts\vmware" # requires interacting with VMware vCenter server
		if ($srvconnection)
		{			
			logThis -msg "`t-> Collecting VMware Reports" -logfile $logfile 
			if ($scriptParams) {remove-variable scriptParams}
							#'runPerformanceReports' = $global:report.Runtime.Configs.perfChecks;							
			$scriptParams = @{
				'logProgressHere'=$logfile;
				'srvconnection'=$srvconnection;
				'logDir'=$global:report.Runtime.LogDirectory;
				'runCapacityReports' = $global:report.Runtime.Configs.capacity;
				'runPerformanceReports' = $global:report.runtime.Configs.perfChecks;
				'runExtendedReports' = $global:report.Runtime.Configs.runExtendedVMwareReports;
				'vms' = $global:report.Runtime.Configs.vmsToCheckPerformance;
				'showPastMonths' = [int]$global:report.Runtime.Configs.previousMonths;
				'runJobsSequentially' = $global:report.Runtime.Configs.runJobsSequentially;
				'returnResultsOnly'=$true
			}
			logThis -msg "Collecting firstime infrastructure items"
			$infrastructure = collectAllEntities -server $srvconnection -force $true
			logThis -msg "Calling collector.."
			$global:report["$type"] = & "$($global:report.Runtime.Configs.scriptsLoc)\$($global:report.Runtime.Configs.vmwareScriptsHomeDir)\collectAll.ps1" @scriptParams
		}  else {
			logThis -msg ">>" -ForegroundColor $global:colours.Error  -logfile $logfile 
			logThis -msg ">> Unable to connect to vCenter Server(s) ""$($global:report.Runtime.Configs.vCenterServers)""."  -ForegroundColor $global:colours.Error  -logfile $logfile 
			logThis -msg ">> Check the address, credentials, and network connectivity"  -ForegroundColor $global:colours.Error  -logfile $logfile 
			logThis -msg ">> between your script and the vCenter server and try again." -ForegroundColor $global:colours.Error  -logfile $logfile 
			logThis -msg ">>" -ForegroundColor $global:colours.Error  -logfile $logfile 
		}
	}



	###########################################################################
	#
	# SAN REPORTS :- 
	#
	###########################################################################
	Set-Location $($global:report.Runtime.Configs.scriptsLoc)
	# NOT WORKING!!!
	if ($global:report.Runtime.Configs.collectSANReports)
	{
		$passwordFile = "$($($global:report.Runtime.Configs.sanV7000SecurePasswordFile | Resolve-Path).Path)"
		logThis -msg "Collecting SAN Reports"  -logfile $logfile 
		###########################################################################
		#
		# REPORT 1 :- IBM V7000 ARRAYS
		#
		###########################################################################
		
		if ($global:report.Runtime.Configs.sanV7000collectReports)
		{
			$reportHeader="Storage Health Check"
			$reportIntro="This report was prepared by $itoContactName for $($global:report.Runtime.Configs.customer) as a review of its Storage Systems."	
			$thisReportLogdir="$($global:report.Runtime.Configs.runtime_log_directory)\Storage"
			$type="V7000"
			$global:report["$type"] = @{}
			$global:report["$type"]["Runtime"]=@{}
			$global:report["$type"]["Runtime"]["Logfile"] = $logfile
			$global:report["$type"]["Runtime"]["Title"] = $reportHeader
			$global:report["$type"]["Runtime"]["Introduction"] = $reportIntro
			$global:report["$type"]["Runtime"]["LogDirectory"] = $thisReportLogdir			
	        
	        if ($global:report.Runtime.Configs.sanV7000User -and $global:report.Runtime.Configs.sanV7000SecurePasswordFile -and !$global:report.Runtime.Configs.sanV700password)
	        {
	            #$credentials = & "$($global:report.Runtime.Configs.scriptsLoc)\$sanV7000scriptsHomeDir\get-mycredentials-fromFile.ps1" -User $sanV7000User -SecureFileLocation $passwordFile
			  $credentials = get-mycredentials-fromFile -User $global:report.Runtime.Configs.sanV7000User -SecureFileLocation $passwordFile
	        }
			if ($global:report.Runtime.Configs.sanV7000User -and $global:report.Runtime.Configs.sanV700password -and $global:report.Runtime.Configs.sanV7000ArraysIPs)
			{    
				$credentials = Get-Credential -UserName  $global:report.Runtime.Configs.sanV7000User -Message "Please specify a password for user account ""$($global:report.Runtime.Configs.sanV7000User)"" to use to authenticate against arrays [string]$($global:report.Runtime.Configs.sanV700ArraysIPs)"
	            #$deviceList = (($sanV7000ArraysIPs -split ',' -replace '^','"') -replace '$','"') -join ','
	            $deviceList = $global:report.Runtime.Configs.sanV7000ArraysIPs -split ','
	            & "$($global:report.Runtime.Configs.scriptsLoc)\$($global:report.Runtime.Configs.sanV7000scriptsHomeDir)\ibmstorwize-checks.ps1" -logDir $thisReportLogdir -username $global:report.Runtime.Configs.sanV7000User -cpassword $sanV700password -arrayOfTargetDevices $deviceList

			}


	        #if(!$stopReportGenerator)
			#{
				#& "$($global:report.Runtime.Configs.scriptsLoc)\$($global:report.Runtime.Configs.vmwareScriptsHomeDir)\generateInfrastructureReports.ps1" -inDir $thisReportLogdir -logDir $global:report.Runtime.Configs.outputDirectory -reportHeader $global:report.Runtime.Configs.reportHeader -reportIntro $global:report.Runtime.Configs.reportIntro -farmName $global:report.Runtime.Configs.customer -openReportOnCompletion  $global:report.Runtime.Configs.openReportOnCompletion -htmlReports $global:report.Runtime.Configs.htmlReports -emailReport $global:report.Runtime.Configs.emailReport -verbose $false -itoContactName $global:report.Runtime.Configs.itoContactName
			#}

		}

		###########################################################################
		#
		# REPORT 2 :- BROCADE SAN Fibre Switches IOS
		#
		###########################################################################
		$collectSanIosFibreSwitches = $true
		if ($collectSanIosFibreSwitches)
		{
			$type="Brocade"
			$global:report["$type"] = @{}
			$global:report["$type"]["Runtime"]=@{}
			$global:report["$type"]["Runtime"]["Logfile"] = $logfile
			$sanIOSscriptsHomeDir="$($global:report.Runtime.Configs.scriptsLoc)\$($global:report.Runtime.Configs.brocadeIOSscriptsHomeDir)"
		}
	}

	###########################################################################
	#
	# XEN REPORTS :- 
	#
	###########################################################################
	Set-Location $($global:report.Runtime.Configs.scriptsLoc)	
	if ($global:report.Runtime.Configs.collectXenReports)
	{
		$type="XenServer"
		$global:report["$type"] = @{}
		$global:report["$type"]["Runtime"]=@{}
		$global:report["$type"]["Runtime"]["Logfile"] = $logfile
		logThis -msg "Collecting XEN Reports"
		$xenScriptsHomeDir="$($global:report.Runtime.Configs.scriptsLoc)\$($global:report.Runtime.Configs.xenscriptsHomeDir)" # requires interacting with master server
	}

	###########################################################################
	#
	# HYPERV-V REPORTS :- 
	#
	###########################################################################
	Set-Location $($global:report.Runtime.Configs.scriptsLoc)	
	if ($global:report.Runtime.Configs.collectHYPERVReports)
	{
		$type="HyperV"
		$global:report["$type"] = @{}
		$global:report["$type"]["Runtime"]=@{}
		$global:report["$type"]["Runtime"]["Logfile"] = $logfile
		logThis -msg "Collecting Hyper-V Reports"  -logfile $logfile 
		$hypervScriptsHomeDir="$($global:report.Runtime.Configs.scriptsLoc)\$($global:report.Runtime.Configs.hyperVscriptsHomeDir)" # requires interacting with master server
	}

	###########################################################################
	#
	# WMI REPORTS :- 
	#
	###########################################################################
	Set-Location $($global:report.Runtime.Configs.scriptsLoc)	
	if ($global:report.Runtime.Configs.collectWMIReports)
	{
		$type="Windows"
		$global:report["$type"] = @{}
		$global:report["$type"]["Runtime"]=@{}
		$global:report["$type"]["Runtime"]["Logfile"] = $logfile
		logThis -msg "Collecting Windows WMI Reports"  -logfile $logfile 
		$wmiScriptsHomeDir="$($global:report.Runtime.Configs.scriptsLoc)\$($global:report.Runtime.Configs.wmiScriptsHomeDir)" # requires interacting with Windows via network 
	}

	###########################################################################
	#
	# Linux Servers REPORTS :- 
	#
	###########################################################################
	Set-Location $($global:report.Runtime.Configs.scriptsLoc)	
	if ($global:report.Runtime.Configs.collectLinuxReports)
	{
		$type="Linux"
		$global:report["$type"] = @{}
		$global:report["$type"]["Runtime"]=@{}
		$global:report["$type"]["Runtime"]["Logfile"] = $logfile
		logThis -msg "Collecting Linux Systems Reports"  -logfile $logfile		
		$wmiScriptsHomeDir="$($global:report.Runtime.Configs.scriptsLoc)\$($global:report.Runtime.Configs.linuxScriptsHomeDir)" # requires interacting with Windows via network 
	}

	# Set the location back to the original directory
	Set-Location $($global:report.Runtime.Configs.scriptsLoc)

	$global:report["Runtime"]["Logs"] = getRuntimeLogFileContent
}


<#
	THIS IS WHERE IT BEGINS
#>
Import-Module "$scriptsLoc\generic\genericModule.psm1" -Force
try {
	if (!$xmlFile)
	{
		# running the audit to produce a resultant XML file.
		$inifile = ($inifile | Resolve-Path -ErrorAction SilentlyContinue).Path
		#$configObj,$preconfig = readConfiguration -inifile $inifile		
		$configObj = convertTextVariablesIntoObject (Get-Content $inifile)
		# all reports, file attachment paths, and runtime information for each scripts 
		# are returned to the variable $global:report
		$global:report = @{}
		$global:report["Runtime"]=@{}
		$global:report["Runtime"]["StartTime"]=Get-Date
		$configObj.Add("Silent",$silent)
		$configObj.Add("scriptsLoc",$scriptsLoc)
		$global:configs = $configObj
		$global:report["Runtime"]["Configs"]=$configObj
		#Set-Variable -Scope Global -Name silent -Value $silent

		startProcess
		
		$global:report["Runtime"]["EndTime"]=Get-Date
		
		$xmlOutput = "$($global:report.Runtime.LogDirectory)\$($global:report.Runtime.Configs.Customer -replace ' ','_').xml"
		logThis -msg "Writing results to $xmlOutput"
		$global:report | Export-Clixml -Path $xmlOutput

		$zippedXmlOutput = $xmlOutput -replace ".xml",".zip"
		logThis -msg "Zipping results for transport to $zippedXmlOutput"
		$o=New-ZipFile -InputObject $xmlOutput -ZipFilePath $zippedXmlOutput 
		# Thinking about putting this in the ini file but it's getting a little big and out of hand. I will leave it here until I have figured a better way.
		$deleteXML=$false
		if ((Test-Path -Path $zippedXmlOutput) -and $deleteXML)
		{
			Remove-Item $xmlOutput
		}			
		# Process the results
	} else {
		# I don't want to collect anymore data but simply read in the resultant XML file.
		$global:report = Import-Clixml $xmlFile
	}

	##############################################################################################
	#	EMAIL XML RESULTANT FILE 
	#
	if ($global:report -and $global:report.Runtime.Configs.emailReport)
	{
		logThis -msg "Emailing results"
		if ($emailParams) {remove-variable scriptParams}
			
		$body = @"
			Health check results for $($global:report.Runtime.Configs.subject) $($global:report.Runtime.Configs.customer)
"@
			
		# This routine sends the email
		#function emailContact ([string] $smtpServer,  [string] $from, [string] $replyTo, [string] $toAddress ,[string] $subject, [string] $htmlPage) {
		if ($global:report.Runtime.Configs.myMailServerRequiresAuthentication)
		{	
			$emailFileDirectory = Split-Path $global:report.Runtime.Configs.emailCredEncryptedPasswordFile
			if (!$emailFileDirectory)
			{
				$global:report.Runtime.Configs.emailCredEncryptedPasswordFile = "$(Split-Path $($global:report.Runtime.configs.inifile))\$($global:report.Runtime.Configs.emailCredEncryptedPasswordFile)"
			}
			$mailCredentials = getmycredentialsfromFile -User $global:report.Runtime.Configs.emailCredUser -SecureFileLocation $global:report.Runtime.Configs.emailCredEncryptedPasswordFile
		} else {
			$mailCredentials = $null
		}
			
		$attachments += $zippedXmlOutput;
		$emailParams = @{ 
			'subject' = $global:report.Runtime.Configs.subject;
			'smtpServer' = $global:report.Runtime.Configs.smtpServer;
			'replyTo' = $global:report.Runtime.Configs.replyToRecipients;
			'from' = $global:report.Runtime.Configs.fromRecipients;
			'toAddress' = $global:report.Runtime.Configs.toRecipients;
			'body' = $body;
			'attachments' = [object]$attachments;
			'fromContactName' = $global:report.Runtime.Configs.fromContactName
			'credentials' = $mailCredentials
		}
		sendEmail @emailParams
	}

	##############################################################################################
	#	HTML REPORTS 
	#
	# if the ini file contains htmlReports=true, then create HTML files
	if ($global:report -and $global:report.Runtime.Configs.htmlReports)
	{
		logThis -msg "Generating HTML Report..."
		$htmlFile = "$($global:report.Runtime.LogDirectory)\report.html"
		$reportParamters = @{
			"reportHeader"=$global:report.Runtime.Configs.reportHeader;
			"reportIntro"=$global:report.Runtime.Configs.reportIntro;
			"farmName"=$global:report.Runtime.Configs.customer;
			"openReportOnCompletion"=$global:report.Runtime.Configs.openReportOnCompletion;
			"verbose"=$false
			"itoContactName"=$global:report.Runtime.Configs.itoContactName;
			'xml'= $global:report
		}
		$htmlPage = generateHTMLReport @reportParamters	
		$htmlPage | Out-File "$htmlFile"
		logThis -msg "---> Opening $htmlFile"
		if ($global:report.Runtime.Configs.openReportOnCompletion)
		{
			
			Invoke-Expression "$htmlFile"
		}
		
		if ($global:report.Runtime.Configs.emailReport)
		{
			$emailParams = @{ 
				'subject' = $global:report.Runtime.Configs.subject;
				'smtpServer' = $global:report.Runtime.Configs.smtpServer;
				'replyTo' = $global:report.Runtime.Configs.replyToRecipients;
				'from' = $global:report.Runtime.Configs.fromRecipients;
				'toAddress' = $global:report.Runtime.Configs.toRecipients;
				'body' = $body;
				'attachments' = [object]$html;
				'fromContactName' = $global:report.Runtime.Configs.fromContactName
				'credentials' = $mailCredentials
			}
			sendEmail @emailParams
		}
	}
	
	$issueEncountered=$false
	if ($global:report ) { return $global:report }
} catch [system.exception]
{
	logThis -msg "Caught a system exception: $_"
	showError -msg $_
	$issueEncountered=$true
  
} Finally
{
	Set-Location $($global:report.Runtime.Configs.scriptsLoc)
	if ($report) { Remove-Variable report -Scope Global }
	if ($srvconnection) { Remove-Variable srvconnection -Scope Global }	
	if ($configObj) { Remove-Variable configObj -Scope local }
	#if ($preconfig) {Remove-Variable preconfig -Scope local }

	if ($issueEncountered)
	{
		logThis -msg "Script completed with one or more issue."
	} else {
		logThis -msg "Script completed successfully without issues."
	}
	
}