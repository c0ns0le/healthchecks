# Load balance ESX datastore/LUNs on Mincom EVA5000. The script load balances LUNs according to MOD(4) algorithm and exact controller ports
# 
# Version : 0.4
# Updated : 31/11/2013
# Author  : teiva.rodiere@gmail.com
# Syntax  : set-multipath-static-hsv110.ps1
#
#
# SCSI Error Decoder - http://vmprofessional.com/index.php?content=resources to identify errors in /var/log/vmkernel

# Next Release
# - Additional CLI Parameters for Batch Use
# - Check MPP on Path Update
# - Compress Code Duplication (Functions)
# - Replace Hash Table with Multi-Dimensional Array
# - Identify Controller issues versus Pathing issues
# - Round Robin Check on sucessful completion of Path Update
# - Improved Error Checking
# - Better Reporting
# - Remove VBSish
#
# Release History
# 0.1 	TR 	- Initial Pre-Release
# 0.2 	TR	- Replaced Static LUN ID assignment with INF_VMware MOD Function
# 		- Replaced Array with Hash Table -> Update Reporting
#		- Additional runtime optimisations
# 0.3	TR 	- Minor Reporting Update + Execution Timing

# Initialize
#FC 16:0.0 10000000c96c20c4<->50001fe150019a68 vmhba1:4:5 On
#FC 16:0.0 10000000c96c20c4<->50001fe150019a6c vmhba1:5:5 On active preferred
#FC 16:0.1 10000000c96c20c5<->50001fe150019a6d vmhba2:4:5 On
#FC 16:0.1 10000000c96c20c5<->50001fe150019a69 vmhba2:5:5 On

$eva_5000_paths = @{"50:00:1f:e1:50:01:9a:68" = "Controller A - Port 0"; "50:00:1f:e1:50:01:9a:69" = "Controller A - Port 1"; "50:00:1f:e1:50:01:9a:6c" = "Controller B - Port 0"; "50:00:1f:e1:50:01:9a:6d" = "Controller B - Port 1";}
$filepath = "C:\admin\powershell\output"
$lun_history = @()
$esx_config = @()
$num_controller_paths = 2
$set_mpp_error_retry = 3
$ErrorActionPreference = "SilentlyContinue" # :-)
$Error.Clear()

# Functions

Function ShowDisclaimer()
{
Write-Host "!!! READ FIRST !!!" -ForegroundColor Red
Write-Host ""
Write-Host "ESX Administrator" -ForegroundColor Yellow
Write-Host "=================" -ForegroundColor Yellow
Write-Host "This script will recalibrate the multipathing policy of each hsv110 LUN using the following placement configuration:" -ForegroundColor Yellow
Write-Host ""
Write-Host "--> All presented ESX LUNs will be configured with a Fixed Multipathing Policy using Preferred Paths" -ForegroundColor Yellow
Write-Host "--> Even LUN IDs will be exclusively assigned to EVA Controller A and statically load-balanced between defined Controller Ports" -ForegroundColor Yellow
Write-Host "--> Odd LUN IDs will be exclusively assigned to EVA Controller B and statically load-balanced between defined Controller Ports" -ForegroundColor Yellow
Write-Host "--> Controller Port assignment is based on modular arithmetic using LUN Identifier (i.e. LUN ID / # of Controller Ports to determine recommended Path)" -ForegroundColor Yellow
Write-Host "    e.g. LUN ID 5 = Controller B (5 = Odd = "B"), Port 1 (5 MOD 4 = "1")" -ForegroundColor Yellow 
Write-Host "--> Load-Balancing is based on Controller WWN not LUN SCSI Target" -ForegroundColor Yellow
Write-Host "--> This script is for ESX 3.X hosts recalibration ONLY - ESX 4.X supports native ALUA and Round-Robin" -ForegroundColor Yellow
Write-Host ""  
Write-Host "SAN Administrator" -ForegroundColor Green
Write-Host "=================" -ForegroundColor Green
Write-Host "It is important that each EVA 5000 vDisk (LUN) used for ESX is configured with the following parameters:" -ForegroundColor Green
Write-Host ""
Write-Host "--> Even LUNs will be configured for Preferred Path/Mode - Path A Failover/Failback"-ForegroundColor Green
Write-Host "--> Odd LUNs will be configured for Preferred Path/Mode - Path B Failover/Failback"-ForegroundColor Green
Write-Host "--> All shared ESX LUNs are presented with the same LUN IDs to all nodes to ensure consistent controller ownership" -ForegroundColor Green
Write-Host ""
Write-Host "!!! READ FIRST !!!" -ForegroundColor Red
Write-Host ""
}
Function check_even ($num) {[bool]!($num%2)}

Function set_mpp ($lun, $newpath, $confirm_lun)
{
	if ($confirm_lun -eq "Y") 
	{$lun_update = $lun |set-scsilun -MultipathPolicy Fixed -PreferredPath $newpath -Confirm} # Replace $error with -ErrorVariable
	else 
	{$lun_update = $lun |set-scsilun -MultipathPolicy Fixed -PreferredPath $newpath} # Replace $error with -ErrorVariable

	write-host "-> Sleeping for 10s to wait for EVA Controller" -foreground Magenta
	write-host ""
	Start-Sleep -Seconds 10 # Wait for EVA - Future (Investigate Trap "Busy" Error and "Retry")	
}

# Main
Clear-Host
ShowDisclaimer
Write-Host "Current EVA Controller and Port Configuration"
Write-Host "============================================="
$eva_5000_paths.getEnumerator() |sort-object Name |ft @{Expression ={$_.Name};Label="EVA Controller WWN";width=25}, @{Expression ={$_.Value};Label="EVA Port Definition"}|out-default #script bug

Disconnect-VIServer $DefaultVIServer -Force
$VIServer = Read-Host "Enter vCenter Server Name"
Write-Host "Connecting to vCenter Server $VIServer ..." -ForegroundColor Cyan
$connect = Connect-VIServer -Server $VIServer -ErrorAction SilentlyContinue -ErrorVariable +err
if ($err.count -ge 1) {Write-Warning "Cannnot connect to vCenter Server $VIServer - Script Halted";Exit} Else {Write-Host "-> vCenter Server Connected <-" -ForegroundColor Magenta}
Write-Host ""

$global:defaultviserver = $connect;

if ($args.Length -ne 0) 
{
	$clusterName = $args[0]
	Write-Host "-> Script Parameter (Cluster Name) : $clustername <-" -ForegroundColor Green
	Write-Host ""
}

Write-Host "Enumerating ESX Clusters connected to vCenter Server $VIServer ..." -ForegroundColor Cyan
$VIclusters = Get-Cluster | Select Name |Sort Name
Get-Cluster |Sort Name|ft -AutoSize|out-default #script bug

#Check Cluster Name Valid
$cluster_match = $true
$a = 0
while($cluster_match) 
{
	if ($args.Length -ne 0 -and $a -eq 0) #Trap 1st Pass only with Argument
	{
		$clusterName = $args[0]
		$a++
	}
	else {$clusterName = Read-Host "Enter ESX Cluster Name to reconfigure hsv110 FC Multipathing"}
	foreach ($cluster in $VIclusters)
	{
		if ($cluster.Name -eq $clusterName)
		{
			Write-Host "-> Cluster Name Validated <-" -foregroundcolor Magenta
			$cluster_match=$false
		}
	}
	if ($cluster_match -ne $false) {Write-Warning "Script Parameter $clusterName is an invalid ESX Cluster name!"}
}
write-host ""

$VMhosts = Get-Cluster $clusterName | Get-vmHost
$VMhosts = $vmhosts |sort-object
Write-Host "ESX Host Summary for Cluster:" $clusterName -ForegroundColor Cyan
$vmhosts|ft Name,State -AutoSize|out-default #script bug

$continue = $true
while($continue)
{
	$answer = Read-Host "Do wish to continue and repair hsv110 LUN Multipathing? [C - Check-Only|Y - Repair|N - Exit]"
	switch ($answer.ToUpper())
	{
		"C" {Write-Host "-> Check-Only and Recommend Mode <-" -foregroundcolor Magenta;write-host "";$continue = $false}
		"Y" {Write-Host "-> Repair Mode <-" -foregroundcolor Red;write-host "";$continue = $false}
		"N" {Exit}
		default {Write-Warning "Incorrect - Select C, Y or N"}
	}
}


$continue = $true
while($continue)
	{
		$pause = Read-Host "Do wish to pause between each ESX LUN during processing? [Y - Yes|N - No]"
		switch ($pause.ToUpper())
			{
				"Y" {Write-Host "-> Pause Mode <-" -foregroundcolor Magenta;write-host "";$continue = $false}
				"N" {Write-Host "-> Continous Mode <-" -foregroundcolor Magenta;write-host "";$continue = $false}
				default {Write-Warning "Incorrect - Select Y or N"}
			}
	}


if ($answer -eq "Y") # - Repair Implied
	{
		$confirm = $true
		while($confirm)
		{
			$confirm_lun = Read-Host "Do wish to confirm each ESX LUN path change during commit processing? [Y - Yes|N - No]"
			switch ($confirm_lun.ToUpper())
				{
					"Y" {Write-Host "-> Confirm Mode <-" -foregroundcolor Magenta;write-host "";$confirm = $false}
					"N" {Write-Host "-> Non-Confirm Mode <-" -foregroundcolor Magenta;write-host "";$confirm = $false}
					default {Write-Warning "Incorrect - Select Y or N"}
				}
		}
	}


# Main Outer ESX Loop
$vmhostcount = 0
$numOfVMhosts = $vmhosts |measure-object
$exec_time = measure-command{
foreach ($vmhost in $VMhosts)
{
	$vmhostcount++
	$esx_object = New-Object -typename System.Object
	$esx_object | Add-Member -MemberType noteProperty -name VMhost -value $vmhost.Name.Split(".")[0]
	Write-Progress -id 1 -activity "Cluster\ESX Progress" -status $clusterName\$vmhost -percentcomplete ($vmhostcount/$numOfVMhosts.Count*100)
	Start-Sleep -Seconds 1
	write-host ""
	Write-Host "ESX Progress -" $vmhostcount "of" $numOfVMhosts.Count "ESX Hosts ("$vmhost.Name")" -ForegroundColor Green
	Write-Host "-> Connected to ESX Host" $vmhost.Name "<-" -ForegroundColor Magenta
	write-Host ""
	$luns = $VMHost|get-scsilun -luntype disk|where-object {$_.ConsoleDeviceName -like "/vmfs/devices/disks/vml*" -AND $_.Model -like "*hsv110*"}|sort-object CanonicalName
	$luns_report = $luns |get-scsilunpath | select LunPath, State, Preferred, SanID, @{Name="EVA Controller Path"; Expression = {$eva_5000_paths.Get_Item($_.SanID)}}
	$TotalCapacityMB = $luns | measure-object CapacityMB -sum
	$TotalCapacityGB = $TotalCapacityMB.Sum/1024
	$numOfLuns = $luns |measure-object # Replace luns.Count
	$numOfPaths = $luns_report |measure-object # Replace luns_report.Count
	Write-Host "Current : ESX Multipathing Summary for all hsv110 LUNs on" $vmhost.Name -ForegroundColor Cyan
	$luns_report|ft -AutoSize|out-default #script bug
	write-host "TOTAL hsv110 LUNS:" $numOfLuns.Count "("$numOfPaths.Count "PATHS )"-ForegroundColor Red
	write-host "TOTAL hsv110 Capacity:" $TotalCapacityGB "GB"-ForegroundColor Red
	write-host ""
	$esx_object | Add-Member -MemberType noteProperty -name Total_hsv110_LUNs -value $numOfLuns.Count
	$esx_object | Add-Member -MemberType noteProperty -name Total_hsv110_Paths -value $numOfPaths.Count
	$esx_object | Add-Member -MemberType noteProperty -name Total_hsv110_CapacityGB -value $TotalCapacityGB

	#Check AdvancedConfiguration for SAN Best Practice	
	Write-Host "Checking ESX Configuration for Cluster SAN supportability" -ForegroundColor Cyan
	$LunResetValue = ($vmhost |Get-VMHostAdvancedConfiguration).get_Item("Disk.UseLunReset")
	$DeviceResetValue = ($vmhost |Get-VMHostAdvancedConfiguration).get_Item("Disk.UseDeviceReset")
	$esx_object | Add-Member -MemberType noteProperty -name DeviceResetValue -value $DeviceResetValue
	$esx_object | Add-Member -MemberType noteProperty -name LunResetValue -value $LunResetValue
	switch ($DeviceResetValue) # 0 Recommended
	{
		"0" 	{
				Write-Host "-> ESX UseDeviceReset Value:" $DeviceResetValue "is Correct" -ForegroundColor Green
				$esx_object | Add-Member -MemberType noteProperty -name DeviceResetStatus -value "OK"
			}
		"1" 	{
				Write-Host "-> ESX UseDeviceReset Value:" $DeviceResetValue "is Incorrect - Update Value to 0 for SAN support" -ForegroundColor Red
				$esx_object | Add-Member -MemberType noteProperty -name DeviceResetStatus -value "REPAIR"
			}
		default	{
				Write-Warning "-> ESX UseDeviceReset Value:" $DeviceResetValue "is Invalid - Update Value to 0 for SAN support"
				$esx_object | Add-Member -MemberType noteProperty -name DeviceResetStatus -value "INVALID"
			}
	}

	switch ($LunResetValue) # 1 Recommended
	{
		"1" 	{
				Write-Host "-> ESX UseLunReset Value:" $LunResetValue "is Correct" -ForegroundColor Green
				$esx_object | Add-Member -MemberType noteProperty -name LunResetStatus -value "OK"
			}
		"0" 	{
				Write-Host "-> ESX UseLunReset Value:" $LunResetValue "is Incorrect - Update Value to 1 for SAN support" -ForegroundColor Red
				$esx_object | Add-Member -MemberType noteProperty -name LunResetStatus -value "REPAIR"
			}
		default	{
				Write-Warning "-> ESX UseLunReset Value:" $LunResetValue "is Invalid - Update Value to 1 for SAN support"
				$esx_object | Add-Member -MemberType noteProperty -name LunResetStatus -value "INVALID"
			}
	}
	
	Write-Host ""		

	# Main Inner LUN Loop	
	$luncount = 0
	Write-Host "Reviewing ESX Multipathing for hsv110 LUNs" -ForegroundColor Cyan
	
	foreach ($lun in $luns)
	{	
		$luncount++
		$mppRR=$false
		$object = New-Object -typename System.Object
		$object | Add-Member -MemberType noteProperty -name VMhost -value $vmhost.Name.Split(".")[0]
		$lunid = $lun.Canonicalname.Split(":")[2]
		$isLunEven = check_even($lunid)
		$lun_recommended_port = $lunid % $num_controller_paths # Mod Function 
		$object | Add-Member -MemberType noteProperty -name LUN_ID -value $lunid
		Write-Progress -id 2 -parentid 1 -activity "LUN Progress" -status $lun.Canonicalname -percentcomplete ($luncount/$numOfLuns.Count*100)
		Start-Sleep -Seconds 0.75
		Write-Host "LUN Progress -" $luncount "of" $numOfLuns.Count "LUNs ("$vmhost.Name")" -ForegroundColor Green
		Write-Host "-> Checking Multipathing for hsv110 LUN" $lunid "on" $vmhost.Name "<-" -ForegroundColor Cyan
		write-host "-> Cluster =" $clusterName -ForegroundColor Magenta
		write-host "-> ESX Host =" $vmhost.Name -ForegroundColor Magenta
		write-host "-> LUN ID =" $lunid -ForegroundColor Magenta
		write-host "-> MPP =" $lun.MultipathPolicy -ForegroundColor Magenta
		$paths = Get-ScsiLunPath -scsilun $lun
		$activepath = $paths|where-object {$_.State -eq "Active"}
		$activecontroller = $eva_5000_paths.Get_Item($activepath.SanID)
		write-host "-> Active Controller Path =" $activecontroller -ForegroundColor Magenta
		write-host "-> Active WWN Path =" $activepath.LunPath "(" $activepath.SanID ")" -ForegroundColor Magenta
		$object | Add-Member -MemberType noteProperty -name Active_Path -value $activepath.LunPath
		$object | Add-Member -MemberType noteProperty -name Active_Path_Controller -value $activepath.SanID
		$object | Add-Member -MemberType noteProperty -name Active_MPP -value $lun.MultipathPolicy
		if ($isLunEven) #Even LUN - Controller A
		{
			switch ($lun_recommended_port) 
			{ 
				0 {$newpath = $paths|where-object {$_.SanID -eq "50:00:1F:E1:50:11:F9:88"};Break}
				1 {$newpath = $paths|where-object {$_.SanID -eq "50:00:1F:E1:50:11:F9:89"};Break}
				2 {$newpath = $paths|where-object {$_.SanID -eq "50:00:1F:E1:50:11:F9:8A"};Break}
				3 {$newpath = $paths|where-object {$_.SanID -eq "50:00:1F:E1:50:11:F9:8B"};Break}
				default {write-warning "No HSV20 Controller match?"}
			}
		}
		else # Odd LUN - Controller B
		{
			switch ($lun_recommended_port) 
			{ 
				0 {$newpath = $paths|where-object {$_.SanID -eq "50:00:1F:E1:50:11:F9:8C"};Break}
				1 {$newpath = $paths|where-object {$_.SanID -eq "50:00:1F:E1:50:11:F9:8D"};Break}
				2 {$newpath = $paths|where-object {$_.SanID -eq "50:00:1F:E1:50:11:F9:8E"};Break}
				3 {$newpath = $paths|where-object {$_.SanID -eq "50:00:1F:E1:50:11:F9:8F"};Break}
				default {write-warning "No HSV20 Controller match?"}
			}
		}
		$object | Add-Member -MemberType noteProperty -name Recommended_Path -value $newpath.LunPath
		$object | Add-Member -MemberType noteProperty -name Recommended_Path_Controller -value $newpath.SanID
		write-host "-> Recommended Controller Path =" $eva_5000_paths.Get_Item($newpath.SanID) -ForegroundColor Magenta
		write-host "-> Recommended WWN Path ="$newpath.LunPath "("$newpath.SanID")" -ForegroundColor Magenta # new
		if ($lun.MultipathPolicy -ieq "RoundRobin") {write-host "";write-warning "Active MPP = Round Robin - Requires Investigation!";$mppRR=$true} 
		write-host ""
		Write-Host "Current : ESX Multipathing Summary for LUN" $lunid -ForegroundColor Cyan
		$paths_report = $lun |get-scsilunpath | select Lunpath, SanID, @{Name="EVA Controller Path"; Expression = {$eva_5000_paths.Get_Item($_.SanID)}}, State, Preferred, @{Name="Recommended"; Expression = {if ($_.SanId -eq $newpath.SanID) {"Y"}}}
		$paths_report|ft -AutoSize|out-default #script bug
		if ($activepath.LunPath -ne $newpath.LunPath -or $mppRR) # Pathing Incorrect or MPP-RR Enabled
		{
			if ($mppRR) {write-warning "Multi-Pathing Policy = RoundRobin"} else {write-warning "Active Path <> Recommended Path"}
			write-host ""
			$date = get-date -uformat "%d/%m/%y %T"
			if ($answer -eq "Y") # Repair Implied
			{
				write-host "-> Repair Mode <-" -foregroundcolor Magenta
				write-host "-> Updating LUN" $lunid "connected to path" $activepath.LunPath "("$activepath.SanID") with new Path" $newpath.LunPath "("$newpath.SanID") <-" -ForegroundColor Magenta
				write-host ""
				$lun_update_attempt = $true
				$a = 1				
				while($lun_update_attempt)
				{
					Write-Host "-> Repair Attempt" $a "of" $set_mpp_error_retry -ForegroundColor Magenta
					set_mpp $lun $newpath $confirm_lun																		
					if ($error.count -ne 0 -and $a -le $set_mpp_error_retry) #Error Detected - Need to Verify
					{
						$a++
						Write-Warning "Error detected during set-scsilun execution - Re-Running"
						$Error.Clear() #Reset - Replace with per Function -ErrorVariable
					}
					Else
					{$lun_update_attempt = $false} # No Errors or Exceed Retry Attempts
				}		
				$object | Add-Member -MemberType noteProperty -name Change_Date -value $date
				$paths = Get-ScsiLunPath -scsilun $lun
				$activepath = $paths|where-object {$_.State -eq "Active"}
				if ($activepath.LunPath -ne $newpath.LunPath) # need to check for RR
				{
					$object | Add-Member -MemberType noteProperty -name Change -value "FAIL"
					Write-Warning "Active Path <> Recommended Path - Update Failure, Please Investigate!"
				}
				else 
				{
					$object | Add-Member -MemberType noteProperty -name Change -value "OK"
					write-host "SUCCESS: Active Path = Recommended Path" -ForegroundColor Green
				}
				write-host ""
				$paths = Get-ScsiLunPath -scsilun $lun
				$paths_report = $lun |get-scsilunpath | select Lunpath, SanID, @{Name="EVA Controller Path"; Expression = {$eva_5000_paths.Get_Item($_.SanID)}}, State, Preferred, @{Name="Recommended"; Expression = {if ($_.SanId -eq $newpath.SanID) {"Y"}}}
				Write-Host "Updated : ESX Multipathing Summary for LUN" $lunid -ForegroundColor Cyan
				$paths_report|ft -AutoSize|out-default #script bug
			}
			else # "C" Check-Only implied
			{
				if ($mppRR) {write-host "--> Recommend updating the MPP of LUN" $lunid "connected to path" $activepath.LunPath "("$activepath.SanID") to Fixed" -ForegroundColor Magenta}
				else {write-host "-> Recommend updating LUN" $lunid "connected to path" $activepath.LunPath "("$activepath.SanID") with new Path" $newpath.LunPath "("$newpath.SanID")" -ForegroundColor Magenta}
#				$lun |set-scsilun -MultipathPolicy Fixed -PreferredPath $newpath -WhatIf
				write-host ""
				$object | Add-Member -MemberType noteProperty -name Change -value "REPAIR"
				$object | Add-Member -MemberType noteProperty -name Change_Date -value "N/A"
				$paths = Get-ScsiLunPath -scsilun $lun # Path shouldn't change
				$activepath = $paths|where-object {$_.State -eq "Active"}
			}
		} 
		else # Pathing OK
		{
			$object | Add-Member -MemberType noteProperty -name Change -value "N/A"
			$object | Add-Member -MemberType noteProperty -name Change_Date -value "N/A"
			write-host "NO CHANGE: LUN" $lunid "connected to Path" $activepath.LunPath "("$activepath.SanID") is the correct Path" -foregroundColor Green
			write-host ""
		}
		$lun_history += $object
		if ($pause -eq "Y")
		{
			Write-Host "Press any key to continue for next LUN ..."
			$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,AllowCtrlC")
		}
		write-host ""
	} # End LUN Loop
$luns_report = $luns |get-scsilunpath | select LunPath, State, Preferred, SanID, @{Name="EVA Controller Path"; Expression = {$eva_5000_paths.Get_Item($_.SanID)}}
Write-Host "Updated : ESX Multipathing Summary for all hsv110 LUNs on" $vmhost.Name -ForegroundColor Cyan
$luns_report|ft -AutoSize|out-default #script bug
Write-Progress -id 2 -parentid 1 -activity "LUN Progress" -status $lun.Canonicalname -percentcomplete ($luncount/$numOfLuns.Count*100) -Completed
$esx_config += $esx_object
} # End ESX Host Loop
Write-Progress -id 1 -activity "Cluster\ESX Progress" -status $clusterName\$vmhost -percentcomplete ($vmhostcount/$numOfVMhosts.Count*100) -Completed
} # End Measure-Command

#Reporting
$date = get-date -uformat "%d/%m/%y %T"
$whoami = $connect.User
# Screen Report
Write-Host "VI Cluster $VIServer\$clusterName Multipathing Changes @ $date - Run By : $whoami" -ForegroundColor Red
Write-Host ""
if ($answer -eq "C"){Write-Host "Run Mode: Check-Only" -ForegroundColor Yellow} Else {Write-Host "Run Mode: Repair" -ForegroundColor Yellow}
Write-Host "Script Execution Time:" $exec_time.TotalSeconds "seconds" -ForegroundColor Yellow
Write-Host ""
Write-Host "ESX Host Status" -ForegroundColor Green
Write-Host "===============" -ForegroundColor Green
$esx_config | select VMhost, Total_hsv110_LUNs, Total_hsv110_Paths, Total_hsv110_CapacityGB, DeviceResetValue, DeviceResetStatus, LunResetValue, LunResetStatus|ft -AutoSize|out-default #script bug
Write-Host "SAN Controller Configuration" -ForegroundColor Green
Write-Host "============================" -ForegroundColor Green
$eva_5000_paths.getEnumerator() |sort-object Name |ft @{Expression ={$_.Name};Label="EVA Controller WWN";width=25}, @{Expression ={$_.Value};Label="EVA Port Definition"}|out-default #script bug
Write-Host "ESX Host Multipathing Changes" -ForegroundColor Green
Write-Host "=============================" -ForegroundColor Green
$lun_history | select VMhost, LUN_ID, Active_Path, Active_Path_Controller, Active_MPP, Recommended_Path, Recommended_Path_Controller, Change, Change_Date |sort VMhost,LUN_ID|ft -AutoSize|out-default #script bug
Write-Host ""

# Totals - Redo Next Release
$total_changes_failed = $lun_history | where {$_.Change -eq "FAIL"}|measure-object
$total_changes_ok = $lun_history | where {$_.Change -eq "OK"}|measure-object
$total_changes_na = $lun_history | where {$_.Change -eq "N/A"}|measure-object
$total_changes_required = $lun_history | where {$_.Change -eq "REPAIR" -or $_.Change -eq "OK" -or $_.Change -eq "FAIL"}|measure-object # Fix
$total_lunresetvalue_incorrect = $esx_config | where {$_.LunResetStatus -eq "REPAIR" -or $_.LunResetStatus -eq "INVALID"}|measure-object
$total_deviceresetvalue_incorrect = $esx_config | where {$_.DeviceResetStatus -eq "REPAIR" -or $_.DeviceResetStatus -eq "INVALID"}|measure-object

Write-Host "Script Execution Summary" -ForegroundColor Green
Write-Host "========================" -ForegroundColor Green
Write-Host ""
Write-Host "Total LUNs Configured Correctly :"$total_changes_na.Count
Write-Host "Total LUNs Requiring Path Updates :"$total_changes_required.Count
Write-Host "Total Failed Corrections :"$total_changes_failed.Count
Write-Host "Total Successful Corrections :"$total_changes_ok.Count
Write-Host "Total Incorrect ESX LunResetValue :"$total_lunresetvalue_incorrect.Count
Write-Host "Total Incorrect ESX DeviceResetValue :"$total_deviceresetvalue_incorrect.Count
Write-Host ""

Write-Host "-> Updating Cluster Multipathing Change Log -" $filepath\"set-multipath-static-hsv110-"$VIServer"-"$clusterName.txt -ForegroundColor Magenta
Write-Host ""
# File Report
"VI Cluster $VIServer\$clusterName Multipathing Changes @ $date - Run By : $whoami" | out-file "$filepath\set-multipath-static-hsv110-$VIServer-$clusterName.txt" -NoClobber -Append
"" | out-file $filepath\"set-multipath-static-hsv110-"$VIServer"-"$clusterName.txt -NoClobber -Append
if ($answer -eq "C"){"Run Mode: Check-Only"|out-file "$filepath\set-multipath-static-hsv110-$VIServer-$clusterName.txt" -NoClobber -Append} Else {"Run Mode: Repair"|out-file "$filepath\set-multipath-static-hsv110-$VIServer-$clusterName.txt" -NoClobber -Append}
"Script Execution Time: " + $exec_time.TotalSeconds + " seconds"| out-file $filepath\"set-multipath-static-hsv110-"$VIServer"-"$clusterName.txt -NoClobber -Append
"" | out-file $filepath\"set-multipath-static-hsv110-"$VIServer"-"$clusterName.txt -NoClobber -Append
"ESX Host Status" | out-file "$filepath\set-multipath-static-hsv110-$VIServer-$clusterName.txt" -NoClobber -Append
"===============" | out-file "$filepath\set-multipath-static-hsv110-$VIServer-$clusterName.txt" -NoClobber -Append
$esx_config | sort VMhost,LUN_ID | ft -AutoSize | out-file $filepath\"set-multipath-static-hsv110-"$VIServer"-"$clusterName.txt -NoClobber -Append
"SAN Controller Configuration" | out-file "$filepath\set-multipath-static-hsv110-$VIServer-$clusterName.txt" -NoClobber -Append
"============================" | out-file "$filepath\set-multipath-static-hsv110-$VIServer-$clusterName.txt" -NoClobber -Append
$eva_5000_paths.getEnumerator() |sort-object Name |ft @{Expression ={$_.Name};Label="EVA Controller WWN";width=25}, @{Expression ={$_.Value};Label="EVA Port Definition"} | out-file "$filepath\set-multipath-static-hsv110-$VIServer-$clusterName.txt" -NoClobber -Append
"ESX Host Multipathing Changes" | out-file "$filepath\set-multipath-static-hsv110-$VIServer-$clusterName.txt" -NoClobber -Append
"=============================" | out-file "$filepath\set-multipath-static-hsv110-$VIServer-$clusterName.txt" -NoClobber -Append
$lun_history | select VMhost, LUN_ID, Active_Path, Active_Path_Controller, Active_MPP, Recommended_Path, Recommended_Path_Controller, Change, Change_Date |sort VMhost,LUN_ID | ft -AutoSize | out-file $filepath\"set-multipath-static-hsv110-"$VIServer"-"$clusterName.txt -NoClobber -Append
"Script Execution Summary"| out-file $filepath\"set-multipath-static-hsv110-"$VIServer"-"$clusterName.txt -NoClobber -Append
"========================"| out-file $filepath\"set-multipath-static-hsv110-"$VIServer"-"$clusterName.txt -NoClobber -Append
""| out-file $filepath\"set-multipath-static-hsv110-"$VIServer"-"$clusterName.txt -NoClobber -Append
"Total LUNs Configured Correctly :" + $total_changes_na.Count| out-file $filepath\"set-multipath-static-hsv110-"$VIServer"-"$clusterName.txt -NoClobber -Append
"Total LUNs Requiring Path Updates :" + $total_changes_required.Count| out-file $filepath\"set-multipath-static-hsv110-"$VIServer"-"$clusterName.txt -NoClobber -Append
"Total Failed Corrections :" + $total_changes_failed.Count| out-file $filepath\"set-multipath-static-hsv110-"$VIServer"-"$clusterName.txt -NoClobber -Append
"Total Successful Corrections :" + $total_changes_ok.Count| out-file $filepath\"set-multipath-static-hsv110-"$VIServer"-"$clusterName.txt -NoClobber -Append
"Total Incorrect ESX LunResetValue :" + $total_lunresetvalue_incorrect.Count | out-file $filepath\"set-multipath-static-hsv110-"$VIServer"-"$clusterName.txt -NoClobber -Append
"Total Incorrect ESX DeviceResetValue :" + $total_deviceresetvalue_incorrect.Count | out-file $filepath\"set-multipath-static-hsv110-"$VIServer"-"$clusterName.txt -NoClobber -Append
"" | out-file $filepath\"set-multipath-static-hsv110-"$VIServer"-"$clusterName.txt -NoClobber -Append

if ($Error.Count -ne 0) {Write-Warning $error.count "outstanding errors have occurred during set-multipath-static-hsv110.ps1 execution."}
else {Write-Host "No outstanding errors detected during execution" -ForegroundColor Green}
Write-Host ""
# Disconnect-VIServer $connect -Force
