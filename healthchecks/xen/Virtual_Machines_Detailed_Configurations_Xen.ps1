# Exports Virtual Machine Details from Xen
# Version : 0.1
#Author : 18/03/2015, by teiva.rodiere@gmail.com
param(
		[object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$includeTemplates=$false,
		[bool]$skipEvents=$true,[bool]$verbose=$false,
		[int]$numsamples=([int]::MaxValue),[int]$numPastDays=7,
		[int]$sampleIntevalsMinutes=5,
		[PSCredential]$credentials)
logThis -msg "Importing Module gmsTeivaModules.psm1 (force)"
Import-Module -Name ..\vmware\gmsTeivaModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name XenServer -Value $srvConnection -Scope Global
$global:logfile
$global:outputCSV

# Want to initialise the module and blurb using this 1 function
xen_InitialiseModule


# TO REMOVE WHEN INTEGRATING INTO REST OF THE SCRIPTS
$srv = "10.20.8.184" # (xenadma)

$credentials = ..\vmware\Get-myCredentials.ps1 -User root -SecureFileLocation
# Disconnect any existing session 
Get-XenSession | Disconnect-XenServer
$session  = Connect-XenServer -Server $srv -Cred $credentials -SetDefaultSession -Passthru
#$xenmaster = xen_get_master
if ($includeTemplates)
{
	$vms = get-xenvm
} else {
	$vms = get-xenvm | ?{!$_.is_a_template}
}


$index=1;
 $Report =  $vms | %{
	$vm = $_;
	#Write-Host "Processing $index of $($vms.Count) :- $($vm.name_label)" -ForegroundColor Yellow;
    #$vmView = $vmsView | ?{$_.Name -eq $vm.Name}
	logThis -msg "Processing $index of $($vms.Count) :- $vm" -ForegroundColor Yellow;
	$vmConfig = "" | Select-Object Name; 
	$vmConfig.Name = $vm.name_label;
	if ($vBlockDevices) {remove-variable vBlockDevices}
	if ($vDiskImages) {remove-variable vDiskImages}
	if ($diskSizes) {remove-variable diskSizes}
	if ($vm.VBDs)
	{
		Write-Host "`t-> $($vm.VBDs.Count) Block Devices found"
		$vBlockDevices = $vm.VBDs | Get-XenVBD | ?{$_.type -eq "Disk"}
		if ($vBlockDevices)
		{
			Write-Host "`t`t-> $($vBlockDevices.Count) of Type Disks"
			if ($vBlockDevices.Count -gt 1)
			{	
				$vDiskImages = $vBlockDevices | %{ Get-XenVDI $_.VDI }
			} else {
				$vDiskImages= Get-XenVDI $vBlockDevices.VDI
			}
			$diskCount = $vDiskImages.Count
			$vdiskSizes = [math]::round($($vDiskImages | measure -Property virtual_size -sum).Sum / 1gb,2)
			$pdiskSizes = [math]::round($($vDiskImages | measure -Property physical_utilisation -sum).Sum / 1gb,2)
		} else {
			Write-Host "`t-> No disks VBDs of type Disk found"
		}
	} else {
		Write-Host "`t-> No VBDs found (disks or CDs)"
		$diskCount = 0
	}
	
	$vmView = Get-XenVMProperty -VM $vm -XenProperty GuestMetrics
    $vmConfig | Add-Member -Type NoteProperty -Name "IsTemplate" -Value  $vm.is_a_template
	$vmConfig | Add-Member -Type NoteProperty -Name "State" -Value  $vm.power_state
	$vmConfig | Add-Member -Type NoteProperty -Name "Disks" -Value  $diskCount
	
	#$vmConfig | Add-Member -Type NoteProperty -Name "Virtual Size GB" -Value  $vdiskSizes
	$vmConfig | Add-Member -Type NoteProperty -Name "Size GB" -Value  ("{0:n2}" -f $pdiskSizes)
	$vmConfig | Add-Member -Type NoteProperty -Name "Memory GB" -Value  ("{0:n2}" -f $([math]::round( ($vm.Memory_Target) / 1gb, 2)))
	$vmConfig | Add-Member -Type NoteProperty -Name "CPU" -Value  $vm.VCPUs_max
	$vmConfig | Add-Member -Type NoteProperty -Name "IP Addresses" -Value $($([string]$($vmView.networks | select Values).Values).Replace(' ','|'))
	$vmConfig | Add-Member -Type NoteProperty -Name "MAC Addresses" -Value ($([string]$($vm.VIFs | get-xenvif | select MAC).MAC).Replace(' ','|'))
	$vmConfig | Add-Member -Type NoteProperty -Name "Port Groups" -Value ($([string]$($vm.VIFs | get-xenvif | select -Property Network  | %{ Get-XenNetwork -ref $_.network} | select name_label).name_label).Replace(' ','|'))
		
	$os = "";
	if ($vmView)
	{		
		$os,$boot,$deviceid=$vmView.os_version.name.Split('|')
	}
	
	$vmConfig | Add-Member -Type NoteProperty -Name "OS" -Value $os
	logThis -msg $vmConfig
	Write-Output $vmConfig 
	$index++
	Remove-Variable vmConfig
	Remove-Variable vmView
}

# Fix the object array, ensure all objects within the 
# array contain the same members (required for Format-Table / Export-CSV)
$loop = 1;
$continue = $true;
logThis -msg "-> Fixing the object arrays <-" -ForegroundColor Magenta
while ($continue)
{
	logThis -msg "Loop index: " $loop;
	$continue = $false;
	
	$Members = $Report | Select-Object `
	@{n='MemberCount';e={ ($_ | Get-Member).Count }}, `
	@{n='Members';e={ $_.PsObject.Properties | %{ $_.Name } }}
	$AllMembers = ($Members | Sort-Object MemberCount -Descending)[0].Members
	
	$tmpReport = $Report | %{
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
	
	$Report = $tmpReport;
	$loop++;
}

ExportCSV -table $Report
launchReport
#$of = ".\output\srg-vms2.csv"
#$Report | Export-Csv -NoTypeInformation $of


logThis -msg "Log file written to $of" -ForegroundColor Yellow