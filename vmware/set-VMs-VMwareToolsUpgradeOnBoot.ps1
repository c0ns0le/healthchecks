# This script edits the VM config to get VM to upgrade tools on boot 
# 
# Version : 0.2
#Author : 09/06/2010, by teiva.rodiere@gmail.com
# Syntax Example: .\set-VMs-VMwareToolsUpgradeOnBoot.ps1 -srvConnection $srvconnection -location "AUBNE-C-DVMWPROD" -readonly $false -upgradeAtPowerCycle $true -syncTimeWithHost $true
#
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[string]$location,[bool]$readonly=$true,[bool]$upgradeAtPowerCycle=$true,[bool]$syncTimeWithHost=$true)
$ErrorActionPreference = "SilentlyContinue"
Write-Host "Executing script $($MyInvocation.MyCommand.path)" -ForegroundColor  green;
Write-Host "Current path is $($pwd.path)" -ForegroundColor  yellow;

$disconnectOnExist = $true;

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

if ((Test-Path -path $logDir) -ne $true) {
	New-Item -type directory -Path $logDir
}

$allAllSettings = $false;
if ($upgradeAtPowerCycle -and $syncTimeWithHost)
{
	$allAllSettings = $true;
}

if ($srvConnection) 
{
    if ($location)
	{
		$vms = Get-VM -Server $srvConnection -Location $location
	} else {
		$vms = Get-VM -Server $srvConnection
	}
    $index = 1;
    $vms | %{
		$vm = $_
		
        Write-Output "Processing host $index of $($vms.Count) - $($vm.Name) ";
		
        $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
		$vmConfigSpec.Tools = New-Object VMware.Vim.ToolsConfigInfo
		
        if ($upgradeAtPowerCycle -or $allAllSettings)
        {
			$proposedPolicy = "upgradeAtPowerCycle"
			if ($vm.ExtensionData.Config.Tools.ToolsUpgradePolicy.ToString() -eq $proposedPolicy)
            {
				Write-Host "-> [SKIPPING] - Current policy = [$($_.ExtensionData.Config.Tools.ToolsUpgradePolicy)], Proposed = [$proposedPolicy] " -Foregroundcolor Green;
			} else {
            	write-Host "-> [UPDATING] - Current policy = [$($_.ExtensionData.Config.Tools.ToolsUpgradePolicy)], Proposed = [$proposedPolicy] " -Foregroundcolor Yellow            
				$vmConfigSpec.Tools.ToolsUpgradePolicy = $proposedPolicy
        	}
			Remove-Variable proposedPolicy
		}
		
		if ($syncTimeWithHost -or $allAllSettings)
		{
			$proposedPolicy = "true"
			if ($vm.ExtensionData.Config.Tools.SyncTimeWithHost -eq $proposedPolicy)
        	{
				Write-Host "-> [SKIPPING] - Current policy = [$($vm.ExtensionData.Config.Tools.SyncTimeWithHost)], Proposed = [$proposedPolicy] " -Foregroundcolor Green;
			} else {
				Write-Host "-> [UPDATING] - Current policy = [$($vm.ExtensionData.Config.Tools.SyncTimeWithHost)], Proposed = [$proposedPolicy] " -Foregroundcolor Yellow;
				$vmConfigSpec.Tools.syncTimeWithHost = $proposedPolicy
			}
			Remove-Variable proposedPolicy
		}
		
		# Time to execute it
		if ($readonly)
		{
			Write-Host "==> [READONLY] - Skipping the update" -ForegroundColor Red
		} else {
			Write-Host "[EXECUTING]" -ForegroundColor Blue
			if ($vmConfigSpec.Tools.syncTimeWithHost -or $vmConfigSpec.Tools.ToolsUpgradePolicy)
			{
				(Get-View $_.ID).ReconfigVM($vmConfigSpec)
			} else {
				Write-Host "--> Nothing to do because all specs are empty"
			}
		}
        $index++;
    } 
}