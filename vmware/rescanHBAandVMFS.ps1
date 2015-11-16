# Rescan cluster hosts for new LUN and VMFS volumes
#Version : 0.1
#Updated : 09th July 2010
#Author  : teiva.rodiere@gmail.com
param([object]$srvConnection="",[string]$clustername="", [string]$logDir="output", [string]$mode="", [string]$vcenterName="")
Write-Host "Executing script $($MyInvocation.MyCommand.path)" -ForegroundColor  green;
Write-Host "Current path is $($pwd.path)" -ForegroundColor  yellow;

$disconnectOnExist = $true;

function ShowSyntax ()
{
	Write-Host "Syntax:  rescanHBAandVMFS.ps1 -vcenterName name -mode [readonly|execute] -clustername [name|*]"
	exit;
}


switch ($mode.ToUpper())
{
	"READONLY" {Write-Host "-> Read-Only (will not rescan, just show command) <-" -foregroundcolor Magenta;write-output "";$continue = $false}
	"EXECUTE" {Write-Host "-> Execute Mode (will rescan)<-" -foregroundcolor Red;write-output "";$continue = $false}
	default {
		Write-Warning "Invalid execution mode (specified mode=$mode); Choice is: readonly or execute"
		ShowSyntax
	}
}

if ($clustername -eq "")
{
	$continue = $true
	while($continue)
	{
		Write-Host "You have not specified a Cluster name"
		Write-Host "Do you want to rescan for all LUNs and VMFS datastores on all hosts in all Clusters in $vcenterName ?"
		$answer = Read-Host "[Y - All Clusters | N - Exit]"
		switch ($answer.ToUpper())
		{
			"Y" {Write-Host "-> Processing all clusters <-" -foregroundcolor Red; $clustername = "*"; write-output "";$continue = $false}
			"N" {Write-Host "-> User exit <-" -foregroundcolor Red; $clustername = ""; write-output ""; exit}
			default {Write-Warning "Incorrect - Select Y or N"}
		}
	}
}

if (!$srvConnection -or ( ($srvconnection.GetType().Name -ne "VIServerImpl") -and ($srvconnection.GetType().Name -ne "Object[]") ) )
{ 
	if (!$vcenterName ) {$vcenterName = Read-Host "Enter virtual center server name"}
	Write-Host "Connecting to virtual center server $vcenterName.."
	$srvConnection = Connect-VIServer -Server $vcenterName
	$disconnectOnExist = $true;	
} else {
	$disconnectOnExist = $false;
}

if (!$srvConnection)
{
	Write-Host "Not connected to Virtualcenter server $vcenterName. Specify a correct server and authentication settings"
	ShowSyntax
	exit;
}

if ((Test-Path -path $logDir) -ne $true) {
	New-Item -type directory -Path $logDir
}

Write-Host "Enumerating datacenters in virtualcenter..." -ForegroundColor Yellow
Get-Datacenter -Server $svConnection | %{
	$dc = $_.Name;
	if ($clustername -eq "*") {	Write-Host "Processing all clusters in $dc in processing mode=$mode..." -ForegroundColor Yellow }
	else { Write-Host "Processing clustername "$dc\$clustername" in processing mode=$mode..." -ForegroundColor Yellow }
	#Write-Host "-> $clustername <-"
	Get-Cluster "$clustername" -Location "$dc" |  %{
		if ($_) {
			$cluster = $_.Name
			if ($mode -eq "readonly")  { 
				Write-Host "[readonly] Rescanning VMHost in $dc\$cluster..." -ForegroundColor Yellow 
				Write-Host "[cmd] Get-VMHost -Location $cluster | Get-VMHostStorage -RescanAllHba -RescanVmfs"
			} 
			else {
				Write-Host "[cmd]: Get-VMHost -Location $cluster | Get-VMHostStorage -RescanAllHba -RescanVmfs"
				Get-VMHost -Location $cluster | Get-VMHostStorage -RescanAllHba -RescanVmfs
			}
		} else { Write-Warning "Cannot process cluster $dc\$clustername" }
	}
}
Write-Host ""
Write-Host ""
Write-Host "Complete" -ForegroundColor Yellow

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}