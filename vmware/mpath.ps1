#Check vSwitches/Port Groups config in VCS for the 1st host in every cluster
#Version : 0.4
#Updated : 8th Oct 2009
#Author  : teiva.rodiere@gmail.com


#$vcenterName = Read-Host "Enter virtual center server name"
#$vcenter = Connect-VIServer -Server $vcenterName

$Report = Get-Datacenter | %{
 
  # Store the DC Name ($_ will not be the same in the next loop)
  $DCName = $_.Name
  $of = $DCName + "_mpath.txt" 
  $_ | Get-Cluster | %{
 
    # Store the Cluster Name ($_ will not be the same in the next loop)
    $ClusterName = $_
 
    # Select only the first returned host
    $_ | Get-VMHost | Select-Object -First 1 | %{
	write-Host "Processing VMhost $_.Name" 
		#$env:path += ";C:\Program Files\VMware\VMware Infrastructure CLI\bin\"
  		$pass=.\getphrase-cons.exe $_ -i Ms6f_ 8;
		iex "'C:\Program Files\VMware\VMware Infrastructure CLI\bin\vicfg-mpath.pl' --list --server $_.Name --username root --passwd $pass";
		Write-Host $results
    }
  }
}
 
$Report

