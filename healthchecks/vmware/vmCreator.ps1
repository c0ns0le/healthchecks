#Script to Deploy Multiple VMs from Template using number iteration
# version: 0.1
# Autor:	teiva.rodiere-at-gmail.com

#*****************************************************
#Connect-VIServer -Server $env:hostname -User <user> -Password <password>
$esxhostName = "hostname.internaldomain.lan";
$templateName = "MyLinuxTemplate_64-bit";
$datastoreName = "DATSTORE_NAME";
$customizationName = "Test-CusOS";
$portGroupName = "SaaS-Private-PG";
$rpName = "Saas Deployment"; # Resource Pool name
$vmnamePrefix="VM"
$totalNumber=10

$esxhost = Get-VMHost $esxhostName;
$template = Get-Template $templateName;
$datastore = Get-Datastore $datastoreName;
$rp = Get-ResourcePool $rpName;
$customization = Get-OSCustomizationSpec $customizationName;

0..$totalNumber | %{
	$index=0
	$newVm = New-VM -VMHost $esxhost -Name "$($vmnamePrefix)$($index)" -Datastore $datastore -ResourcePool $rp -NetworkName $portGroupName -OSCustomizationSpec $customizationName ;
}
