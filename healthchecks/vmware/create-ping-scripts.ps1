$vms = get-vm * -Server $srvconnection

$hostnames = $vms | select Host -Unique
$cmdtask = "start D:\INF-VMware\mybin\Pinger.exe -s"

#create host scripts
$hostbatchfile = ".\ping-all-hosts.bat"
echo "@ECHO OFF" | Out-File -FilePath $hostbatchfile -Encoding "UTF8"

$hostnames | %{
   Write-Output "$cmdtask $($_.Host)" |  Out-File -FilePath $hostbatchfile -Append -Encoding "UTF8"
}

#initialise the bat files
$hostnames | %{
    $batchfile = ".\$($_.Host.Name).bat"
	echo "@ECHO OFF" | Out-File -FilePath $batchfile -Encoding "UTF8"
}

$vms | sort Name | select Name,Host | %{
	$batchfile = ".\$($_.Host.Name).bat"
	Write-output "$cmdtask $($_.Name)" |  Out-File -FilePath $batchfile -Append -Encoding "UTF8"
}
