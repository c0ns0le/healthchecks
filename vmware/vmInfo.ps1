# Helps admin find a given virtual machine within multiple VirtualCenter servers and shows it's location
#Version : 0.1
#Updated : 1th Nov 2009
#Author  : teiva.rodiere@gmail.com 
param( [string] $VMName)

$row = "" | Select-Object VMName,GuestFullName,GuestState,HostName,NumCPU,MemoryMB,HDDCount,NICCount,IpAddress,ToolsStatus,ToolsVersion,SyncTimeWithHost,BootTime,BladeSystem,Client,SLA,VRUC,VRUM,Cluster,ResponsibilityCode;

$vCenterServers = "srvds3350x001.corporate.transgrid.local","SRVDWX3350X003.corporate.transgrid.local","SRVDSX3850X001.corporate.transgrid.local"
$VIServers = Connect-VIServer -Server $vCenterServers 


#######################################
# Start of script
if ($VMName -eq ""){
	Write-Host
	Write-Host "Please specify a virtual machine name name eg...."
	Write-Host "      powershell.exe vmInfo.ps1 MYVM"
	Write-Host
	Write-Host
	exit
} else {
	#foreach ($viserver in $vCenterServers) {
		Get-VM -Name $VMName -Server $VIServers  | Get-View | foreach-object { 
			$row.Cluster = $_.Name;
			
			Get-VM -Location $_.Name  | Sort-Object Name | Get-View | foreach-object {
				$row.VMName = $_.Name;
				$row.IpAddress =$_.Guest.IpAddress;
				$row.GuestState =$_.Guest.GuestState;
				$row.HostName =$_.Guest.HostName;
				$row.NumCPU = $_.Config.Hardware.NumCPU;
				$row.MemoryMB =$_.Config.Hardware.MemoryMB ;
				$row.HDDCount = $_.Guest.Disk.Count;
				$row.NICCount = $_.Guest.Net.Count;
				$row.GuestFullName = $_.Config.GuestFullName ;
				$row.ToolsStatus =$_.Guest.ToolsStatus;
				$row.ToolsVersion = $_.Config.Tools.ToolsVersion ;
				$row.SyncTimeWithHost =$_.Config.Tools.SyncTimeWithHost ;
				$row.BootTime =$_.Runtime.BootTime;
				$customValue = $_.CustomValue;#| Select-Object Key,Name | Sort-Object Key;
				$availableFields = $_.AvailableField;# | Select-Object Key,Value | Sort-Object Key;
				$row.Client = "";
					$row.ResponsibilityCode = "";
					$row.SLA = "";
					$row.VRUC = "";
					$row.VRUM = "";
					$row.BladeSystem = "";
				if ($customValue) 
				{
				for ($i = 0; $i -lt $customValue.Length; $i++){
					
					$key = $customValue[$i].Key;
					$value = $customValue[$i].Value;
					for ($j = 0; $j -lt $availableFields.Length; $j++)
					{
						if ($key -eq $availableFields[$j].Key) 
						{
							switch ($availableFields[$j].Name) {
								"Client" { $row.Client =  $value;}
								"Responsibility Code" {$row.ResponsibilityCode = $value;}
								"SLA" {$row.SLA =  $value;}
								"VRU-C" {$row.VRUC = $value;}
								"VRU-M" {$row.VRUM  = $value;}
								"BladeSystem" {$row.BladeSystem = $value;}
								#default {""};
							}
						}
					}
				}
				}
				Write-Output   $row;
			}
		}
	#}
}

$VIServers | Disconnect-VIServer -Confirm:$false