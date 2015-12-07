# Helps admin find a given virtual machine within multiple VirtualCenter servers and shows it's location
#Version : 0.1
#Updated : 11th Nov 2009
#Author  : teiva.rodiere-at-gmail.com 
# Syntaxt: .\findVM.ps1 NAME1
# Syntaxt for multiple VMs: .\findVM.ps1 NAME1 NAME2 NAME3
# OUtput: <VMNAME1> found on vCenter server <Servername>

Add-pssnapin VMware.VimAutomation.Core
Set-ExecutionPolicy Unrestricted
Clear-Host
$of="$($env:temp)\findVM-results.txt"

if (test-path $of)
{
	remove-item -path $of -force
}

if ($args.Count -eq 0) {
	Write-Host "Enter a VM or a list of VMs to search on customer infrastructures" -foreground Green
	Write-Output "Syntax/Examples: "
	Write-Host ".\findVM.ps1 VMNAME" -foreground Green
	Write-Host ".\findVM.ps1 VMNAME1 VMNAME2" -foreground Green
	Write-Host ".\findVM.ps1 VM*" -foreground Green
	Write-Host ".\findVM.ps1 *2008*" -foreground Green
	Write-Host "" -foreground Green
	$VMName = Read-Host "Enter"
} else {
	$VMName = $args
}


foreach ($environment in (Import-CSV D:\INF-VMWARE\scripts\customerEnvironmentSettings.ini) )
{
	$site = $environment.MoreInfo;
	Write-Host "Quering environment " $environment.MoreInfo "("$environment.vCenterSrvName")" -foreground Red
	$srvConnection = Connect-VIServer $environment.vCenterSrvName

	Write-Output "VMs that match your criteria found vCenter infrastructure $environment.vCenterSrvName ($srvConnection)" >> $of
	$vms=Get-VM $VMName -Server $srvConnection -ErrorAction SilentlyContinue
	foreach ($vm in $vms) {
		if ($vm) { 
			Write-Output $vm.Name >> $of
		}
	}
	Write-Output "" >> $of
	#Clear-Host
}

if (test-path $of)
{
	Invoke-Item $of
}  else {
	Write-Output "Error while opening up the result file $of";
	Write-Output "Try rerunning the script or contact INF-VMWARE@Customer.com";
}