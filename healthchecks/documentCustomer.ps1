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
	[Parameter(Mandatory=$true)][string]$inifile,
	[bool]$stopReportGenerator=$false,
	[bool]$silent=$false	
)

[bool]$global:logTofile = $false
[bool]$global:logInMemory = $true
[bool]$global:logToScreen = $true
$script=$MyInvocation.MyCommand.Path
$global:scriptName = Split-Path $MyInvocation.MyCommand.Path -Leaf
$scriptsLoc=$(Split-Path $script)

# Clear srvconnection if it already exists
if ($srvconnection -or $global:srvconnection)
{
	Remove-Variable srvconnection -Scope Global
}

function readConfiguration ([Parameter(Mandatory=$true)][string]$inifile)
{
	#logThis -msg "Reading in configurations from file $inifile"
	$configurations = @{}
	Get-Content $inifile | %{
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
			#Write-Host  $configurations.$keyname		 -ForegroundColor White
			$updatedField = $configurations.$keyname | %{
				$curr_string = $_						
				
				if ($curr_string -match '\$')
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
							#Write-Host "Needs replacing $word with $($configurations.$key)"
						} else {
							$word
							#Write-Host "$($word)"
						}
					}
					$updatedValue = [string]$newstring_array
					#Write-Host "-t>>>$updatedValue" -ForegroundColor Blue
				} elseif ($curr_string -eq $true)
				{
					$updatedValue = $true
					#Write-Host "-t>>>$updatedValue" -ForegroundColor Cyan
				} elseif ($curr_string -eq $false)
				{
					$updatedValue = $false
					#Write-Host "-t>>>$updatedValue" -ForegroundColor Green
				} else {
					
					$updatedValue = $curr_string
					#Write-Host "-t>>>$updatedValue" -ForegroundColor Yellow
				}
				$updatedValue
			}
			$postProcessConfigs.Add($keyname,$updatedField)
		}
		$postProcessConfigs.Add("inifile",$inifile)
		#return $configurations,$postProcessConfigs
	
		return $postProcessConfigs,$configurations
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
	Import-Module ".\generic\genericModule.psm1" -Force	

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
			logThis -msg ">>>>" -ForegroundColor Yellow
			logThis -msg "$($global:report.Runtime.Configs.vCenterServers)"
			logThis -msg ">>>>" -ForegroundColor Yellow
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

			$global:report["$type"] = & "$($global:report.Runtime.Configs.scriptsLoc)\$($global:report.Runtime.Configs.vmwareScriptsHomeDir)\collectAll.ps1" @scriptParams
		}  else {
			logThis -msg ">>" -ForegroundColor Red  -logfile $logfile 
			logThis -msg ">> Unable to connect to vCenter Server(s) ""$($global:report.Runtime.Configs.vCenterServers)""."  -ForegroundColor Red  -logfile $logfile 
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


	        if(!$stopReportGenerator)
			{
				& "$($global:report.Runtime.Configs.scriptsLoc)\$($global:report.Runtime.Configs.vmwareScriptsHomeDir)\generateInfrastructureReports.ps1" -inDir $thisReportLogdir -logDir $global:report.Runtime.Configs.outputDirectory -reportHeader $global:report.Runtime.Configs.reportHeader -reportIntro $global:report.Runtime.Configs.reportIntro -farmName $global:report.Runtime.Configs.customer -openReportOnCompletion  $global:report.Runtime.Configs.openReportOnCompletion -createHTMLFile $global:report.Runtime.Configs.createHTMLFile -emailReport $global:report.Runtime.Configs.emailReport -verbose $false -itoContactName $global:report.Runtime.Configs.itoContactName
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
try {
	$inifile = ($inifile | Resolve-Path -ErrorAction SilentlyContinue).Path	
	# all reports, file attachment paths, and runtime information for each scripts 
	# are returned to the variable $global:report
	$global:report = @{}
	$global:report["Runtime"]=@{}
	$global:report["Runtime"]["StartTime"]=Get-Date
	$configObj,$preconfig = readConfiguration -inifile $inifile
	if ($configObj)
	{	
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
		New-ZipFile -InputObject $xmlOutput -ZipFilePath $zippedXmlOutput
		$deleteXML=$false
		if ((Test-Path -Path $zippedXmlOutput) -and $deleteXML)
		{
			Remove-Item $xmlOutput
		}
		if ($global:report.Runtime.Configs.emailReport)
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

		return $global:report

	} else {
		logThis -msg "No configurations found in $inifile"
	}
}catch [system.exception]
{
	logThis -msg "Caught a system exception:"  
	showError -msg $_
  
} Finally
{
	Set-Location $($global:report.Runtime.Configs.scriptsLoc)
	if ($report) { Remove-Variable report -Scope Global }
	if ($srvconnection) { Remove-Variable srvconnection -Scope Global }	
	if ($configObj) { Remove-Variable configObj -Scope local }
	if ($preconfig) {Remove-Variable preconfig -Scope local }
	logThis -msg "Script Exited."
}