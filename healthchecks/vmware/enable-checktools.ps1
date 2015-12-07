## this script edits the VM config to get VM to upgrade tools on boot and to synch times.
#$vmConfigSpec.Tools.syncTimeWithHost = "true"

$ErrorActionPreference = "SilentlyContinue"
connect-viserver -server bnevcm01 

get-vm * -Location ELLIPSE_ASP_CLU | foreach-object {
$vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
$vmConfigSpec.Tools = New-Object VMware.Vim.ToolsConfigInfo
$vmConfigSpec.Tools.ToolsUpgradePolicy = "UpgradeAtPowerCycle"
(Get-View $_.ID).ReconfigVM($vmConfigSpec)
} 

get-vm * -Location CORP_PRD_CLU | foreach-object {
$vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
$vmConfigSpec.Tools = New-Object VMware.Vim.ToolsConfigInfo
$vmConfigSpec.Tools.ToolsUpgradePolicy = "UpgradeAtPowerCycle"
(Get-View $_.ID).ReconfigVM($vmConfigSpec)
} 

get-vm * -Location CORP_CLU | foreach-object {
$vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
$vmConfigSpec.Tools = New-Object VMware.Vim.ToolsConfigInfo
$vmConfigSpec.Tools.ToolsUpgradePolicy = "UpgradeAtPowerCycle"
(Get-View $_.ID).ReconfigVM($vmConfigSpec)
} 



get-vm * -Location MINCOM_AXIS | foreach-object {
$vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
$vmConfigSpec.Tools = New-Object VMware.Vim.ToolsConfigInfo
$vmConfigSpec.Tools.ToolsUpgradePolicy = "UpgradeAtPowerCycle"
$vmConfigSpec.Tools.syncTimeWithHost = "true"
(Get-View $_.ID).ReconfigVM($vmConfigSpec)
} 