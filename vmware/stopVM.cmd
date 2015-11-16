@echo off
powershell.exe "& 'E:\scripts\powershell\stopVM.ps1' -userId %1 -passWord %2 -VM %3" 