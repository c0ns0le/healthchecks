# This scripts exports a list of VMs with some specs (short list) but mainly for their Contacts
# Last updated: 31 March 2011
# Author: teiva.rodiere-at-gmail.com
#
param(
	[object]$srvConnection,
	[string]$logDir="output",
	[string]$comment="",
	[bool]$showDate=$false,
	[bool]$returnReportOnly=$false,
	[bool]$showExtra=$true,
	[string]$configFile="E:\scripts\customerEnvironmentSettings-ALL.ini"
	)
Write-Host "Executing script $($MyInvocation.MyCommand.path)" -ForegroundColor  green;
Write-Host "Current path is $($pwd.path)" -ForegroundColor  yellow;

$disconnectOnExist = $false;

if (!$srvConnection -or ( ($srvconnection.GetType().Name -ne "VIServerImpl") -and ($srvconnection.GetType().Name -ne "Object[]") ) )
{ 
    Write-Host "Current value of srvConnection is $srvConnection"
    Write-Host "Type of srvConnection is $($srvConnection.GetType())"
	$vcenterName = Read-Host "Enter virtual center server name"
	Write-Host "Connecting to virtual center server $vcenterName.."
	$srvConnection = Connect-VIServer -Server $vcenterName
	$disconnectOnExist = $true;	
} else {
  Write-Host "Current value of srvConnection is $srvConnection"
    Write-Host "Type of srvConnection is $($srvConnection.GetType())"
	$disconnectOnExist = $false;
	$vcenterName = $srvConnection.Name;
}

if ((Test-Path -path $logDir) -ne $true) {
	New-Item -type directory -Path $logDir
}


if ($srvConnection.Count)
{
	$vcenterName="multiple"
}

$runtime="$(date -f dd-MM-yyyy)"
$filename = ($($MyInvocation.MyCommand.Name)).TrimEnd('.ps1');
Write-Host "$filename";
if ($comment -eq "" ) {
	$of = $logDir + "\"+$runtime+"_"+$vcenterName.ToUpper()+"_"+$filename+".csv"
} else {
	$of = $logDir + "\"+$runtime+"_"+$vcenterName.ToUpper()+"_"+$filename+"-"+$comment+".csv"
}
Write-Host "This script log to " $of -ForegroundColor $global:colours.Information 


$run1Report =  $srvConnection | %{
    $vcenterName = $_.Name
    if ($showOnlyTemplates) 
    {
        Write-Host "Enumerating Virtual Machines Templates only from vCenter $_ inventory..." -ForegroundColor $global:colours.Error
        $vms = Get-Template -Server $_ | Sort-Object Name
        
        #Write-Host "Enumerating Virtual Machines Templates Views from vCenter $_ inventory..." -ForegroundColor $global:colours.Error
        #$vmsViews = $vms | Get-View;
    } else {
        Write-Host "Enumerating Virtual Machines from vCenter $_ inventory..." -ForegroundColor $global:colours.Error
        $vms = Get-VM -Server $_ | Sort-Object Name 
        
        #Write-Host "Enumerating Virtual Machines Views from vCenter $_ inventory..." -ForegroundColor $global:colours.Error
        #$vmsViews = $vms | Get-View;
    }
    
    if ($vms) 
    {
		$index=1;
        $vms | %{
			$vm = $_;
            #$vmView = $vmsView | ?{$_.Name -eq $vm.Name}
			Write-Host "$index/$($vms.Count) :- $vm" -ForegroundColor $global:colours.Information;
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
			if ($configFile)
			{
				$ifConfig=Import-Csv $configFile
				$currentConfig = $ifConfig | ?{$_.vCenterSrvName -eq $vcenterName}
				#Write-Host "[$currentConfig]" -BackgroundColor $global:colours.Error -ForegroundColor $global:colours.Information
				
				$GuestConfig | Add-Member -Type NoteProperty -Name "Environment" -Value $currentConfig.MoreInfo
			} else {
				$GuestConfig | Add-Member -Type NoteProperty -Name "ManagementServer" -Value $vcenterName.ToUpper()
			}
			
			
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


if ($returnReportOnly)
{
	return $serverListReport | sort -Property Name
} else {
	Write-Output $serverListReport | sort -Property Name | Export-Csv $of -NoTypeInformation
	Write-Output "" >> $of
	Write-Output "" >> $of
	Write-Output "Collected on $(get-date)" >> $of

	Write-Host "Logs written to " $of -ForegroundColor  yellow;
}

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}