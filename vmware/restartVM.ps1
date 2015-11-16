# Restarts VM of choice
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
		
		Write-Output "Current Powerstate of the VM: " + $vm.PowerState;
		
		# -RunAsync means the command Start-VM will continue without waiting
		if ( ($vm.PowerState -eq "PoweredOn") -or ($vm.PowerState -eq "Suspended")) {
			$vm | Stop-VM -RunAsync | Start-VM;
			
		} else {
			Write-Output "VM cannot be powered started. It's current powerstate is " + $vm.PowerState;
		}
} else {
	Write-output "Syntax: .\startVM.ps1 -userId <username> -passWord <password> -VM <name>"
}
