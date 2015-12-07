# Lists VMs and their some key attributes
#Version : 0.1
#Updated : 3rd Feb 2009
#Author  : teiva.rodiere@gmail.com 

$myarray = "" | Select-Object Name,IpAddress,GuestState,ESXHostName,NumCPU,MemoryMB,GuestFullName,ToolsStatus,ToolsVersion,SyncTimeWithHost,BootTime;

$vCenter = Read-Host "Enter the vCenter server name"
$User = Read-Host "Enter the User name"
$Password = Read-Host "Enter the Password"
Connect-VIServer -Server $vCenter -User $User -Password $Password

Get-VM -Name BNEVCM01 | Get-View | foreach-object {
	$myarray.Name = $_.Name;
	$myarray.IpAddress =$_.Guest.IpAddress;
	$myarray.GuestState =$_.Guest.GuestState;
	$myarray.ESXHostName =$_.Guest.HostName;
	$myarray.NumCPU = $_.Config.Hardware.NumCPU;
	$myarray.MemoryMB =$_.Config.Hardware.MemoryMB ;
	$myarray.GuestFullName = $_.Config.GuestFullName ;
	$myarray.ToolsStatus =$_.Guest.ToolsStatus;
	$myarray.ToolsVersion = $_.Config.Tools.ToolsVersion ;
	$myarray.SyncTimeWithHost =$_.Config.Tools.SyncTimeWithHost ;
	$myarray.BootTime =$_.Runtime.BootTime;
	Write-Output   $myarray;
}