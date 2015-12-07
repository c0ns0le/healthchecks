# Starts a VM of choice
#Version : 0.1
#Updated : 15th Step 2009
#Author  : teiva.rodiere@gmail.com
#param($userId,$passWord,$VM)
if ($args) {
        $id=$args[1];
		$pass=$args[3];
        $VMName=$args[5];

        #Write-Output $id $pass $VMName
        Add-PSSnapin VMware.VimAutomation.Core
        Connect-VIServer -server $env:Computername -User $id -Password $pass
		
		$vm = Get-VM $VMName;
		# -RunAsync means the command Start-VM will continue without waiting
		if ( ($vm.PowerState -eq "PoweredOff") -or ($vm.PowerState -eq "Suspended")) {
			Start-VM  $vm -RunAsync;
		} else {
			Write-Output "VM cannot be powered started. It's current powerstate is " + $vm.PowerState;
		}
} else {
	Write-output "Syntax: .\startVM.ps1 -userId <username> -passWord <password> -VM <name>"
}
