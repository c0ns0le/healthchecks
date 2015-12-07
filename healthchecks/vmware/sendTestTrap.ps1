# This powershell script helps generating an snmp trap (Warm start - generic snmpv2)
# 
# Configure the settings
$targethost="esxi.customer.com"
$targethostUsername="root"
$targethostPassword="rootpassword"
$rocommunity="rocommunity"
$trapPort="162" # this is the default though
$receiverTargetHost="targetSNMPServer"
# The following are not needed, it is just a reminder that the NNM polling settings are as follow
#Timeout=2 seconds
#Retries=3
#Status polling=1 minute
# This helps getting things configured quickly
#$serverlist = Import-csv ".\rnd-serverAndPasswords.csv"

# just in case
Set-ExecutionPolicy unrestricted
$snapinLoaded = Get-PSSnapin | ?{$_.Name -contains "VMware.VimAutomation.Core"}
if (!$snapinLoaded) {Add-pssnapin VMware.VimAutomation.Core}

# It's important to remember that Connect to vCenter doesn't help, you must connect to ESX/ESXi  directly
Write-Output "Logging on to $targethost as $targethostUsername.."
$serverlist | %{Connect-viserver $targethost -User $targethostUsername -Password $targethostPassword}
Write-Output "Looking up SNMP Configurations for host $targethost.."
$hostsSnmp = Get-VMHostSnmp
#show SNMP configuration
#$hostsSnmp | select *
# Configure service whilst I am at it
#$hostsSnmp | %{ Set-VMHOstSnmp -HostSnmp $_ -ReadOnlyCommunity $rocommunity -TargetHost $receiverTargetHost -TargetPort $trapPort -TargetCommunity $rocommunity -AddTarget }
# Enable SNMP Service whilst I am at it
#$hostsSnmp | %{ Set-VMHOstSnmp -HostSnmp $_ -Enabled:$true }
Write-output "Generating a test trap from $targethost to $receiverTargetHost"
$hostsSnmp | %{ Test-VMHostSnmp $_ }

# To remove the target if you entered the wrong name, port or community str
#$hostsSnmp | %{ Set-VMHOstSnmp -HostSnmp $_ -TargetHost $receiverTargetHost -removetarget }
