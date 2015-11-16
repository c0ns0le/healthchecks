#Purpose: Use this script to create all portgroups on ALL hosts in the "Maintenance Dock" folder
#Version : 0.3
#Last Updated : 26th Feb 2010, teiva.rodiere@gmail.com
#Author : teiva.rodiere@gmail.com 
param([object]$srvConnection,$hostsInLocation="Maintenance Dock",$sourceHost="",$targetHost="", $pgName="",$vlan="",$vSwitchName="vSwitch1",$vcenterName="",[bool]$commit=$false,$autocontinue="")

$disconnectOnExist = $true;

if (!$srvConnection -or ( ($srvConnection.GetType().Name -ne "VIServerImpl") -and ($srvconnection.GetType().Name -ne "Object[]") ) )
{ 
    Write-Host "Current value of srvConnection is $srvConnection"
    Write-Host "Type of srvConnection is $($srvConnection.GetType())"
	$vcenterName = Read-Host "Enter virtual center server name"
	Write-Host "Connecting to virtual center server $vcenterName.."
	$srvConnection = Connect-VIServer -Server $vcenterName
	$disconnectOnExist = $true;	
} else {
    Write-Host "Current value of srvConnection is $srvConnection"
    Write-Host "Type of srvConnection is $($srvConnection.GetType())"
	$disconnectOnExist = $false;
	$vcenterName = $srvConnection.Name;
}

if ($sourceHost -eq "" -or ($hostsInLocation -eq "" -and $targetHost -eq ""))
{
	write-output "Syntaxt: .\create-pg.ps1 -Cluster name -pgName name -vlan number -vSwitchName vSwitchX -vcenterName name -commit yes|no"
	Write-Output "Note the syntax is case sensitive. i.e vswitch1 is not the same as vSwitch1"
	exit;
}

#get-vc mmsbnevcm01.gms.mincom.com

#Get Source PGs
$sourceVMhost = Get-VMhost -Name $sourceHost -Server $srvconnection

if ($sourceVMhost)
{
	$pgs = $sourceVMhost | Get-VirtualSwitch -Name $vSwitchName | Get-VirtualPortGroup
	#$array_PG=("MCC-192.168.50.x_501","501"),("JoyGlobal-10.161.9.0-24_509","509"),("NQM-192.168.0.x_500","500"),("SFC-Prod-10.223.38.x_505","505"),("Vicroad-149.176.224.32_506","506"),("OzMinerals-Prod-10.0.60.x_502","502")
	if ($pgs)
	{
		$pgs | %{
			Write-host "Processing """$_.Name""" with ""vlanid="""$_.VLanId
			.\create-pg.ps1 -Cluster $hostsInLocation -pgName $_.Name -vlan $_.VLanId -srvconnection $srvconnection -vSwitchName $vSwitchName -commit $commit -autocontinue "Y"
		}
	}
} else {
	Write-Host "$sourceHost is not a valid servername"
}