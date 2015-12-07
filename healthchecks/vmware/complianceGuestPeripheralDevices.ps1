# Lists VMs that have floppy and CD roms connected
#Version : 0.1
#Updated : 3 Septembre 2009
#Author  : teiva.rodiere-at-gmail.com

$myvm = "" | Select Name,Path;
foreach ( $vm in (get-vm *)) 
{
	$cd= Get-cddrive -VM $vm; 
	$floppy= Get-FloppyDrive -VM $vm;
	if ($cd.isopath -or $floppy.FloppyImagePath)
	{ 
		$myvm.name = $vm.Name; 
		$myvm.Path = $cd.isopath; 
		if ($floppy.FloppyImagePath) 
		{
			$myvm.Path = $myvm.Path + "," + $floppy.FloppyImagePath;
		}
		Write-Output $myvm; 
	}
}