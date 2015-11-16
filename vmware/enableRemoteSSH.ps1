# 
# verify SSH Service status
#Get-VMHost | Get-VMHostService | Where { $_.Key -eq "TSM-SSH" } |select VMHost, Label, Running

# export all servces
#Get-VMHost | Get-VMHostService |select VMHost, Label, Running

#Enable SSH on all hosts 
#Get-VMhost | Get-VMHostService | ?{$_.Key -eq "TSM-SSH"} | Start-VMHostService

# Stop Remote SSH Service on all cluster hosts
#Get-VMhost | Get-VMHostService | ?{$_.Key -eq "TSM-SSH"} | Stop-VMHostService

$esxhosts = Get-VMHost | Sort-object -Property Name

# Enable SSH on all hosts
$esxhosts | Get-VMHostService | ?{$_.Key -eq "TSM-SSH"} | Start-VMHostService

# Stop SSH serices
#$esxhost | Get-VMHostService | ?{$_.Key -eq "TSM-SSH"} | Stop-VMHostService -confirm:$false