#Purpose: USe this script to delete a port group on all hosts in a defined cluster
#Version : 0.3
#Last Updated : 26th Feb 2010, teiva.rodiere@gmail.com
#Author : teiva.rodiere@gmail.com 
#Syntax: .\delete-pg.ps1 -Cluster name -pgName name -vSwitchName name"
#Example: .\delete-pg.ps1 -Cluster CUSTOMER_CLU -pgName Mincom-PortGroup_100 -vSwitchName vSwitch1"
#Inputs: vcenter server name, username, and password
#Output: new port group created on defined vSwitch
param($Cluster,$pgName,$vSwitchName)

$vcenterName = Read-Host "Enter virtual center server name"
Write-Host "Connecting to virtual center server $vcenterName.."
$vcenter = Connect-VIServer -Server $vcenterName

$exists = "False";
if ($args){
	$clusterName=$args[1];
	$name=$args[3];
	$vSwitch = $args[5];
	$exists = "False";
	
	get-VMhost -Location $clusterName | foreach-object {
		$esxhost = $_;
		$vs = Get-VirtualSwitch -VMHost $esxhost -Name $vSwitch;
		$pgs = Get-VirtualPortGroup -VirtualSwitch $vs;
		foreach ($pg in $pgs) {
			if ($pg.Name.Equals($name)) 
			{
				$exists = "True";
				$vpgToDelete = $pg;
			}
		}
	
		if ($exists.Equals("True")) 
		{
			Remove-VirtualPortGroup -VirtualPortGroup $vpgToDelete -Confirm:$false;
			Write-Output "Port Group [Name=$name] removed from $esxHost";
		
		} else  {
			Write-Output "Port Group [Name=$name] does not exist on $esxHost";
		}
		$exists = "False";	
	}
}
else {
write-output "Syntaxt: .\delete-pg.ps1 -Cluster name -pgName name -vSwitchName name"
}