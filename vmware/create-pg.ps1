#Purpose: USe this script to create a port group on all hosts in a defined cluster
#Version : 0.3
#Last Updated : 26th Feb 2010, teiva.rodiere@gmail.com
#Author : teiva.rodiere@gmail.com 
#Syntax: .\create-pg.ps1 -Cluster "VMWARE_CLUSTER" -pgName "Portgroup_Name" -vlan "100" -vSwitchName "vSwitch1" -vcenterName "name"
#Inputs: vcenter server name, username, and password
#Output: new port group created on defined vSwitch
param([object]$srvConnection,$Cluster="",$pgName="",$vlan="",$vSwitchName="",$vcenterName="",
	[bool]$commit=$false,$autocontinue="N",[string]$onlyServer)


if (!$srvConnection -or ( ($srvConnection.GetType().Name -ne "VIServerImpl") -and ($srvconnection.GetType().Name -ne "Object[]") ) )
{ 
    Write-Host "Current value of srvConnection is $srvConnection"
    Write-Host "Type of srvConnection is $($srvConnection.GetType())"
	$vcenterName = Read-Host "ME virtual center server name"
	Write-Host "Connecting to virtual center server $vcenterName.."
	$srvConnection = Connect-VIServer -Server $vcenterName
	$disconnectOnExist = $true;	
} else {
    Write-Host "Current value of srvConnection is $srvConnection"
    Write-Host "Type of srvConnection is $($srvConnection.GetType())"
	$disconnectOnExist = $false;
	$vcenterName = $srvConnection.Name;
}

if ((!$Cluster -and !$onlyServer) -or $pgName-eq "" -or $vlan -eq "" -or $vSwitchName -eq "")
{
	write-output "Syntaxt: .\create-pg.ps1 -Cluster name -pgName name -vlan number -vSwitchName vSwitchX -vcenterName name -commit yes|no"
	Write-Output "Note the syntax is case sensitive. i.e vswitch1 is not the same as vSwitch1"
	exit;
}

if ($commit -eq $false) 
{
	write-host "-> script running in readonly mode [commit=$commit]" -foreground Magenta
} elseif ($commit -eq $true) 
{
	write-host "-> script running in commit mode. Changes will take effect automatically [commit=$commit]" -foreground Magenta
	
	$continue = $true
	while($continue)
	{
		if ($autocontinue -eq "")
		{
			$autocontinue = Read-Host "Do wish to commit changes on all servers in cluster without a prompt? [Y - Yes|N - No]"
		} else {
			switch ($autocontinue.ToUpper())
			{
				"Y" {Write-Host "-> Auto Commit Mode selected <-" -foregroundcolor Magenta; write-host "";$continue = $false; $commit=$true;}
				"N" {Write-Host "-> Exiting application, consider running in read only mode first to view changes before commiting <-" -foregroundcolor Magenta;write-host "";$continue = $false; exit;}
				default {Write-Warning "Incorrect - Select Y or N"}
			}
		}
	}
} else { write-host "-> invalid commit value [commit=$commit]. Only yes and no allowed" -foreground Magenta; exit;}

$exists = "False";
#Write-Host "Connecting to virtual center server $vcenterName" -foreground Yellow
#$vcenter = Connect-VIServer -Server $vcenterName

$exists = "False";

if ($onlyServer)
{
	Write-host "Getting ESX host $onlyServer ..."
	$vmhosts = Get-VMhost -Name  $onlyServer -Server $srvConnection
} else {
	Write-host "Getting list of ESX host in cluster $Cluster..."
	$vmhosts = Get-VMhost -Location $Cluster -Server $srvConnection 
}

$vmhosts | foreach-object {
	$esxhost = $_;
	$vs = Get-VirtualSwitch -VMHost $esxhost -Name $vSwitchName;
	$pgs = Get-VirtualPortGroup -VirtualSwitch $vs;
	if ($pgs)
	{
		foreach ($pg in $pgs) {
			if ($pg.Name.Equals($pgName)) 
			{
				$exists = "True";
			}
		}
	}
	
	if ($exists.Equals("True")) 
	{
		Write-Host "Port group [Name=$pgName,vSwitch=$vSwitchName,vlanid=$vlan] already exists on $esxHost" -foreground Yellow;
	
	} else  {
		if ($commit -eq $false) {
			Write-Host "[read-only mode] new group [Name=$pgName,vSwitch=$vSwitchName,vlanid=$vlan] created on $esxHost"  -foreground Green;
		}
		if ($commit -eq $true) 
		{
			$newVPG = New-VirtualPortGroup -VirtualSwitch $vs -Name $pgName -VLanID $vlan -Confirm:$false;
			Write-Host "The new group [Name=$pgName,vSwitch=$vSwitchName,vlanid=$vlan] created on $esxHost" -foreground Blue;
		}
	}
	$exists = "False";	
}

