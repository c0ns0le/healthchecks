# Lists all VMs with a CPU or Memory Resevations
# Setp 11 2009
# author: teiva.rodiere@gmail.com


$row = "" | Select-Object VM,CPUReservation,CPULimits,MemReservation,MemLimit,Cluster

Get-Cluster * | Get-View | ForEach-Object {
		$row.Cluster = $_.Name;
	Get-VM -Location $_.Name | Get-View | ForEach-Object {
		
		#if reservation exist
		$row.VM = $_.Name;
		if ( ($_.ResourceConfig.CpuAllocation.Reservation -gt 0) -or
		($_.ResourceConfig.CpuAllocation.Limit -gt 0) -or ($_.ResourceConfig.MemoryAllocation.Reservation -gt 0) -or 
		($_.ResourceConfig.MemoryAllocation.Limit -gt 0))
		{
			$row.CPUReservation =$_.ResourceConfig.CpuAllocation.Reservation ;
			$row.CPULimits =$_.ResourceConfig.CpuAllocation.Limit ;
			$row.MemReservation = $_.ResourceConfig.MemoryAllocation.Reservation;
			$row.MemLimit = $_.ResourceConfig.MemoryAllocation.Limit;
			Write-Output $row
		}
	}
}
