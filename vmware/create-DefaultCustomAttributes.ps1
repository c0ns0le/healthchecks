#NOT FINISHED - WORK IN PROGRESS
#Teiva
$srvconnection =  get-vc
$customAttributes = Get-CustomAttribute -Server $srvconnection
#TargetType	Specify the type of the objects to which the new custom attribute applies. 
#The valid values are VirtualMachine, ResourcePool, Folder, VMHost, Cluster, Datacenter, and $null. 
#If the value is $null the custom attribute is global and applies to all target types.
#Global
$targettype="VMHost"

#Global
$GLOBAL_CUSTOMER_ATTRIBUTES_DEFINITIONS = "Business Impact","Client Region","Commissioned By","Commissioned Date","Department","Hardware","Last Modified By","Last Modified Date","Last Task","Last Task By","Last Task Date","Licence","Location","MAC Address","SLA","Site","Special Notes","Support Contact","Support Region","Work Order"
$GLOBAL_CUSTOMER_ATTRIBUTES_DEFINITIONS | New-CustomerAttribute -Name %_ -TargetType $null

#VirtualMachine
$VMSS_CUSTOMED_ATTRIBUTES_DEFINITIONS="Application","Backup Schedule","Backup Server","Expiry Date"
$VMSS_CUSTOMED_ATTRIBUTES_DEFINITIONS | New-CustomerAttribute -Name %_ -TargetType VirtualMachine

#VMHost
$VMHOSTS_CUSTOMED_ATTRIBUTES_DEFINITIONS = "Remote Console","BladeEnclosure"
$VMHOSTS_CUSTOMED_ATTRIBUTES_DEFINITIONS  | New-CustomerAttribute -Name %_ -TargetType VMhost

#Resource Pools
$RP_CUSTOMED_ATTRIBUTES_DEFINITIONS = "Policy_CPU_Reservation_%","Policy_CPU_Limit_%","Policy_MEM_Reservation_%","Policy_MEM_Limit_%"
$RP_CUSTOMED_ATTRIBUTES_DEFINITIONS | New-CustomerAttribute -Name %_ -TargetType ResourcePool

#Folders

#Clusters
$targettype="Datacenter"



