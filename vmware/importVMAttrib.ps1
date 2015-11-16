#Description: 
#Version : 0.2
#Updated : 30th Sept 2009
#Author  : teiva.rodiere@gmail.com
# Syntax : script.ps1 if.csv
#	$if: input file in CSV format, comma delimited
#    input file format: Name,Notes,<custom attributes>
#   	Name = VM Name
#		Notes = Although a field but not a custom attribute, needs to be there 
#		<custom attibutes> = a list of custom attributes available from virtual center
# Examples
# .\importVMAttrib.ps1 -srvConnection $srvconnection -if ".\audit-21-May2013.csv"  -readonly $true
# .\importVMAttrib.ps1 -srvConnection $srvconnection -if ".\audit-21-May2013.csv"  -readonly $false
# .\importVMAttrib.ps1 -srvConnection $srvconnection -if ".\audit-21-May2013.csv"  -readonly $false -canBlankFields $true
#
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[string]$vmName="",[bool]$verbose=$true,[string]$if="",[bool]$readonly=$true,[bool]$canBlankFields=$false,[bool]$overRideVcenter=$true,[bool]$autocontinue=$false)

function VerboseToScreen([string]$msg,[string]$color="White")
{
	if ($verbose) {
		Write-Host $msg -ForegroundColor $color
	}
}

VerboseToScreen "Executing script $($MyInvocation.MyCommand.path)" "Green";
VerboseToScreen "Current path is $($pwd.path)" "yellow"

$disconnectOnExist = $true;

if (!$srvConnection)
{ 
	$vcenterName = Read-Host "Enter virtual center server name"
	VerboseToScreen "Connecting to virtual center server $vcenterName..", "Yellow"
	$srvConnection = Connect-VIServer -Server $vcenterName
	$disconnectOnExist = $true;	
} else {
	$disconnectOnExist = $false;
	$vcenterName = $srvConnection.Name;
	VerboseToScreen "Here" "Red"
}
if (!$if)
{
	VerboseToScreen "No input file specified" "Red"
	VerboseToScreen "Run ""./doumentGuests.ps1"" to export existing VM details (and as a backup), then make the changes to any Annotation to re-import back" "Red"
	exit;
}

if ((Test-Path -path $logDir) -ne $true) {
	New-Item -type directory -Path $logDir
}

$filename = ($($MyInvocation.MyCommand.Name)).TrimEnd('.ps1');

VerboseToScreen "$filename";

if ($comment -eq "" ) {
	$of = $logDir + "\"+$filename+"-"+$vcenterName+".csv"
} else {
	$of = $logDir + "\"+$filename+"-"+$comment+".csv"
}


VerboseToScreen "This script log to $of" "Yellow"

VerboseToScreen  "Enumerating clusters in $srvConnection..."

$date = get-date -f "dd-mm-yyyy"
$startTime = get-date
$1VRU_CPU=1
$1VRU_MEMORY=1024

$backFilename = $logDir+"\exportVM_Attributes$date.csv"
# Main
# List all vailable attributes


# !$readonly means that you want to make changes
if (!$readonly) {
	if (!$autocontinue)
	{
		$answer = (Read-Host "THIS SCRIPT WILL MAKE PERMANENT CHANGES TO CUSTOM ATTRIBUTES. Do you want to run this script? (y/n)") -match "y"
		if ($answer -eq "y")
		{
			$proceed = $true;
		} else 
		{
			VerboseToScreen "User choice to leave the script" "cyan"; 
			$proceed = $false;
		}
	} else{
		$proceed = $true
	}
} else {
	# I will be running in read only mode so no need to check and prompt
	$proceed = $true
}

if ($proceed) {
	VerboseToScreen "Loading vCenter Custom Attributes..." "Green"
	$customAttributes = Get-CustomAttribute -Server $srvconnection #| ?{$_.TargetType -ne "VMhost"}
	

	if ($vmName)
	{
		VerboseToScreen "Reading in input CSV File $if and filtering the list to only select VM with name ""$vmName""..." "red"
		$cmdb = Import-Csv $if | ?{$_.Name -eq $vmName} | Select-Object -Property * | Sort-Object "Name"
	} else 
	{
		VerboseToScreen "Reading ininput CSV File $if (No VM Filtering required)..." "red"
		$cmdb = Import-Csv $if | Select-Object -Property * | Sort-Object "Name" 
	}
	if ($cmdb)
	{
		VerboseToScreen "Identifying Table Headers.." "red"
		$cmdbColumnsCount = ($cmdb | get-member -type NoteProperty).Count
		$cmdbColumns = $cmdb | get-member -type NoteProperty | Select-Object -property Name
		$cmdbRows = $cmdb.Count
		
	} else {
		VerboseToScreen "No Data found in INPUT File" "Red"
		exit
	}
	# Validate that all colums in the CMDB to import contain valid fields
	if (($cmdbColumns.Count - 2) -ne $customAttributes.Count) {
		VerboseToScreen "+" "cyan"
		VerboseToScreen "BE AWARE that additional Custom Attributes exist in vCenter which are no present in the input attachment." "Cyan"
		VerboseToScreen "Only attributes that match in virtualcenter will be updated" "cyan"
		#$answer = Read-Host "Do you want proceed? (y/n) "
		$answer = "y"
	}
	
	if ($answer -match "y") {
	# Backup current Attributes List
		$row = 0;
		########################################################
		# Process only the VM(s) found in the Input CSV
		########################################################
		$index = 1;
		
		
		
		$cmdb | %{
			$ci = $_ # The whole Non VM CI
			
			VerboseToScreen "[$index/$cmdbRows] VM $($ci.Name).." "Red"
			$vm = Get-VM -Name $ci.Name -Server $srvconnection
			# If a valid VM, progress
			if ($vm) 
			{
				$vmValues = $vm.ExtensionData.Value
				Write-Host " ==== >> $vmValues.Count << ===="
				#
				# Process all columns for this server
				#
				#Write-Output $vmValues
				#
				$cmdbColumns | %{
					$colName = $_
					# Is this column a valid custom attribute in this vCenter ?
			
					$attribute = $customAttributes | ?{$_.Name.ToLower() -eq $colName.Name.ToLower()}
					
					#Write-Host " ===>> $($attribute.GetType()) << ==="
					#VerboseToScreen "colName = $colName, attribute = $attribute" "Green"
					# if a valid custom attribute, proceed
					if ($attribute)
					{
						$attribName = $attribute.Name
						$attribKey = $attribute.Key
						
						# Set the new Value
						$newAttributeValue = $ci.$attribName
						$newAttributeKey = $attribKey
						
						# get the old values just in case
						$oldVMAttributeValue = ($vmValues | ?{$_.Key -eq $attribKey}).Value
						#Write-Host "=== >> $oldVMAttributeValue << ====" -BackgroundColor Red -ForegroundColor Yellow
						#if ($canBlankFields)
						#{	
						#	if ($oldVMAttributeValue -ne "" -and $newAttributeValue -eq "")
						#	{
						#		VerboseToScreen "--> You are going blanking a value" "red"
						#		VerboseToScreen "exec cmd: Set-CustomField -Entity $($_.Name) -Name $($column.Name) -Value $($row.$($($column.Name)))"  "Yellow"
						#	}
						#}
#						VerboseToScreen "--> Beware Attibute name [ $attribName ]: old value = [$oldVMAttributeValue] and new value = [$newAttributeValue]"  "Yellow"
						if ($readonly)
						{
							if (($oldVMAttributeValue -ne $newAttributeValue) -and ($newAttributeValue -eq "") -and ($canBlankFields -eq $false))
							{
								VerboseToScreen "   --> New Value is Empty compare with old value (use parameter '-canBlankFields' to force -- Skipping" "Green"
								VerboseToScreen "      --> Attibute = [ $attribName ], old value = [$oldVMAttributeValue], new value = [$newAttributeValue] -- Skipping"  "Green"
							} elseif ($oldVMAttributeValue -eq $newAttributeValue)
							{
								VerboseToScreen "   --> Both new and old values are the same -- Skipping" "Blue"
								VerboseToScreen "      --> Attibute = [ $attribName ], old value = [$oldVMAttributeValue], new value = [$newAttributeValue] -- Skipping"  "Blue"
							} else {
								VerboseToScreen "   exec cmd: Set-CustomField -Entity $($vm.Name) -Name ""$attribName"" -Value ""$newAttributeValue"""  "Yellow"
							}
							
						} else {						
							if (($oldVMAttributeValue -ne $newAttributeValue) -and ($newAttributeValue -eq "") -and ($canBlankFields -eq $false))
							{
								VerboseToScreen "   --> New Value is Empty compare with old value (use parameter '-canBlankFields' to force -- Skipping" "Green"
								VerboseToScreen "      --> Attibute = [ $attribName ], old value = [$oldVMAttributeValue], new value = [$newAttributeValue] -- Skipping"  "Green"
							} elseif ($oldVMAttributeValue -eq $newAttributeValue)
							{
								VerboseToScreen "   --> Both new and old values are the same -- Skipping" "Blue"
								VerboseToScreen "      --> Attibute = [ $attribName ], old value = [$oldVMAttributeValue], new value = [$newAttributeValue] -- Skipping"  "Blue"
							} else {
								VerboseToScreen "   exec cmd: Set-CustomField -Entity $($vm.Name) -Name ""$attribName"" -Value ""$newAttributeValue"""  "Yellow"
								Set-CustomField -Entity $vm.Name -Name "$attribName" -Value "$newAttributeValue"

							}
						}
					} else {
						VerboseToScreen "   ---> Customed attribute $colName not found on this vCenter -- skipping" "Red"
						$attribName = $false
						$attribKey = $false
						
						# Set the new Value
						$newAttributeValue = $false
						$newAttributeKey = $false
						
						# get the old values just in case
						$oldVMAttributeValue = $false
					}
				}
			} else {
				VerboseToScreen "---> Not a valid VM -- skipping" "Red"
			}
			$index++;
		}
	} else {
		VerboseToScreen "User canceled the import." "Cyan"
		VerboseToScreen "Do you want to view all virtual center custom attributes " "Cyan"
		if( (Read-Host "Proceed ? (y/n)") -match "y") {
			$allFields = "" | Select-Object Name,Notes
			foreach ($field in $validFields) {
				$allFields | Add-Member -Type NoteProperty -Name $field.Name -Value ""
			}
			Write-Output $allFields 
		}
	}
} else { VerboseToScreen "User canceled utility. Exiting.." "Cyan" }

VerboseToScreen "+"
VerboseToScreen "Script started at $startTime"
VerboseToScreen "Script completed at $(get-Date))"

if ($disconnectOnExist)
{
	Disconnect-VIServer $srvconnection
}