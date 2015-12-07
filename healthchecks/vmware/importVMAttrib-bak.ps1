#Description: 
#Version : 0.2
#Updated : 30th Sept 2009
#Author  : teiva.rodiere-at-gmail.com
# Syntax : script.ps1 if.csv
#	$if: input file in CSV format, comma delimited
#    input file format: Name,Notes,<custom attributes>
#   	Name = VM Name
#		Notes = Although a field but not a custom attribute, needs to be there 
#		<custom attibutes> = a list of custom attributes available from virtual center
#

$vcenter = Read-Host "Enter virtualcenter Hostname"

Connect-VIServer -server $vcenter

$date = get-date -f "dd-mm-yyyy"
$startTime = get-date
$backFilename = ".\exportVM_Attributes$date.csv"
$SyntaxTest = "Syntax: .\importVMAttrib.ps1 input_file_csv"

$1VRU_CPU=1
$1VRU_MEMORY=1024

# Main
# List all vailable attributes
$if = $args[0] #".\vmattributes.csv"

Write-Host "I recommend running documentGuests.ps1 before proceeding to backup all attributes"  -ForegroundColor cyan 
if ((Read-Host "Do you want to run this script anyway? (y/n)") -match "y") { 	
	Write-Host "+" -ForegroundColor cyan 
	Write-Host "Reading in input file " $if "..." -ForegroundColor red 
	$cmdb = Import-Csv $if | Select-Object -Property * | Sort-Object "Name" 
	Write-Host "Identifying Table Headers.." -ForegroundColor red
	$cmdbColumsCount = ($cmdb | get-member -type NoteProperty).Count
	$cmdbColums = $cmdb | get-member -type NoteProperty | Select-Object -property Name
	$cmdbRows = $cmdb.Count
	
	Write-Host "Loading Infrastructure Custom Attributes..." -ForegroundColor red
	$validFields  = (Get-VM BNEVCM01 | Get-View).AvailableField | Select-Object -Property Name
	$fieldsCount = $validFields
	
	#$correctFields = $validFields.ToString()
	
	# Validate that all colums in the CMDB to import contain valid fields
	if (($cmdbColumsCount - 2) -ne $validFields.Count) {
		Write-Host "+"  -ForegroundColor cyan
		Write-Host "There are additional columns or may be missing colums in the attachment." -ForegroundColor cyan
		Write-Host "Only attributes that match in virtualcenter will be updated" -ForegroundColor cyan
		$answer = Read-Host "Do you want proceed? (y/n) "
	}
	
	if ($answer -match "y") {
	# Backup current Attributes List
		$row = 0;
		foreach ($ci in $cmdb) {
			Write-Host "+"  -ForegroundColor cyan
			Write-Host "Loading VM " + $ci.Name + "for processing.." -ForegroundColor red
			Get-VM -Name $ci.Name | Get-View | Sort-Object $_.Name | %{
				$vmConfig = "" | Select-Object "Name"
				$vmConfig.Name = $ci.Name	
				# Backup Custom Attributes
				foreach ($row in $ci) {
					foreach ($column in $cmdbColums) {
						$fieldFound = $false
						for ($i = 0; $i -le $validFields.Count; $i++) { 
							if (($validFields[$i]).Name -contains $column.Name) {
								#Write-Host ($validFields[$i]).Name; 
								$fieldFound = $true
								if ($column.Name -eq "Application")
								{
									Write-Host exec cmd: Set-CustomField -Entity $_.Name -Name $column.Name -Value $row.$($column.Name)  -ForegroundColor yellow
									#Set-CustomField -Entity $_.Name -Name $column.Name -Value $row.$($column.Name)
								} else {
								if ($column.Name -eq "VRU-C") {
									Write-Host exec cmd: Set-CustomField -Entity $_.Name -Name $column.Name -Value ([math]::ROUND($_.Config.Hardware.NumCPU * $1VRU_CPU))  -ForegroundColor yellow
									#Set-CustomField -Entity $_.Name -Name $column.Name -Value ([math]::ROUND($_.Config.Hardware.NumCPU * $1VRU_CPU))
								} elseif ($column.Name -eq "VRU-M") {
									Write-Host exec cmd: Set-CustomField -Entity $_.Name -Name $column.Name -Value ([math]::ROUND($_.Config.Hardware.MemoryMB / $1VRU_MEMORY))  -ForegroundColor yellow
									#Set-CustomField -Entity $_.Name -Name $column.Name -Value ([math]::ROUND($_.Config.Hardware.MemoryMB / $1VRU_MEMORY))
								} elseif ($column.Name -eq "Veeam.ems_node") {
									Write-Host exec cmd: Set-CustomField -Entity $_.Name -Name $column.Name -Value $_.Guest.Hostname  -ForegroundColor yellow
									#Set-CustomField -Entity $_.Name -Name $column.Name -Value $_.Guest.Hostname
								} elseif ($column.Name -eq "Name"){ 
									# do nothing
								} else {
									#if ($row.$($column.Name))
									#{
										Write-Host exec cmd: Set-CustomField -Entity $_.Name -Name $column.Name -Value $row.$($column.Name)  -ForegroundColor yellow
										#Set-CustomField -Entity $_.Name -Name $column.Name -Value $row.$($column.Name)
									#}
								}
								}
							} 
						}
					}
				} 
			}
		}
	} else {
		Write-Host "User canceled the import."    -ForegroundColor cyan
		Write-Host "Do you want to view all virtual center custom attributes " -ForegroundColor cyan
		if( (Read-Host "Proceed ? (y/n)") -match "y") {
			$allFields = "" | Select-Object Name,Notes
			foreach ($field in $validFields) {
				$allFields | Add-Member -Type NoteProperty -Name $field.Name -Value ""
			}
			Write-Output $allFields 
		}
	}
} else { Write-Host "User canceled utility. Exiting.." -ForegroundColor cyan }

Write-Host "+"
Write-Host "Script started at "  $startTime
Write-Host "Script completed at " (get-Date)

Disconnect-VIServer $vcenter