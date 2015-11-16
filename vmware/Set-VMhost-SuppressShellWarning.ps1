
# This script is going to run against all hosts in the location below
$location="Maintenance Dock" # or * or another name
$vcenter="vcenter"
$srvConnection = get-vc $vcenter
$esxHosts = Get-VMHost -Location $location -Server $srvConnection

if ($esxHosts)
{
    # Backup the configuration of ESX servers found in the location specified
    .\backupEsxiFirmware.ps1 -Location $location -backupDir ".\firmware-backups-maintenancedock" -srvConnection $srvConnection

    #RFC000000039489
    #Enable SSH and Supress Shell Warning
    $esxHosts | Set-VMHostAdvancedConfiguration -VMHost $_ -Name UserVars.SuppressShellWarning -Value 1

} else {
    write-output "No ESX/ESXi hosts found at location ""$location"" in virtual infrastructure ""$vcenter""";
}