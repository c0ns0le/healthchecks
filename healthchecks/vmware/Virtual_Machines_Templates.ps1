# Exports resource pools configurations and runtime information
# Version : 0.1
#Author : 8/0632011, by teiva.rodiere-at-gmail.com
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="")
LogThis -msg "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global




# Want to initialise the module and blurb using this 1 function




LogThis -msg "Enumerating templates.." -ForegroundColor $global:colours.Highlight
$run1Report = $srvConnection | %{
    Get-Template -Server $_.Name | Get-View | %{
    	LogThis -msg "Processing $($_.Name)" -ForegroundColor $global:colours.Information;
    	$GuestConfig = "" | Select-Object "Template";
    	$GuestConfig.Template = $_.Name;
    	$GuestConfig | Add-Member -Type NoteProperty -Name "NumCPU" -Value  $_.Config.Hardware.NumCPU;
    	$GuestConfig | Add-Member -Type NoteProperty -Name "MemoryMB" -Value $_.Config.Hardware.MemoryMB ;
    	$GuestConfig | Add-Member -Type NoteProperty -Name "NICCount" -Value  $_.Guest.Net.Count;
    	$GuestConfig | Add-Member -Type NoteProperty -Name "GuestFullName" -Value  $_.Config.GuestFullName;
    	$GuestConfig | Add-Member -Type NoteProperty -Name "GuestType" -Value $_.Guest.GuestFullName;		
    	$GuestConfig | Add-Member -Type NoteProperty -Name "PowerState" -Value $_.Runtime.PowerState;
    	$GuestConfig | Add-Member -Type NoteProperty -Name "LastBooted" -Value $_.Runtime.BootTime;
    	$GuestConfig | Add-Member -Type NoteProperty -Name "GuestHostname" -Value $_.Guest.HostName;
    	$GuestConfig | Add-Member -Type NoteProperty -Name "IpAddressPrimary" -Value $_.Guest.IpAddress;
    	$GuestConfig | Add-Member -Type NoteProperty -Name "NIC_Connected" -Value "$($_.Guest.net).Connected";
    	$GuestConfig | Add-Member -Type NoteProperty -Name "PortGroup" -Value  "$(($_.Config.Hardware.Device | ?{$_.key -match 4000}).DeviceInfo.Summary)";
    	$GuestConfig | Add-Member -Type NoteProperty -Name "GuestState" -Value $_.Guest.GuestState;
    	$GuestConfig | Add-Member -Type NoteProperty -Name "Hostname" -Value $_.Guest.HostName;
    	$GuestConfig | Add-Member -Type NoteProperty -Name "ToolsStatus" -Value $_.Guest.ToolsStatus;
    	$GuestConfig | Add-Member -Type NoteProperty -Name "ToolsVersion" -Value  $_.Config.Tools.ToolsVersion;
        $GuestConfig | Add-Member -Type NoteProperty -Name "ToolsUpgradePolicy" -Value $_.Config.Tools.ToolsUpgradePolicy;
    	$GuestConfig | Add-Member -Type NoteProperty -Name "SyncTimeWithHost" -Value $_.Config.Tools.SyncTimeWithHost;
    	$GuestConfig | Add-Member -Type NoteProperty -Name "BootTime" -Value  $_.Runtime.BootTime;
    	$GuestConfig | Add-Member -Type NoteProperty -Name "LastModifiedTime" -Value  $_.Config.Modified;
    	$GuestConfig | Add-Member -Type NoteProperty -Name "VMXLocation" -Value $_.Summary.Config.VmPathName;

    	#LogThis -msg $GuestConfig;
    	$GuestConfig | Add-Member -Type NoteProperty -Name "vCenter" -Value $_.Name;
    	$GuestConfig;
    }
}

# Fix the object array, ensure all objects within the 
# array contain the same members (required for Format-Table / Export-CSV)
$loop = 1;
$continue = $true;
LogThis -msg "-> Fixing the object arrays <-" -ForegroundColor Magenta
while ($continue)
{
	LogThis -msg "Loop index: $loop";
	$continue = $false;
	
	$Members = $run1Report | Select-Object `
	@{n='MemberCount';e={ ($_ | Get-Member).Count }}, `
	@{n='Members';e={ $_.PsObject.Properties | %{ $_.Name } }}
	$AllMembers = ($Members | Sort-Object MemberCount -Descending)[0].Members
	
	$Report = $run1Report | %{
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
	
	$run1Report = $Report;
	$loop++;
}

ExportCSV -table $Report

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
	LogThis -msg "-> Disconnected from $srvConnection.Name <-" -ForegroundColor Magenta
}

LogThis -msg "Log file written to $of" -ForegroundColor $global:colours.Information