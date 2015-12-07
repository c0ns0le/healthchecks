# Exports VMs and Specific attributes
#Version : 0.1
#Updated : 3rd Step 2009
#Author  : teiva.rodiere@gmail.com 
#param($userId,$passWord,$VM)
if ($args) { 
	$id=$args[1];
	$pass=$args[3];
	$VMName=$args[5];

	#Write-Output $id $pass $VMName
	Add-PSSnapin VMware.VimAutomation.Core
	Connect-VIServer –server $env:Computername –User $id –Password $pass

	$row = "" | Select-Object VMName,IpAddress,GuestState,HostName,NumCPU,MemoryMB,GuestFullName,ToolsStatus,ToolsVersion,SyncTimeWithHost,BootTime,BladeSystem,Client,SLA,VRUC,VRUM,Cluster,ResponsibilityCode;
	
	Get-VM $VMName | Get-View | foreach-object {
		$row.VMName = $VMName;
		Get-VM BNEVUM01 | Get-Cluster | Select-Object -property Name | ForEach-Object { $row.Cluster += $_.Name} ;
		$row.IpAddress =$_.Guest.IpAddress;
		$row.GuestState =$_.Guest.GuestState;
		$row.HostName =$_.Guest.HostName;
		$row.NumCPU = $_.Config.Hardware.NumCPU;
		$row.MemoryMB =$_.Config.Hardware.MemoryMB ;
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
		Write-Output  $row | Export-CSV ".\$VMName.csv";
	}
} 
else { 
	Write-output "Syntax: .\get-Guest-Summary.ps1 -userId <username> -passWord <password> -VM <name>"
}



