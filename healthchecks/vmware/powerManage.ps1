# Power Manager VM of choice
# Permitted actions are: start,shutdown,restart,stop,reset,status
# Version : 0.2
# Last updated : 02 June 2010
# Maintained by: teiva.rodiere-at-gmail.com
# Syntax: C:\admin\autoscripts\powerManageVM.cmd $powerAction $userid  $password $vm
# Syntax (frmo openview):  ovdeploy -cmd "C:\admin\autoscripts\powerManageVM.cmd $powerAction $userid  $password $vm" -host $vcenter
#
# required switches
param($action="",$userid="",$password="",$vm="",$vcentername=$env:Computername)
function DisconnectVIServer()
{
	if ($vcenter)
	{
		#Write-Host "Disconnecting $userid from $vcenter" -ForegroundColor $global:colours.Highlight;
		Disconnect-VIServer -Server $vcenter -Confirm:$false
	}

}

$ErrorActionPreference = "SilentlyContinue" # :-)
$Error.Clear()

# filter out bad parameters
if ($action -eq "" -or $userid -eq "" -or $password -eq "" -or $vm -eq "")
{
	Write-Host "Syntax: .\powerManageVM.ps1 -action <action> -userId <username> -passWord <password> -VM <name>" -ForegroundColor $global:colours.Error; 
	Write-Host "Note the permitted power actions are: start,shutdown,restart,stop,reset,status" -ForegroundColor $global:colours.Error;
	exit;
}

# Main course
# Add the VIM Automation libraries
Add-PSSnapin VMware.VimAutomation.Core

#connect to virtualcenter
Write-Host "Connecting $userid to $vcentername.." -ForegroundColor $global:colours.Highlight;
$vcenter = Connect-VIServer -server $vcentername -User $userId -Password $passWord   -ErrorAction SilentlyContinue -ErrorVariable $err ; #-Debug:$false -OutVariable $output -ErrorAction SilentlyContinue -Verbose:$false

if (!$vcenter -or ($err.count -ge 1) )
{
	Write-host "Unable to connect session to virtualcenter server $vcenter" -ForegroundColor  red
	exit;
}

# Query vm object
$vmObject = Get-VM $vm -ErrorAction SilentlyContinue -Verbose:$false -Server $vcenter | Select-Object *;

if (!$vmObject)
{
	Write-Host "Virtual machine [$vm] not found in Inventory [vcenter=$vcenter]" -ForegroundColor $global:colours.Error;
	DisconnectVIServer;
	exit;
}

switch ($action)
{
	"start" {
		if ( ($vmObject.PowerState -eq "PoweredOff") -or ($vmObject.PowerState -eq "Suspended")) {
			Start-VM -VM $vmObject.Name -Confirm:$false;
		} else {
			Write-host "You cannot perform this action[$action] on guest[$vm]. It's current powerstate is "$vmObject.PowerState -ForegroundColor $global:colours.Error;
		}
	}
	"shutdown" {
		if ( $vmObject.PowerState -eq "PoweredOn" ) {
			Shutdown-VMGuest -VM $vmObject.Name -Confirm:$false;
			
		} else {
			Write-host "You cannot perform this action[$action] on guest[$vm]. It's current powerstate is "$vmObject.PowerState -ForegroundColor $global:colours.Error;
		}
	}
		
	"restart" {
		if ( $vmObject.PowerState -eq "PoweredOn" ) {
			Restart-VMGuest -VM $vmObject.Name -Confirm:$false; 
		} else {
			Write-host "You cannot perform this action[$action] on guest[$vm]. It's current powerstate is "$vmObject.PowerState -ForegroundColor $global:colours.Error;
		}
	}
	"stop" {
		if ($vmObject.PowerState -ne "PoweredOff") {
			Stop-VM -VM $vmObject.Name -Confirm:$false;
		} else {
			Write-host "You cannot perform this action[$action] on guest[$vm]. It's current powerstate is "$vmObject.PowerState -ForegroundColor $global:colours.Error;
		}
	}
	"reset" {
		if ( $vmObject.PowerState -eq "PoweredOn" ) {
			Stop-VM -VM $vmObject.Name -Confirm:$false;
			Start-VM -VM $vmObject.Name -Confirm:$false;
		} else {
			Write-host "You cannot perform this action[$action] on guest[$vm]. It's current powerstate is "$vmObject.PowerState -ForegroundColor $global:colours.Error;
		}
	}
	"status" {
		$vmObject;
	}
	default {
		$vmObject;
	}

}

DisconnectVIServer;
