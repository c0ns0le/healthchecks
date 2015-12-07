$vm=get-vm
$vm | Select-Object name,guest,notes,memoryMB,numcpu,resourcepool,powerstate,VMhost | Export-Csv d:\inf-vmware\export\ssdc.csv -NoTypeInformation
