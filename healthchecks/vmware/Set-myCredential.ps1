# Syntax
# Set-Credentials -File securestring.txt
# Set-Credentials 
# maintained by: teiva.rodiere@gmail.com
# You need to open run this under the account that will be using to run the reports or the automation
# DOMAIn\svc-autobot is a domain account which most scripts run under on VCENTERSEVER.
#   if you want to use DOMAIN\svcAccount to call any scripts under scheduled task, you need to create the password file for the target account to 
# be used in the target vcenter server. So for exampl: if you want to automate scripts from VCENTERSEVER.internaldomain.lan against the DEV Domain
# you need 
# 1) Launch cmd.exe as the DOMAIN\svcAccount account on VCENTERSEVER
#   C:\>runas /user:DOMAIN\svcAccount cmd.exe
# 2) in the command line cmd.exe shell, launch powershell.exe
# 3) in powershell run this script, where securetring.txt should be named meaningfully..like securestring-dev-autobot.txt
# 
Param([string]$File="securestring.txt")
$Credential = Get-Credential
$credential.Password | ConvertFrom-SecureString | Set-Content $File
