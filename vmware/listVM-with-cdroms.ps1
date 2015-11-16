#list how many VMs have CD DRVIE mounted
get-vm | get-cddrive | select Parent,"HostDevice","RemoteDevice","IsoPath"