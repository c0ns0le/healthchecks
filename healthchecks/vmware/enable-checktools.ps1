## this script edits the VM config to get VM to upgrade tools on boot and to synch times.
#$vmConfigSpec.Tools.syncTimeWithHost = "true"

$ErrorActionPreference = "SilentlyContinue"
$location="Maintenance Dock"
get-vm * -Location $location -server $srvconnection| foreach-object {
$vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
$vmConfigSpec.Tools = New-Object VMware.Vim.ToolsConfigInfo
$vmConfigSpec.Tools.ToolsUpgradePolicy = "UpgradeAtPowerCycle"
$vmConfigSpec.Tools.syncTimeWithHost = "true"
(Get-View $_.ID).ReconfigVM($vmConfigSpec)
} 