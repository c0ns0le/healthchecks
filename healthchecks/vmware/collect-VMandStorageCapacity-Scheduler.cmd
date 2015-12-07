@echo off

set SCRIPTLOC="E:\scripts"
cd /d %SCRIPTLOC%

powershell.exe -Command "& {E:\scripts\collect-VMandStorageCapacity-Scheduler.ps1 -configFile E:\scripts\customerEnvironmentSettings-ALL.ini -logDir E:\scripts\scheduler\flexpod-migration-reports -logFile E:\scripts\scheduler\flexpod-migration-reports\export-daily-capacity.log}"

