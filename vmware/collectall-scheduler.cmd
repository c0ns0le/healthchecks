@echo off

set SCRIPTLOC="C:\admin\scripts\vmware"
cd /d %SCRIPTLOC%

powershell.exe "& {C:\admin\scripts\vmware\collectAll-scheduler.ps1 -configFile C:\admin\scripts\vmware\customerEnvironmentSettings-ALL.ini -logDir C:\admin\scripts\vmware\scheduler\sydney -logFile C:\admin\scripts\vmware\scheduler\sydney\collectAll-scheduler.log}"
powershell.exe "& {C:\admin\scripts\vmware\generateInfrastructureReports.ps1 -useConfig $true -configFile C:\admin\scripts\vmware\customerEnvironmentSettings-ALL.ini -logDir C:\admin\scripts\vmware\scheduler\sydney -inDir C:\admin\scripts\vmware\scheduler\sydney -emailReport $true -openReportOnCompletion $false}"