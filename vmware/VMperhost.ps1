$vc = Read-Host "Please specify your VirtualCenter"
$User = Read-Host "Please Specify Login ID"
$Pass = Read-Host -AsSecureString "Enter Password"

Connect-VIServer $vc -User $User -password $Pass
$filename = "c:\scratch\vmhostcount.csv"

#Clear varables
$vm = ""
$clu = ""

# Set arrays
$cluster = @()
$hosts = @()
$list = @()

$cluster = Get-Cluster
# Get all the hosts in a cluster

foreach ( $clu in $cluster) {

	$hosts = $clu | Get-VMHost
	
	foreach ($ho in $hosts) {
	
	$vm = $Ho | Get-VM

Write-Host $clu $Ho $vm.Count

#$list = $clu.Name,$Ho.Name,$vm.Count

#$list | Export-Csv $filename -NoTypeInformation

}}