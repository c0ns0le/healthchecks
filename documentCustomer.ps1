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

[bool]$global:logTofile = $false
[bool]$global:logInMemory = $true
[bool]$global:logToScreen = $true

$script=$MyInvocation.MyCommand.Path
$scriptsLoc=$(Split-Path $script)

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
			$updatedField = $configurations.$keyname | %{
				$curr_string = $_				
				if ($curr_string.count -gt 1 -and $curr_string -match '$')
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
						} else {
							$word
						}
					}
					$updatedValue = [string]$newstring_array
				} elseif ($curr_string -eq $true)
				{
					$updatedValue = $true
				} elseif ($curr_string -eq $false)
				{
					$updatedValue = $false
				} else {
					$updatedValue = $curr_string
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
	Import-Module ".\generic\genericModule.psm1" -Force	

	if ((Test-Path -path $global:configs.runtime_log_directory) -ne $true) {
		New-Item -type directory -Path $global:configs.runtime_log_directory
		#$childitem = Get-Item -Path $global:configs.runtime_log_directory
		#$global:configs.runtime_log_directory = $childitem.FullName
	}
	$global:report["Runtime"]["LogDirectory"]=$global:configs.runtime_log_directory	
	$logfile="$($global:configs.runtime_log_directory)\documentCustomer.log"
	$global:report["Runtime"]["Logfile"]=$logfile
	
	if (!$global:configs.Silent)
	{
		#Invoke-Item $global:configs.runtime_log_directory
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
		$type="VMware"
		$global:report["$type"] = @{}
		$global:report["$type"]["Runtime"]=@{}
		$global:report["$type"]["DataTable"]=@{}
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
			
		} Catch {		
			#$ErrorMessage = $_.Exception.Message
	    		#$FailedItem = $_.Exception.ItemName
			#showError -msg $ErrorMessage
			$global:configs.vcCredentialsFile
			
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
		
		$global:report["$type"]["Runtime"]["vCenters"]=$global:configs.vCenterServers
		Import-Module -Name "$($global:configs.scriptsLoc)\$($global:configs.vmwareScriptsHomeDir)\vmwareModules.psm1" -Force
		
		#Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
		
		InitialiseModule -logDir $global:configs.runtime_log_directory -parentScriptName $($MyInvocation.MyCommand.name)
		
		logThis -msg "Collecting VMware Reports ($runtime_log_directory)" -logfile $logfile 
		$global:report["$type"]["Runtime"]["Lofile"]=$logfile
		#$($global:configs.scriptsLoc)\$($global:configs.vmwareScriptsHomeDir)="C:\admin\scripts\vmware" # requires interacting with VMware vCenter server
		if ($srvconnection)
		{			
			logThis -msg "`t-> Collecting VMware Reports" -logfile $logfile 
			if ($scriptParams) {remove-variable scriptParams}
			$scriptParams = @{
				'logProgressHere'=$logfile;
				'srvconnection'=$srvconnection;
				'logDir'=$global:report.Runtime.LogDirectory;
				'runCapacityReports' = $global:report.Runtime.Configs.capacity;
				'runPerformanceReports' = $global:report.Runtime.Configs.perfChecks;
				'runExtendedReports' = $global:report.Runtime.Configs.runExtendedVMwareReports;
				'vms' = $global:report.Runtime.Configs.vmsToCheckPerformance;
				'showPastMonths' = [int]$global:report.Runtime.Configs.previousMonths;
				'runJobsSequentially' = $global:report.Runtime.Configs.runJobsSequentially;
				'returnResultsOnly'=$true
			}
			$global:report["$type"] = & "$($global:configs.scriptsLoc)\$($global:configs.vmwareScriptsHomeDir)\collectAll.ps1" @scriptParams
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
			$type="V7000"
			$global:report["$type"] = @{}
			$global:report["$type"]["Runtime"]=@{}
			$global:report["$type"]["Runtime"]["Logfile"] = $logfile
			$global:report["$type"]["Runtime"]["Title"] = $reportHeader
			$global:report["$type"]["Runtime"]["Introduction"] = $reportIntro
			$global:report["$type"]["Runtime"]["LogDirectory"] = $thisReportLogdir			
	        
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
			$type="Brocade"
			$global:report["$type"] = @{}
			$global:report["$type"]["Runtime"]=@{}
			$global:report["$type"]["Runtime"]["Logfile"] = $logfile
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
		$type="XenServer"
		$global:report["$type"] = @{}
		$global:report["$type"]["Runtime"]=@{}
		$global:report["$type"]["Runtime"]["Logfile"] = $logfile
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
		$type="HyperV"
		$global:report["$type"] = @{}
		$global:report["$type"]["Runtime"]=@{}
		$global:report["$type"]["Runtime"]["Logfile"] = $logfile
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
		$type="Windows"
		$global:report["$type"] = @{}
		$global:report["$type"]["Runtime"]=@{}
		$global:report["$type"]["Runtime"]["Logfile"] = $logfile
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
		$type="Linux"
		$global:report["$type"] = @{}
		$global:report["$type"]["Runtime"]=@{}
		$global:report["$type"]["Runtime"]["Logfile"] = $logfile
		logThis -msg "Collecting Linux Systems Reports"  -logfile $logfile		
		$wmiScriptsHomeDir="$($global:configs.scriptsLoc)\$($global:configs.linuxScriptsHomeDir)" # requires interacting with Windows via network 
	}

	# Set the location back to the original directory
	Set-Location $($global:configs.scriptsLoc)

	$global:report["Runtime"]["Logs"] = getRuntimeLogFileContent
}

# MAIN
if ($configObj) {Remove-Variable configObj -Scope All }
if ($global:configs) {Remove-Variable configs -Scope Global }
if ($preconfig) {Remove-Variable preconfig -Scope All }
if ($global:report) { Remove-Variable report -Scope Global }

$global:report = @{}
$global:report["Runtime"]=@{}
$global:report["Runtime"]["StartTime"]=Get-Date
$configObj,$preconfig = readConfiguration -inifile $inifile
Write-Host "AFTER"
$configObj
Write-Host "BEFORE"
$preconfig 
pause
if ($configObj)
{	
	$configObj.Add("Silent",$silent)
	$configObj.Add("scriptsLoc",$scriptsLoc)
	$global:configs = $configObj
	$global:report["Runtime"]["Configs"]=$configObj
	#Set-Variable -Scope Global -Name silent -Value $silent

	startProcess
	$global:report["Runtime"]["EndTime"]=Get-Date
	return $global:report

} else {
	logThis -msg "Invalid Configurations"
}

