$vms = get-vm * | Select-Object *
Write-Output "Virtual Machine Memory Stats."
$vms | measure-object –property MemoryMB -average –maximum –minimum

Write-Output "Virtual Machine Disk Usage stats"
$vms | foreach { (get-harddisk -VM $_.Name | measure-object -property CapacityKB -sum).Sum}  | measure-object -average -sum -maximum –minimum

Write-Output "Guest Types (Not including Templates)"
#$vmsView = $vms| Get-View 
#$row = $vmsView | % {
$row = $vms | %{
	$config = "" | Select-Object -Property "GuestType";
	if ($_.Guest.GuestFullName -ne ""){
		$config.GuestType = $_.Guest.OSFullName;
	}
	$config;
} 
$report = $row | Sort-Object GuestType -Unique -Descending | %{
	$result = "" | Select-Object -Property "GuestFlavour","Count","Percent"
	$result.GuestFlavour = $_.GuestType;
	$result.Count = ($row | Select-Object GuestType | ?{$_.GuestType -eq  $result.GuestFlavour}).Count
	if ($result.Count -ne $null) {
		$result.Percent = "{0:P2}" -f "$([math]::truncate($result.Count / $row.Count * 100))%";
	} else {
		$result.Percent = "0%"
	}
	$result
}
$report | ft

Write-Output "Teplates"
Get-Template | Ft
#Write-Output "Get a list of all VMs and export it to CSV format. Include the following fields: Name, Description, Host, Power State, Number of CPUs, Memory"
#get-vm | select Name, Description, PowerState, Num*, Memory*, @{Name="Host"; Expression={$_.Host.Name}} | export-csv output.csv