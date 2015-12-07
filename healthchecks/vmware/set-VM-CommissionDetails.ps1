# Looks for VMs without COMMISSIONED DATE and COMMISIONED BY attributes, reports them, and looks through past eventsto determine the creation/commissioning date and the user who provisioned it.
# Once it has determined it, you can choose to update vCenter attributes
# Version : 1.0
#Author : 8/07/2013, by teiva.rodiere-at-gmail.com
param([object]$srvConnection="",[string]$logDir="output",[bool]$disconnectOnExist=$false,[string]$comment="",[bool]$reportOnly=$true,[bool]$verbose=$true,[bool]$overwrite=$false,[string]$debugFile)


## Property - WIP
# $fielsd = { 
#
#	#Proposed Syntax: "Name","Default","Overwrite_With_Default"=$false,"Overwrite_if_Not_Empty=$false
# 	"MAC Address

# Expected annotations required in vCenter
$global:annotationMacAddressText="MAC Address"
$global:annotationCommissionByText="Commissioned By"
$global:annotationCommissionDateText="Commissioned Date"
$global:annotationModifiedByText="Last Modified By"
$global:annotationModifiedDateText="Last Modified Date"
$global:annotationModifiedTaskText="Last Task"
$global:annotationModifiedTaskDateText="Last Task Date"
$global:annotationModifiedTaskByText="Last Task By"
$global:annotationDeployedFromTemplateText="Deployed from Template"

$global:annotationCommissionByField = $false
$global:annotationCommissionDateField = $false
$global:annotationModifiedByTextField = $false
$global:annotationModifiedDateTextField = $false
$global:annotationModifiedTaskTextField = $false
$global:annotationModifiedTaskDateTextField = $false
$global:annotationModifiedTaskByTextField = $false
$global:annotationMacAddressTextField = $false
$global:annotationDeployedFromTemplateTextField = $false;

function LogThis([string]$msg,[string]$color="White",[string]$background="black",[string]$filename="",[bool]$newLine=$true)
{
	if ($verbose) {
		if ($newLine)
		{
			Write-Host $msg -ForegroundColor $color -BackgroundColor $background
		} else {
			Write-Host $msg -ForegroundColor $color -BackgroundColor $background -NoNewline
		}
	}
	if ($filename -ne "")
	{
		Write-Output $msg | Out-File -FilePath $filename -Append  
	}
}

# Pass entity and set attributes
function ProcessEntities {
param(
[object]$objEntity,
[object]$vCenterObj,
[string[]]$CreationEventTypes,
[string[]]$ModifiedEventTypes,
[string[]]$EventCategories,
[string]$MessageFilter,
[string]$functionlogFile
)
	
	
	#write-host "-------"
	#write-host "$($global:annotationCommissionByField.key) $($currEntityCommissionBy.Value)"
	#write-host "-------"
	#LogThis -msg "(UPDATES"
    #LogThis -msg "`t$($objEntity.Name): ""$($currEntityCommissionBy.Value)"",""$($currEntityCommissionDate.Value)"",""$($global:annotationModifiedByTextField.Value)"",""$($global:annotationModifiedDateTextField.value)"" --> Needs updating" -color "Yellow" -filename $of
	#LogThis -msg " [""$($currEntityCommissionDate.Value)"",""$($currEntityCommissionBy.Value)"",""$($currEntityModifiedBy.value)"",""$($currEntityModifiedDate.Value)""]" -color "Yellow" -filename $of
	#$objEntity = $_
	#$row = @()
	$row = "" | Select-Object "Entity","CommissionedDate","CommissionedBy","LastModified","LastModifiedBy","LastTask","LastTaskDate","LastTaskBy","Status","DeployedFrom","vCenter","ScriptAction"
    $row.Entity = $objEntity.Name
	$row.vCenter = $global:DefaultVIServer.Name
	$row.Status = "Unset - needs modificiation"
	$firstcreationevent = ""
	$firstEvent = ""
	$lastEvent = ""
	
	
	$currEntityCommissionBy = $objEntity.ExtensionData.CustomValue | ?{$_.key -eq $global:annotationCommissionByField.key}
	$currEntityCommissionDate = $objEntity.ExtensionData.CustomValue | ?{$_.key -eq $global:annotationCommissionDateField.key}
	
	if ($CreationEventTypes)
	{
		if ( !$currEntityCommissionBy -or !$currEntityCommissionDate -or !$currDeployedFromTemplate -or $overwrite)
		{
			LogThis -msg "`tSearching for Creation Events"  -Color "Yellow"
			$objEntityEventsCreation = .\Get-MyEvents -name $objEntity.Name -objType $objEntity.ExtensionData.Moref.Type -EventTypes $CreationEventTypes -vCenterObj $vCenterObj
				
			if ($objEntityEventsCreation)
			{
				$firstcreationevent = $objEntityEventsCreation | Sort-Object -Property CreatedTime | select -Last 1
				
				$adjustedTimeCommission = (get-date $firstcreationevent.CreatedTime).Add([system.timezoneinfo]::Local.BaseUtcOffset)
				$row.CommissionedDate =  get-date $adjustedTimeCommission -uformat "%d/%m/%Y %r"
				if (!$firstcreationevent.Username)
				{
					$row.CommissionedBy = "System"			
				} else {
					$row.CommissionedBy = $firstcreationevent.Username
				}
				
				#####################################
				#  Commissioned Date
				#####################################
				#Write-Host "[$($currEntityCommissionDate.Value)]" -ForegroundColor Red -BackgroundColor Yellow
				
		        if ($row.CommissionedDate) {
					# If something already exist in the field, then just overwrite
					#if ( ($currEntityCommissionDate -and $currEntityCommissionDate.Value -ne "") -and $overwrite -eq $true)
					#if ( ( ($currEntityCommissionDate.Value -ne "") -and $overwrite ) -or ($currEntityCommissionDate.Value -eq "") )
					#if ( $overwrite -or ( $currEntityCommissionDate.Value -eq "") )
					if ( ($currEntityCommissionDate -and $overwrite) -or !$currEntityCommissionDate)
					{
						if ($row.CommissionedDate -eq $currEntityCommissionDate.Value)
						{
							LogThis -msg "`t--> [SKIPPING] Original and New ""$global:annotationCommissionDateText"" are the same [Original: $($currEntityCommissionDate.Value), New: $($row.CommissionedDate)]" -color "Red" -filename $of
						} else {
							if ($reportOnly)
							{
								LogThis -msg "`t--> [READONLY] New ""$global:annotationCommissionDateText"" would be set to [$($row.CommissionedDate)] " -color "Magenta" -filename $of
							} else 
							{
								LogThis -msg "`t--> [UPDATING] New ""$global:annotationCommissionDateText"" will be set to [$($row.CommissionedDate) " -color "Blue" -filename $of
								#Set-Annotation -Entity $objEntity -CustomAttribute $global:annotationCommissionDateText -Value "$(get-date $firstcreationevent.CreatedTime -uformat ""%d/%m/%Y %r"")"
								Set-Annotation -Entity $objEntity -CustomAttribute $global:annotationCommissionDateText -Value "$($row.CommissionedDate)"
							}
						}
					} else
					{
						LogThis -msg "`t--> [SKIPPING] Original ""$global:annotationCommissionDateText"" not empty [Original: $($currEntityCommissionDate.Value), New: $($row.CommissionedDate)] -- Use ""-overwrite=`$true"" to force update this field" -color "Red" -filename $of
					}
		        } else {
					LogThis -msg "`t--> [SKIPPING] No ""$global:annotationCommissionDateText"" events found in this Inventory  [$($row.CommissionedDate)]" -color "Red" -filename $of
				}
				#####################################
				#  Commissioned By Username
				#####################################
		        if ($row.CommissionedBy) {
					#if ( ( ($currEntityCommissionBy.Value -ne "") -and ($overwrite) ) -or ($currEntityCommissionBy.Value  -eq "") )
					#if ( $overwrite -or ( $currEntityCommissionBy.Value -eq "") )
					if ( ($currEntityCommissionBy -and $overwrite) -or !$currEntityCommissionBy)
					{
						if ($firstcreationevent.Username -eq $currEntityCommissionBy.Value)
						{
							LogThis -msg "`t--> [SKIPPING] Original and New ""$global:annotationCommissionByText"" are the same [Original: $($currEntityCommissionBy.Value), New: $($row.CommissionedBy)]" -color "Red" -filename $of
						} else {
							if ($reportOnly)
							{
								LogThis -msg "`t--> [READONLY] New ""$global:annotationCommissionByText"" would be set to [$($row.CommissionedBy)]" -color "Magenta" -filename $of
							} else {
								LogThis -msg "`t--> [UPDATING] New ""$global:annotationCommissionByText"" will set to [$($row.CommissionedBy)]" -color "Blue" -filename $of
			        			Set-Annotation -Entity $objEntity -CustomAttribute $global:annotationCommissionByText -Value "$($row.CommissionedBy)"
							}
						}
					} else {
						LogThis -msg "`t--> [SKIPPING] Original ""$global:annotationCommissionByText"" field not empty [Original: $($currEntityCommissionBy.Value), New: $($row.CommissionedBy)] -- Use ""-overwrite=`$true"" to force update this field" -color "Red" -filename $of
						Set-Annotation -Entity $objEntity -CustomAttribute $global:annotationCommissionByText -Value "$($row.CommissionedBy)"
					}
		        } else {
					LogThis -msg "`t--> [SKIPPING] Cannot set ""$global:annotationCommissionByText"" - Username empty" -color "Red" -filename $of
				}
				
				#####################################
				#  Deployed From Source Template
				#####################################
				$annotationDeployedFromTemplate = $objEntity.ExtensionData.CustomValue | ?{$_.key -eq $global:annotationDeployedFromTemplateTextField.key}
				if (($annotationDeployedFromTemplate -and $overwrite) -or !$annotationDeployedFromTemplate)
				{	
					$row.DeployedFrom = "Unknown" # the default
					$tempEventDeployment = "";
					$tempEvents = $objEntityEventsCreation | ?{$_.GetType().Name -eq "VmBeingDeployedEvent"}
					if ($tempEvents)
					{	
						if ($tempEvents.GetType().IsArray)
						{
							$tempEventDeployment = $($tempEvents | Sort-Object -Property CreatedTime | select -Last 1).SrcTemplate.Name
						} else {
							$tempEventDeployment = $tempEvents.SrcTemplate.Name
						}
						if ($tempEventDeployment)
						{
							$row.DeployedFrom = $tempEventDeployment
						} else {
							$row.DeployedFrom = "Unknown"
						}
						if ($annotationDeployedFromTemplate -eq $row.DeployedFrom)
						{
							LogThis -msg "`t--> [SKIPPING] Original and New ""$global:annotationDeployedFromTemplateText"" are the same [Original: $annotationDeployedFromTemplate, New: $($row.DeployedFrom)]" -color "Red" -filename $of
						} else {
							if ($reportOnly)
							{
								LogThis -msg "`t--> [READONLY] New ""$global:annotationDeployedFromTemplateText"" would be set to [$($row.DeployedFrom)]" -color "Magenta" -filename $of
							} else {
								LogThis -msg "`t--> [UPDATING] New ""$global:annotationDeployedFromTemplateText"" will set to [$($row.DeployedFrom)]" -color "Blue" -filename $of
				        		Set-Annotation -Entity $objEntity -CustomAttribute $global:annotationDeployedFromTemplateText -Value "$($row.DeployedFrom)"
							}
						}
					} else {						
						if ($reportOnly)
						{
							LogThis -msg "`t--> [READONLY] Cannot get ""$global:annotationDeployedFromTemplateText"" - No Events Found for this VirtualMachine, setting to [Unknown]" -color "Red" -filename $of
						} else {
							LogThis -msg "`t--> [UPDATING] New ""$global:annotationDeployedFromTemplateText"" will set to [$($row.DeployedFrom)]" -color "Blue" -filename $of
			        		Set-Annotation -Entity $objEntity -CustomAttribute $global:annotationDeployedFromTemplateText -Value "$($row.DeployedFrom)"
						}
					}
				}
			}
		} else {
			LogThis -msg "`t--> [SKIPPING] Commissioning Details not empty - use the force option for force the operation" -color "Red" -filename $of
		}
	}else {
		LogThis -msg "`t--> [SKIPPING] User doesn't not want to update Commissioning Details" -color "Red" -filename $of
	}
	
	$currEntityModifiedBy = $objEntity.ExtensionData.CustomValue | ?{$_.key -eq $global:annotationModifiedByTextField.key}
	$currEntityModifiedDate = $objEntity.ExtensionData.CustomValue | ?{$_.key -eq $global:annotationModifiedDateTextField.key}
	
	if ($ModifiedEventTypes)
	{
		LogThis -msg "`tSearching last Reconfiguration Events"  -Color "Yellow"
		$objEntityEventsReconfigurations = .\Get-MyEvents -name $objEntity.Name -objType $objEntity.ExtensionData.Moref.Type -EventTypes $ModifiedEventTypes -vCenterObj $vCenterObj -MessageFilter $MessageFilter
		$lastEvent = $objEntityEventsReconfigurations | Sort-Object -Property CreatedTime -Descending | select -First 1
		$firstEvent = $objEntityEventsReconfigurations | Sort-Object -Property CreatedTime -Descending | select -Last 1
		
		if (!$lastEvent)
		{
			$lastEvent = $firstcreationevent
		}
		$adjustedModifiedDate =  (get-date $lastEvent.CreatedTime).Add([system.timezoneinfo]::Local.BaseUtcOffset)
		$row.LastModified =  get-date $adjustedModifiedDate -uformat "%d/%m/%Y %r"
        if (!$lastEvent.Username)
		{
			$row.LastModifiedBy = "System"
		} else {
			$row.LastModifiedBy = $lastEvent.Username
		}
		#####################################
		#  Last Reconfigured/Updated Date
		#####################################
		if ($row.LastModified){
			if ($row.LastModified -eq $currEntityModifiedDate.Value )
			{
				LogThis -msg "`t--> [SKIPPING] Original and New ""$global:annotationModifiedDateText"" are the same [Original: $($currEntityModifiedDate.Value), New: $($row.LastModified)]" -color "Red" -filename $of
			} else {
				if ($reportOnly)
				{
					LogThis -msg "`t--> [READONLY] New ""$global:annotationModifiedDateText"" would be set to [$($row.LastModified)]" -color "Magenta" -filename $of
				} else {
					LogThis -msg "`t--> [UPDATING] New ""$global:annotationModifiedDateText"" will be set to [$($row.LastModified)]" -color "Blue" -filename $of
					#Set-Annotation -Entity $objEntity -CustomAttribute $global:annotationModifiedDateText -Value "$(get-date $lastEvent.CreatedTime -uformat ""%d/%m/%Y %r"")"
					Set-Annotation -Entity $objEntity -CustomAttribute $global:annotationModifiedDateText -Value "$($row.LastModified)"
				}
			}
		} else {
			LogThis -msg "`t--> [SKIPPING] Cannot set ""$global:annotationModifiedDateText"" - Last Modified Date not found [$($row.LastModified)]" -color "Red" -filename $of
		}
		#####################################
		#  Last reconfigured/Updated By
		#####################################
		if ($row.LastModifiedBy)
		{
			if ($lastEvent.Username -eq $currEntityModifiedBy.Value)
			{
				LogThis -msg "`t--> [SKIPPING] Original and New ""$global:annotationModifiedByText"" are the same [Orginal: $($currEntityModifiedBy.Value), New: $($row.LastModifiedBy)]" -color "Red" -filename $of
			} else {
				if ($reportOnly)
				{
					LogThis -msg "`t--> [READONLY] New ""$global:annotationModifiedByText"" would be set to [$($row.LastModifiedBy)]" -color "Magenta" -filename $of
				} else {
					LogThis -msg "`t--> [UPDATING] New ""$global:annotationModifiedByText"" will be set to [$($row.LastModifiedBy)]" -color "Blue" -filename $of
					Set-Annotation -Entity $objEntity -CustomAttribute $global:annotationModifiedByText -Value "$($row.LastModifiedBy)"
				}
			}
		}  else {
			LogThis -msg "`t--> [SKIPPING] Cannot set ""$global:annotationModifiedByText"" - Username not found [$($row.LastModifiedBy)]" -color "Red" -filename $of
		}
	} else {
		LogThis -msg "`t--> There are no Reconfiguration Events for this system" -color "Red" -filename $of
	}
	
	#$objEntityEevntsLastTasks = .\Get-MyEvents -name $objEntity.Name -objType $objEntity.ExtensionData.Moref.Type -EventTypes $ModifiedEventTypes -vCenterObj $vCenterObj -MessageFilter "Task:"
	# DO this for all devices
	$currEntityModifiedTask = $objEntity.ExtensionData.CustomValue | ?{$_.key -eq $global:annotationModifiedTaskTextField.key}
	$currEntityModifiedTaskDate = $objEntity.ExtensionData.CustomValue | ?{$_.key -eq $global:annotationModifiedTaskDateTextField.key}
	$currEntityModifiedTaskBy = $objEntity.ExtensionData.CustomValue | ?{$_.key -eq $global:annotationModifiedTaskByTextField.key}
	LogThis -msg "`tSearching for Last Tasks events such as tasks"  -Color "Yellow"
	$objEntityEventsTasks = .\Get-MyEvents -name $objEntity.Name -objType $objEntity.ExtensionData.Moref.Type -EventTypes "TaskEvent" -vCenterObj $vCenterObj
	
	if ($objEntityEventsTasks)
	{       
		$lastTaskEvent = $objEntityEventsTasks | Sort-Object -Property CreatedTime -Descending | select -First 1
		$adjustedTaskDate = (get-date $lastTaskEvent.CreatedTime).Add([system.timezoneinfo]::Local.BaseUtcOffset)
		
		$row.LastTask = $lastTaskEvent.FullFormattedMessage
		$row.LastTaskDate = get-date $adjustedTaskDate -uformat "%d/%m/%Y %r"
		if ($lastTaskEvent.Username)
		{
			$row.LastTaskBy = $lastTaskEvent.Username
		} else {
			$row.LastTaskBy = "System"
		}
		##################################
		# Last task Details
		#################################
		if ($row.LastTask) 
		{			
			if ($row.LastTask -eq $currEntityModifiedTask.Value)
			{
				LogThis -msg "`t--> [SKIPPING] Original and New ""$global:annotationModifiedTaskText"" are the same [Orginal: $($currEntityModifiedTask.Value), New: $($row.LastTask)]" -color "Red" -filename $of
			} else {
				if ($reportOnly)
				{
					LogThis -msg "`t--> [READONLY] New ""$global:annotationModifiedTaskText"" would be set to [$($row.LastTask)]" -color "Magenta" -filename $of
				} else {
					LogThis -msg "`t--> [UPDATING] New ""$global:annotationModifiedTaskText"" will be set to [$($row.LastTask)]" -color "Blue" -filename $of
					Set-Annotation -Entity $objEntity -CustomAttribute $global:annotationModifiedTaskText -Value "$($row.LastTask)"
				}
			}
		}  else {
			LogThis -msg "`t--> [SKIPPING] Cannot set ""$global:annotationModifiedTaskText"" - Event details empty[$($row.LastTask)]" -color "Red" -filename $of
		}
		
		##################################
		# Last task Details
		#################################
		if ($row.LastTaskDate) 
		{			
			if ($row.LastTaskDate -eq $currEntityModifiedTaskDate.Value)
			{
				LogThis -msg "`t--> [SKIPPING] Original and New ""$global:annotationModifiedTaskDateText"" are the same [Orginal: $($currEntityModifiedTaskDate.Value), New: $($row.LastTaskDate)]" -color "Red" -filename $of
			} else {
				if ($reportOnly)
				{
					LogThis -msg "`t--> [READONLY] New ""$global:annotationModifiedTaskDateText"" would be set to [$($row.LastTaskDate)]" -color "Magenta" -filename $of
				} else {
					LogThis -msg "`t--> [UPDATING] New ""$global:annotationModifiedTaskDateText"" will be set to [$($row.LastTaskDate)]" -color "Blue" -filename $of
					Set-Annotation -Entity $objEntity -CustomAttribute $global:annotationModifiedTaskDateText -Value "$($row.LastTaskDate)"
				}
			}
		}  else {
			LogThis -msg "`t--> [SKIPPING] Cannot set ""$global:annotationModifiedTaskDateText"" - Event details empty[$($row.LastTaskDate)]" -color "Red" -filename $of
		}
		
		##################################
		# Last task Details By
		#################################
		if ($row.LastTaskBy) 
		{			
			if ($row.LastTaskBy -eq $currEntityModifiedTaskBy.Value)
			{
				LogThis -msg "`t--> [SKIPPING] Original and New ""$global:annotationModifiedTaskByText"" are the same [Orginal: $($currEntityModifiedTaskBy.Value), New: $($row.LastTaskBy)]" -color "Red" -filename $of
			} else {
				if ($reportOnly)
				{
					LogThis -msg "`t--> [READONLY] New ""$global:annotationModifiedTaskByText"" would be set to [$($row.LastTaskBy)]" -color "Magenta" -filename $of
				} else {
					LogThis -msg "`t--> [UPDATING] New ""$global:annotationModifiedTaskByText"" will be set to [$($row.LastTaskBy)]" -color "Blue" -filename $of
					Set-Annotation -Entity $objEntity -CustomAttribute $global:annotationModifiedTaskByText -Value "$($row.LastTaskBy)"
				}
			}
		}  else {
			LogThis -msg "`t--> [SKIPPING] Cannot set ""$global:annotationModifiedTaskByText"" - Event details empty[$($row.LastTaskBy)]" -color "Red" -filename $of
		}
	} else {
		LogThis -msg "`t--> There are no Task Events events for this system" -color "Red" -filename $of
	}	
	
	$row.ScriptAction = "Updated"

	#exit
	#LogThis -msg $row
	#$row | Out-File -FilePath $of -Append 
	#Remove-Variable $row;
	if ($adjustedTimeCommission) {Remove-Variable adjustedTimeCommission}
	if ($adjustedModifiedDate) {Remove-Variable adjustedModifiedDate}
	if ($currEntityCommissionDate) { Remove-Variable currEntityCommissionDate }
	if ($currEntityCommissionBy) { Remove-Variable currEntityCommissionBy }		
	$row
}


LogThis -msg "Executing script $($MyInvocation.MyCommand.path)" -colour "green";
LogThis -msg "Current path is $($pwd.path)" -color "Yellow";

if (!$srvConnection -or ( ($srvconnection.GetType().Name -ne "VIServerImpl") -and ($srvconnection.GetType().Name -ne "Object[]") ) )
{ 
	LogThis -msg "NOT connected to vCenter $($srvconnection)" -colour "Yellow" -filename $of;
	$global:DefaultVIServerName = Read-Host "Enter virtual center server name"
	LogThis -msg "Connecting to virtual center server $global:DefaultVIServerName.." -filename $of
	$srvConnection = Connect-VIServer -Server $global:DefaultVIServerName
	$disconnectOnExist = $true;	
} else {
	$disconnectOnExist = $false;
	$global:DefaultVIServerName = $srvConnection.Name;
	LogThis -msg "Already connected to $($srvconnection)" -colour "green" -filename $of;
}

if ((Test-Path -path $logDir) -ne $true) {
	New-Item -type directory -Path $logDir
}





#################################
# MAIN
######################################



if ($reportOnly -eq $true)
{
	LogThis -msg "[READONLY MODE]" -color "Magenta" -filename $of
	#$overwrite = $false;
}

if ($overwrite -eq $false)
{
	LogThis -msg "[OVERWRITE MODE OFF]" -color "Magenta" -filename $of
} else {
	LogThis -msg "[OVERWRITE MODE ON]" -color "Blue" -filename $of
}
LogThis -msg "Search for Servers without a commissioned date or by status set " -color "Yellow" -filename $of

$report = $srvconnection | %{
	LogThis -msg "Searching on vcenter $($_.Name)..." -filename $of
	$global:DefaultVIServer = $_
	$eventMgr = Get-View $global:DefaultVIServer.ExtensionData.Content.EventManager
	#$eventMgr = Get-View EventManager
	$functionlogFile = $debugFile
	if ($functionlogFile)
	{
			$ofverbose = $true
	}
	$filename = ($($MyInvocation.MyCommand.Name)).TrimEnd('.ps1');
	LogThis -msg "$filename" -filename $of;
	if ($comment -eq "" ) {
		$of = $logDir + "\$filename-$($global:DefaultVIServer.Name).log"
		$csv = $logDir + "\$filename-$($global:DefaultVIServer.Name).csv"
	} else {
		$of = $logDir + "\"+$filename+"-"+$comment+".log"
		$csv = $logDir + "\"+$filename+"-"+$comment+".csv"
	}

	Write-Output "" > $of
	LogThis -msg "This script log to $of" -color "Yellow" -filename $of
	LogThis -msg "$(get-date)" -color "Yellow" -filename $of	
	#get key fields for COMMISSIONED DATE and COMMISSIONED BY attributes
	
	$global:annotationCommissionByField = Get-CustomAttribute -Server $global:DefaultVIServer  | ?{$_.Name -eq $global:annotationCommissionByText}
	if (!$annotationCommissionByField)
	{
		# set for all
		New-CustomAttribute -Name $global:annotationCommissionByText -Server $global:DefaultVIServer
		$global:annotationCommissionByField = Get-CustomAttribute -Server $global:DefaultVIServer  | ?{$_.Name -eq $global:annotationCommissionByText}
	}
	
	$global:annotationCommissionDateField = Get-CustomAttribute -Server $global:DefaultVIServer  | ?{$_.Name -eq $global:annotationCommissionDateText}
	if (!$global:annotationCommissionDateField)
	{
		New-CustomAttribute -Name $global:annotationCommissionDateText -Server $global:DefaultVIServer
		$global:annotationCommissionDateField = Get-CustomAttribute -Server $global:DefaultVIServer  | ?{$_.Name -eq $global:annotationCommissionDateText}
	}
	$global:annotationModifiedByTextField =  Get-CustomAttribute -Server $global:DefaultVIServer  | ?{$_.Name -eq $global:annotationModifiedByText}
	if (!$global:annotationModifiedByTextField)
	{
		New-CustomAttribute -Name $global:annotationModifiedByText -Server $global:DefaultVIServer
		$global:annotationModifiedByTextField =  Get-CustomAttribute -Server $global:DefaultVIServer  | ?{$_.Name -eq $global:annotationModifiedByText}
	}
	$global:annotationModifiedDateTextField =  Get-CustomAttribute -Server $global:DefaultVIServer  | ?{$_.Name -eq $global:annotationModifiedDateText}
	if (!$global:annotationModifiedDateTextField)
	{
		New-CustomAttribute -Name $global:annotationModifiedDateText -Server $global:DefaultVIServer
		$global:annotationModifiedDateTextField =  Get-CustomAttribute -Server $global:DefaultVIServer  | ?{$_.Name -eq $global:annotationModifiedDateText}
	}
	$global:annotationModifiedTaskTextField = Get-CustomAttribute -Server $global:DefaultVIServer  | ?{$_.Name -eq $global:annotationModifiedTaskText}
	if (!$global:annotationModifiedTaskTextField)
	{
		# set for all
		New-CustomAttribute -Name $global:annotationModifiedTaskText -Server $global:DefaultVIServer
		$global:annotationModifiedTaskTextField = Get-CustomAttribute -Server $global:DefaultVIServer  | ?{$_.Name -eq $global:annotationModifiedTaskText}
	}
	$global:annotationModifiedTaskDateTextField = Get-CustomAttribute -Server $global:DefaultVIServer  | ?{$_.Name -eq $global:annotationModifiedTaskDateText}
	if (!$global:annotationModifiedTaskDateTextField)
	{
		# set for all
		New-CustomAttribute -Name $global:annotationModifiedTaskDateText -Server $global:DefaultVIServer
		$global:annotationModifiedTaskDateTextField = Get-CustomAttribute -Server $global:DefaultVIServer  | ?{$_.Name -eq $global:annotationModifiedTaskDateText}
	}
	
	$global:annotationModifiedTaskByTextField = Get-CustomAttribute -Server $global:DefaultVIServer  | ?{$_.Name -eq $global:annotationModifiedTaskByText}
	if (!$global:annotationModifiedTaskByTextField)
	{
		# set for all
		New-CustomAttribute -Name $global:annotationModifiedTaskByText -Server $global:DefaultVIServer
		$global:annotationModifiedTaskByTextField = Get-CustomAttribute -Server $global:DefaultVIServer  | ?{$_.Name -eq $global:annotationModifiedTaskByText}
	}
	
	$global:annotationMacAddressTextField = Get-CustomAttribute -Server $global:DefaultVIServer  | ?{$_.Name -eq $global:annotationMacAddressText}
	if (!$global:annotationMacAddressTextField)
	{
		# set for all
		New-CustomAttribute -Name $global:annotationMacAddressText -Server $global:DefaultVIServer -TargetType VirtualMachine
		$global:annotationMacAddressTextField = Get-CustomAttribute -Server $global:DefaultVIServer  | ?{$_.Name -eq $global:annotationMacAddressText}
	}
	
	$global:annotationDeployedFromTemplateTextField = Get-CustomAttribute -Server $global:DefaultVIServer  | ?{$_.Name -eq $global:annotationDeployedFromTemplateText}
	if (!$global:annotationDeployedFromTemplateTextField)
	{
		# set for all
		New-CustomAttribute -Name $global:annotationDeployedFromTemplateText -Server $global:DefaultVIServer -TargetType VirtualMachine
		$global:annotationDeployedFromTemplateTextField = Get-CustomAttribute -Server $global:DefaultVIServer  | ?{$_.Name -eq $global:annotationDeployedFromTemplateText}
	}
	
	#$affectedVMs = $vms | sort Name | %{
	$row = @()
	LogThis -msg "Processing VMs " -color "Yellow" -filename $of	
	$index = 1
	$entities  = get-vm * -Server $global:DefaultVIServer
	$entities | sort Name | %{
		$entity = $_
		LogThis -msg "[$index/$($entities.Count)] Processing $($entity.ExtensionData.Moref.Type) $($entity.Name)" -color "Black" -background "Green" -filename $of -newLine $true
		#$row = ProcessEntities -objEntity $_ -objvCenter $global:DefaultVIServer -CreationEventTypes "VmCreatedEvent","VmClonedEvent","VmRegisteredEvent","VmDeployedEvent" -ModifiedEventTypes "VmReconfiguredEvent" -EventCategories "info"
		$row = ProcessEntities -objEntity $entity -objvCenter $global:DefaultVIServer -CreationEventTypes "VmCreatedEvent","VmClonedEvent","VmRegisteredEvent","VmDeployedEvent","VmBeingDeployedEvent" -ModifiedEventTypes "VmReconfiguredEvent","ExtendedEvent" # -EventCategories "info"
		$annotationMacAddress = $($entity.ExtensionData.CustomValue | ?{$_.key -eq $global:annotationMacAddressTextField.Key}).Value
		
		$newMacAddress +=  $entity.ExtensionData.Config.Hardware.Device | ?{$_.MacAddress} |%{
				$_.MacAddress
		}
		#Write-Host "$($entity.ExtensionData.CustomValue | ?{$_.key -eq $global:annotationMacAddressField.key}).Value	 annotationMacAddress = $annotationMacAddress, newMacAddress = $newMacAddress";
		if ($newMacAddress) {
			if ($annotationMacAddress -eq $newMacAddress)
			{
				LogThis -msg "`t--> [SKIPPING] Original and New ""$global:$annotationMacAddressText"" are the same [Orginal: $annotationMacAddress) New: $newMacAddress]" -color "Red" -filename $of
			} else {
				if ($reportOnly)
				{
					LogThis -msg "`t--> [READONLY] New ""$global:$annotationMacAddressText"" would be set to [$newMacAddress]" -color "Magenta" -filename $of
				} else {
					LogThis -msg "`t--> [UPDATING] New ""$global:$annotationMacAddressText"" will be set to [$newMacAddress]" -color "Blue" -filename $of
					Set-Annotation -Entity $entity -CustomAttribute $global:$annotationMacAddressText -Value "$newMacAddress"
				}
			}
		} else {
			LogThis -msg "`t--> [SKIPPING] Cannot set ""$global:$annotationMacAddressText"" - Event details empty[$newMacAddress]" -color "Red" -filename $of
		}
		Remove-Variable "annotationMacAddress"
		Remove-Variable "newMacAddress"
		$index++;
		$row
		LogThis -msg "" -color "Green" -filename $of
	}
	
	$index = 1
	LogThis -msg "Processing Hosts " -color "Yellow" -filename $of	
	$entities = get-vmhost * -Server $global:DefaultVIServer
	$entities | sort Name | %{
		LogThis -msg "[$index/$($entities.Count)] Processing $($_.ExtensionData.Moref.Type) $($_.Name)" -color "Green" -filename $of -newLine $true
		$row = ProcessEntities -objEntity $_ -objvCenter $global:DefaultVIServer -CreationEventTypes "HostAddedEvent"
		#-EventCategories "info" 
		#-MessageFilter "Task:"
		$index++;
		$row
		LogThis -msg "" -color "Green" -filename $of
	}
	
	#ClusterReconfiguredEvent
	#ClusterCreatedEvent
	#TaskEvent
	#AlarmStatusChangedEvent
	#AlarmActionTriggeredEvent
	#AlarmSnmpCompletedEvent
	#AlarmClearedEvent
	#ExtendedEvent
	#DrsEnabledEvent
	##DasEnabledEvent
	###ResourcePoolCreatedEvent
	#AlarmAcknowledgedEvent
	#InsufficientFailoverResourcesEvent
	#EventEx
	##FailoverLevelRestored
	#ResourcePoolDestroyedEvent
	#DasAdmissionControlDisabledEvent
	#DasAdmissionControlEnabledEvent
	#AlarmScriptFailedEvent
	#AlarmScriptCompleteEvent
	#DrsInvocationFailedEvent
	#DasDisabledEvent
	#HostMonitoringStateChangedEvent
	$index = 1
	LogThis -msg "Processing Hosts " -color "Yellow" -filename $of	
	$entities = get-cluster * -Server $global:DefaultVIServer
	$entities | sort Name | %{
		LogThis -msg "[$index/$($entities.Count)] Processing $($_.ExtensionData.Moref.Type) $($_.Name)" -color "Green" -filename $of -newLine $true
		$row = ProcessEntities -objEntity $_ -objvCenter $global:DefaultVIServer -CreationEventTypes "ClusterCreatedEvent" -ModifiedEventTypes "ClusterReconfiguredEvent"

		#-EventCategories "info" 
		#-MessageFilter "Task:"
		$index++;
		$row
	}
	
	LogThis -msg "$(Get-Date)" -color "Yellow" -filename $of
	LogThis -msg "Runtime Logs written to " -color "Yellow";
	
	if ($eventMgr) {Remove-Variable eventMgr}
	if ($disconnectOnExist)
	{
		Disconnect-VIServer $global:DefaultVIServer -force -Confirm:$false
	}
}


if ($reportOnly -eq $false)
{
	$report | Export-Csv $csv -NoTypeInformation
	if ($showDate) {
		LogThis -msg "" -color "Yellow" -filename $csv
		LogThis -msg "" -color "Yellow" -filename $csv
		LogThis -msg "Collected on $(get-date)" -color "Yellow" -filename $csv
	}
	LogThis -msg "CSV Logs written to $csv" -color "yellow" -filename $of;
}
