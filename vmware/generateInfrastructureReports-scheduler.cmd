@echo off

set SCRIPTLOC="E:\scripts"
cd /d %SCRIPTLOC%

powershell.exe -Command "& {E:\scripts\generateInfrastructureReports-scheduler.ps1 -configFile E:\scripts\customerEnvironmentSettings-ALL.ini -logDir E:\scripts\scheduler\flexpod-migration-reports -logFile E:\scripts\scheduler\flexpod-migration-reports\runtime-emailer.log}"

