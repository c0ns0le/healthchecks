<#
This script will login to each fibre swith specified in the fibre-switches.txt and captutre the current errors and then clear all the errors on each port
#>


# Set the SMTP Server address
$SMTPSRV = "smtpserver"
# Set the Email address to recieve from
$EmailFrom = "from@abcd.com"
# Set the Email address to send the email to
$EmailTo = "to-address@abcd.com"
$logFile = "Brocade-Log-" + (Get-date -f dd ).tostring() + (Get-date -f MM ).tostring() + ((Get-Date).year).tostring() + ".err"

(get-date) > $logFile

# Capture the errors to log file
Get-Content .\fibre-switches.txt | % {  $_  >> $LogFile ; & '.\plink.exe' -l admin -pw password -m .\brocade1.txt  $_  >> $LogFile}
# Clear the errors on all switch ports
Get-Content .\fibre-switches.txt | % { & '.\plink.exe' -l admin -pw password -m .\brocade2.txt  $_  }

$MyReport = "Cleared Fibre switch errors for all brocade switches"
Send-MailMessage -To $EmailTo  -Subject "Brocade switch error clear." -From $EmailFrom  -Body $MyReport -SmtpServer $SMTPSRV -Attachments $LogFile