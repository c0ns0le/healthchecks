# Generates a list of VMs then an email summary of VM ownership to each "Contact" + a special Manager Style Report with lots of Summary 
# Version : 0.9
#Author : 12/03/2014, by teiva.rodiere-at-gmail.com
# Syntax
# .\sendListOfVMsToContacts-shortlist.ps1 -srvconnection $srvconnection -includeIndividualReports [$true|$false] -includeManagersReport [$true|$false] -emailReport [$true|$false] -verboseHTMLFilesToFile [$true|$false]
#
# Examples - 
# 1) Only create a HTML output for each Contact email (not actually emailing) for INdividual and manager reports
# .\sendListOfVMsToContacts-shortlist.ps1 -srvconnection $srvconnection -includeIndividualReports $true -includeManagersReport $true -emailReport $false -verboseHTMLFilesToFile $true
#
# 2) Only email output for each Contact and email for INdividual and manager reports
#.\sendListOfVMsToContacts-shortlist.ps1 -srvconnection $srvconnection -includeIndividualReports $true -includeManagersReport $true -emailReport $true -verboseHTMLFilesToFile $false
#
# 3) Only create a HTML output for each email (not actually emailing) for INdividual and manager reports
# .\sendListOfVMsToContacts-shortlist.ps1 -srvconnection $srvconnection -includeIndividualReports $true -includeManagersReport $true -emailReport $false -verboseHTMLFilesToFile $true -thisContactOnly "tech-unix"


param([object]$srvConnection="",
	[string]$configFile="E:\scripts\customerEnvironmentSettings-ALL.ini",
	[string]$logfile="",
	[string]$logDir="output",
	[string]$comment="",
	[bool]$showOnlyTemplates=$false,
	[bool]$skipEvents=$true,
	[bool]$includeIndividualReports=$true,
	[bool]$includeManagersReport=$true,
	[bool]$verbose=$false,
	[bool]$emailReport=$false,
	[bool]$verboseHTMLFilesToFile=$false,
	[string]$thisContactOnly="")
	
if (!(get-pssnapin VMware.VimAutomation.Core))
{
	Add-pssnapin VMware.VimAutomation.Core
}

Write-Host "Executing script $($MyInvocation.MyCommand.path)" -ForegroundColor  green;
Write-Host "Current path is $($pwd.path)" -ForegroundColor  yellow;

$disconnectOnExist = $true;

###################################
# DEFINE THE IMPORTANT STUFF HERE
###################################
#$farmname = "Managed Services VMware Infrastructure"
#$fromContactName = "INF VMware"
#$fromAddress="inf-vmware@ventyx.abb.com"
#$fromContactName = "Teiva Rodiere"
#$fromAddress="teiva.rodiere-at-gmail.com"
$fromContactName="Service Center"
$fromAddress="servicedesk@gms.ventyx.abb.com"
$farmname = "VENTYX Managed Service VMware Infrastructure"
$gmsContactName = "Ventyx Global Support Helpdesk "
$replyAddress="servicedesk@gms.ventyx.abb.com"
$smtpServer = "mmsbnemrl01.internal.Customer.com"
$emailfqdn = "@ventyx.abb.com" 
# Uncomment the below line to overwride all emails destinations to the one below
#$sendAllEmailsTo="teiva.rodiere-at-gmail.com"

if ($logfile)
{
	$log = $logfile;
} else {
	#$log = "$logDir\collectAll-scheduler.log";
	$log = ($($MyInvocation.MyCommand.Name)).Replace('.ps1','.log');
}

if ($configFile)
{
	$vcenterServers = @();
	foreach ($environment in (Import-CSV $configFile) )
	{
	        $vcenterServers += $environment.vCenterSrvName;
	}
	$srvConnection = get-vc -Server $vcenterServers
	#Write-Output "List of vCenter servers to report: "  | out-file -filepath $log -append
	#$vcenterServers | out-file -filepath $log -append

	#if ($environment.LoginUser -and $environment.SecurePasswordFile)
	#{
		
	#} else {
		#if ($mycred) 
		#{
			#Remove-Variable  mycred
		#}
	#}
} else {
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
}
if ((Test-Path -path $logDir) -ne $true) {
	New-Item -type directory -Path $logDir
}

#[vSphere PowerCLI] D:\INF-VMware\scripts> $viEvent = $vms | Get-VIEvent -Types info | where { $_.Gettype().Name -eq "VmBeingDeployedEvent"}
$runtime="$(date -f dd-MM-yyyy)"
$filename = ($($MyInvocation.MyCommand.Name)).TrimEnd('.ps1');
Write-Host "$filename";


$run1Report =  $srvConnection | %{
	
    $vcenterName = $_.Name
    if ($showOnlyTemplates) 
    {
        Write-Host "Enumerating Virtual Machines Templates only from vCenter $_ inventory..." -ForegroundColor Red
        $vms = Get-Template -Server $_ | Sort-Object Name
        
        #Write-Host "Enumerating Virtual Machines Templates Views from vCenter $_ inventory..." -ForegroundColor Red
        #$vmsViews = $vms | Get-View;
    } else {
        Write-Host "Enumerating Virtual Machines from vCenter $_ inventory..." -ForegroundColor Red
        $vms = Get-VM -Server $_ | Sort-Object Name 
        
        #Write-Host "Enumerating Virtual Machines Views from vCenter $_ inventory..." -ForegroundColor Red
        #$vmsViews = $vms | Get-View;
    }
    
    if ($vms) 
    {
		$index=1;
        $vms | %{
			$vm = $_;
            #$vmView = $vmsView | ?{$_.Name -eq $vm.Name}
			Write-Host "Processing $index of $($vms.Count) :- $vm" -ForegroundColor Yellow;
			$GuestConfig = "" | Select-Object Name; 
			$GuestConfig.Name = $vm.Name;
            $GuestConfig | Add-Member -Type NoteProperty -Name "GuestHostname" -Value $vm.ExtensionData.Guest.HostName;
            $GuestConfig | Add-Member -Type NoteProperty -Name "PowerState" -Value $vm.PowerState;
			$GuestConfig | Add-Member -Type NoteProperty -Name "OperatingSystem" -Value $vm.ExtensionData.Config.GuestFullName;
            # Custom Attributes
			if ($vm.ExtensionData.AvailableField) {
				foreach ($field in $vm.ExtensionData.AvailableField) {
					if ($field.Name -like "Contact" -or $field.Name -like "Application")
					{
						$custField = $vm.ExtensionData.CustomValue | ?{$_.Key -eq $field.Key}
						$GuestConfig | Add-Member -Type NoteProperty -Name $field.Name -Value $custField.Value
					}
				}
			}  
			$GuestConfig | Add-Member -Type NoteProperty -Name "ManagementServer" -Value $vcenterName.ToUpper()
			
    		if ($verbose)
            {
                Write-Host $GuestConfig;
            }
    		$GuestConfig;
			Write-Host $GuestConfig;
            $index++;
        }
    } else {
		Write-Host "There are no VMs found";
		exit;
	}
	
}

# Fix the object array, ensure all objects within the 
# array contain the same members (required for Format-Table / Export-CSV)
$loop = 1;
$continue = $true;
Write-Host "-> Fixing the object arrays <-" -ForegroundColor Magenta
while ($continue)
{
	Write-Host "Loop index: " $loop;
	$continue = $false;
	
	$Members = $run1Report | Select-Object `
	@{n='MemberCount';e={ ($_ | Get-Member).Count }}, `
	@{n='Members';e={ $_.PsObject.Properties | %{ $_.Name } }}
	$AllMembers = ($Members | Sort-Object MemberCount -Descending)[0].Members
	
	$serverListReport = $run1Report | %{
		ForEach ($Member in $AllMembers)
		{
			If (!($_ | Get-Member -Name $Member))
			{ 
				$_ | Add-Member -Type NoteProperty -Name $Member -Value "[N/A]"
				$continue = $true;
			}
		}
		Write-Output $_
	}
	
	$run1Report = $serverListReport;
	$loop++;
}

if ($emailReport -or $verboseHTMLFilesToFile)
{
	
	# Group by Contacts
	#$sortedList = $csvImport | Group-Object -Property Contact
	if ($thisContactOnly)
	{
		Write-Host "Yes this contact $thisContactOnly" -BackgroundColor Red -ForegroundColor Yellow
		$sortedList = $serverListReport | Group-Object -Property Contact | ?{$_.Name -eq $thisContactOnly}
		Write-host $sortedList
		Write-Host "Yes this contact $thisContactOnly" -BackgroundColor Red -ForegroundColor Yellow
	} else 
	{
		$sortedList = $serverListReport | Group-Object -Property Contact
	}
	
	if ($sortedList)
	{
		if ($includeIndividualReports)
		{
			$index = 1;
			
			#######################################################################################################
			# Generate Individual Reports
			# This section generates a report all Virtual Machines found in the $serverListReport, 
			# then groups the VMs by their Contact Names, then emails the Contact $firstame.$lastname@$domainfqdn
			#######################################################################################################
			# Only include Assets Contacts -- those without will be exported in the Manager's report section below
			$sortedList | ?{$_.Name} | %{
				$htmlBody = "";
				$contact = $_;
				$serverList = $contact.Group;
				$count = 0
				if ($serverList)
				{
					if ($serverList.Count)
					{
						$count = $serverList.Count
					} else {
						$count = 1
					}
				} else { 
					$count = 0
				}
				
			    $contactName = $contact.Name
				Write-Host "Processing contact: $contactName.." -BackgroundColor Green -ForegroundColor Blue
				Write-Host "-> $count systems associated to the user";
				$subject = "Your Virtual Machines Asset List"
				#$htmlBody = "Dear <strong>$contactName</strong>,<br><br>You are receiving this email because our records show that you are currently nominated as the primary contact for one or more virtual machines found in the $farmname. <h3>Asset Information</h3>"
				$htmlBody += "Dear <strong>$contactName</strong>,<br><br>"
				$htmlBody += "This email has been automatically generated by the $farmname and contains a list of Virtual Machine Systems for which our records show you are the current contact."
				$htmlBody += "<h3>What we need from you</h3>Please review this asset list found below and notify the $gmsContactName ($replyAddress) if any changes are required: <br><br>"
				$htmlBody += "<u>Please note that you must notify the $gmsContactName if:</u>"
				$htmlBody += "<br><ul>"
				$htmlBody += "<li>The below information is NOT accurate </li>"
				$htmlBody += "<li>One or more of these systems can be powered off</li>"
				$htmlBody += "<li>One or more of these systems can be decommissioned </li>"
				$htmlBody += "<li>One or more have been repurposed</li>"
				$htmlBody += "</ul><h3>Assets Information</h3>"
				$htmlBody += "<div>There are currently $count assets in your name.</div><br>"
				$htmlBody += $serverList | ConvertTo-HTML -Fragment
				$htmlBody += "<br><u>Unique table rows: $count</u><br><br>"
				
				$firstname,$lastname = $contactName.Split(' ')
				if ($firstname -and $lastname)
				{
					$toAddr = $($firstname + "." + $lastname + $emailfqdn).ToString().Trim().ToLower()
				} elseif ($firstname -and !$lastname) {
					$toAddr = $($firstname + $emailfqdn).ToString().Trim().ToLower()
				} else {
					# nothing	
				}
				
				Write-Host "---> Sending Email to $toAddr"
				$a = "<style>"
				$a = $a + "BODY{background-color:white;font-size:11.0pt;font-family:Calibri,sans-serif;color:black}"
				$a = $a + "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}"
				$a = $a + "TH{border-width: 1px;padding: 2px;border-style: solid;border-color: black;background-color:#FEFEFE}"
				$a = $a + "TD{border-width: 1px;padding: 2px;border-style: solid;border-color: black;background-color:lightgray}"
				$a = $a + "</style>"
				$htmlBody += "Thank you for your cooperation. If you need clarification or require assistance, please contact $gmsContactName ($replyAddress)	<br><br>Regards,<br><br>$fromContactName"
				$htmlBody += "<br><br><small>$runtime | $farmname | $srvconnection | generated from $env:computername.$env:userdnsdomain </small>";
				
				$htmlPage = ConvertTo-html -Head $a -Body $htmlBody
				
				if ($verboseHTMLFilesToFile)
				{
					ConvertTo-html -Head $a -Body $htmlBody | Out-File "output\email$index.html"
					Write-Host "---> Opening output\email$index.html"
					Invoke-Expression "output\email$index.html"
				}
				
				if ($emailReport)
				{
					# This routine sends the email
					#function emailContact ([string] $smtpServer,  [string] $from, [string] $replyTo, [string] $toAddress ,[string] $subject, [string] $htmlBody) {
					if ($sendAllEmailsTo)
					{
						Write-Host "Was emailing report to $fromContactName <$fromAddress> but user choice to overide with $sendAllEmailsTo "
						.\sendMail-Routine.ps1 $smtpServer "$fromContactName <$fromAddress>" "$gmsContactName <$replyAddress>"  $sendAllEmailsTo $subject $htmlPage
					} else {
						Write-Host "Emailing report to $contactName <$toAddr>"
						.\sendMail-Routine.ps1 $smtpServer "$fromContactName <$fromAddress>" "$gmsContactName <$replyAddress>"  "$contactName <$toAddr>" $subject $htmlPage
					}
				}
				$index++;
				# adding spacers to the screen
				Write-Host ""
				Write-Host ""
			}
		}
		
		#######################################################################################################
		# Generate Manager Reports
		# This section generates a report based on Virtual Machines list found in $serverListReport, 
		# then creates various reports and emails it to $fromAddress
		#######################################################################################################
		$htmlBody ="";
		if ($includeManagersReport)
		{
			$index=1;
			# HTML header style
			$a = "<style>"
			$a = $a + "BODY{background-color:white;font-size:11.0pt;font-family:Calibri,sans-serif;color:black}"
			$a = $a + "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}"
			$a = $a + "TH{border-width: 1px;padding: 2px;border-style: solid;border-color: black;background-color:#FEFEFE}"
			$a = $a + "TD{border-width: 1px;padding: 2px;border-style: solid;border-color: black;background-color:lightgray}"
			$a = $a + "</style>"
			$subject = "$farmname Capacity Report - Manager report"
			#
			$htmlBody += "Dear <strong>$fromContactName</strong>,<br><br>This email has been automatically generated by the $farmname to provide you with some Capacity information about your environment."
			
			
			#######################################################
			# Add Virtual Machine Assets and Contacts
			$htmlBody += "<h3>Virtual Machine Assets and Contacts</h3>"
			$htmlBody += "<div>This section lists out the number of Virtual Machines per assigned Contact within $farmname. If this list is inacurate, please contact the $gmsContactName to get it updated.</div><br>"
			$htmlBody += $sortedList | Sort-Object -Property Count -Descending | Select-Object -Property Count,Name | ConvertTo-HTML -Fragment
			if ($sortedList)
			{
				if ($sortedList.Count)
				{
					$count = $sortedList.Count
				} else {
					$count = 1
				}
			} else { 
				$count = 0
			}
			$htmlBody += "<br><u>Unique table rows: $count</u><br><br>"
			
			
			#######################################################
			# Add Virtual Machine Assets without Contacts
			$htmlBody += "<h3>Virtual Machine Assets without Contacts</h3>"
			$htmlBody += "<div>This section lists out all Virtual Machines within $farmname which do NOT have a Contact person assigned.</div><br>"
			# Only show account for VMs without Contact assigned
			Write-Host "-> $count systems associated to the user";
			$htmlBody += "This report shows a list of Virtual Machime Systems without an assigned Contacts (Firstname Lastname)."
			$unssignedSystems += $sortedList | ?{!$_.Name} | select-object -Property Group | %{ $_.Group | %{Write-Output $_} }
			$htmlBody += $unssignedSystems | Sort-Object -Property Name -Descending | ConvertTo-HTML -Fragment
			if ($unssignedSystems)
			{
				if ($unssignedSystems.Count)
				{
					$count = $unssignedSystems.Count
				} else {
					$count = 1
				}
			} else { 
				$count = 0
			}
			$htmlBody += "<br><u>Unique table rows: $count</u><br><br>"
			
			$htmlBody += "<h3>Virtual Machine By Operating Systems</h3>"
			$htmlBody += "<div>This section lists out all Virtual Machines within $farmname group by Operating System Types.</div><br>"
			#param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$showDate=$false,[bool]$returnReportOnly=$false)
			$osTypereport = .\Virtual_Machines_By_Operating_System_Types.ps1 $srvConnection "output" "" $false $true
			#Write-Host $osTypereport
			$htmlBody += $osTypereport | ConvertTo-HTML -Fragment
			if ($osTypereport)
			{
				if ($osTypereport.Count)
				{
					$count = $osTypereport.Count
				} else {
					$count = 1
				}
			} else { 
				#$count = 0
			}
			$htmlBody += "<br><u>Unique table rows: $count</u><br><br>"
					
			$htmlBody += "<h3>Complete Assets List</h3>"
			$htmlBody += "<div>This section lists out all Virtual Machines within $farmname.</div><br>"
			$htmlBody += $serverListReport | Sort-Object -Property Name | ConvertTo-HTML -Fragment
			if ($serverListReport)
			{
				if ($serverListReport.Count)
				{
					$count = $serverListReport.Count
				} else {
					$count = 1
				}
			} else { 
				$count = 0
			}
			$htmlBody += "<br><u>Unique table rows: $count</u><br><br>"
			
			# Footer
			$htmlBody += "If you need clarification or require assistance, please contact $gmsContactName ($replyAddress) <br><br>Regards,<br><br>$gmsContactName"
			$htmlBody += "<br><br><small>$runtime | $farmname | $srvconnection | generated from $env:computername.$env:userdnsdomain </small>";
			
			$htmlPage = ConvertTo-html -Head $a -Body $htmlBody
			
			if ($verboseHTMLFilesToFile)
			{
				ConvertTo-html -Head $a -Body $htmlBody | Out-File "output\managersreport.html"
				Write-Host "---> Opening output\managersreport.html"
				Invoke-Expression "output\managersreport.html"
			}
			
			if ($emailReport)
			{
				# This routine sends the email
				#function emailContact ([string] $smtpServer,  [string] $from, [string] $replyTo, [string] $toAddress ,[string] $subject, [string] $htmlBody) {
				
				if ($sendAllEmailsTo)
				{
					Write-Host "Was emailing report to $fromContactName <$fromAddress> but user choice to overide with $sendAllEmailsTo "
					.\sendMail-Routine.ps1 $smtpServer "INF-VMWARE inf-vmware@ventyx.abb.com" "$gmsContactName <$replyAddress>"  $sendAllEmailsTo $subject $htmlPage
				} else {
					Write-Host "Emailing report to $fromContactName <$fromAddress>"
					.\sendMail-Routine.ps1 $smtpServer "INF-VMWARE inf-vmware@ventyx.abb.com" "$gmsContactName <$replyAddress>"  "$fromContactName <$fromAddress>" $subject $htmlPage
				}
			}
			
			#$index++;
			# adding spacers to the screen
			Write-Host ""
			Write-Host ""
		}
	} else {
		Write-Host "There are no listed of VMs generated for the source farms or for this specified contact [$thisContactOnly]" -BackgroundColor Red -ForegroundColor Yellow
	}
} else {
	Write-Host "User Choice : Choosing NOT to generate HTML or emailing reports"
}

#$serverListReport | Export-Csv $of -NoTypeInformation
#Write-Output "" >> $of
#Write-Output "" >> $of
#Write-Output "Collected on $(get-date)" >> $of


#if ($srvConnection -and $disconnectOnExist) {
#	Disconnect-VIServer $srvConnection -Confirm:$false;
#	Write-Host "-> Disconnected from $srvConnection.Name <-" -ForegroundColor Magenta
#}

#Write-Host "Log file written to $of" -ForegroundColor Yellow