# Configure the settings
$rocommunity="<yours>"
$trapPort="162" # this is the default though
$receiverTargetHost="snmpTargetIPAddress"
# The following are not needed, it is just a reminder that the NNM polling settings are as follow
#Timeout=2 seconds
#Retries=3
#Status polling=1 minute
# This helps getting things configured quickly
#CSV Format: SEVRERNAME,PASSWORD_IN_CLEAR_TEXT
$serverlist = Import-csv ".\ServerList-serverAndPasswords.csv"

# It's important to remember that Connect to vCenter doesn't help, you must connect to ESX/ESXi  directly
$serverlist | %{ Connect-viserver $_.servername -User root -Password $_.password }
$hostsSnmp = Get-VMHostSnmp
$hostsSnmp | select *
$hostsSnmp | %{ Set-VMHOstSnmp -HostSnmp $_ -ReadOnlyCommunity $rocommunity -TargetHost $receiverTargetHost -TargetPort $trapPort -TargetCommunity $rocommunity -AddTarget }
$hostsSnmp | %{ Set-VMHOstSnmp -HostSnmp $_ -Enabled:$true }
$hostsSnmp | %{ Test-VMHostSnmp $_ }

#
# To remove the target if you entered the wrong name, port or community str
# $hostsSnmp | %{ Set-VMHOstSnmp -HostSnmp $_ -TargetHost $receiverTargetHost -removetarget }
