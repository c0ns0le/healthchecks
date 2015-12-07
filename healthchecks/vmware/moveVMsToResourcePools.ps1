# Moves Virtual Machines around to a resource pool based on a give policy
#Version : 0.1
#Updated : 23th Feb 2012
#Author  : teiva.rodiere-at-gmail.com
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[string]$vmName="",[bool]$verbose=$true)

function ShowSyntax() {
	Write-host "" -ForegroundColor Yellow 
	Write-host " Syntax: ./moveVMsToResourcePools.ps1 -srvConnection `$srvConnection -vmName ""yourPrefix""" -ForegroundColor Yellow 
	Write-host "" -ForegroundColor Yellow 
	Write-host "`$srvConnection: You can obtain this variable by first executing a command like this: `$srvConnection = Connect-VIServer vcenterServerFQDN" -ForegroundColor Yellow 
	Write-host "vmName: Can any string such as MSD*, *, *BNE*" -ForegroundColor Yellow 
	Write-host "" -ForegroundColor Yellow 
}

function VerboseToScreen([string]$msg,[string]$color="White")
{
	if ($verbose) {write-host $msg -foregroundcolor $color}
}

VerboseToScreen "Executing script $($MyInvocation.MyCommand.path)" "Green";
VerboseToScreen "Current path is $($pwd.path)" "yellow"

if (!$srvConnection -and !$vmName) {
	ShowSyntax
	exit
}
	
# Policies
$gold_cluster=""
$gold_rp=""
$gold_datastore=""
$default_SLA="Low"
$default_rp = "Bronze"
$array_SLAPolicy=@{ High = "Gold"; Medium = "Silver"; Low = $default_rp} 
$relocString="relocate"
$norelocString="stays"

$disconnectOnExist = $true;

if (!$srvConnection)
{ 
	$vcenterName = Read-Host "Enter virtual center server name"
	VerboseToScreen "Connecting to virtual center server $vcenterName.."
	$srvConnection = Connect-VIServer -Server $vcenterName
	$disconnectOnExist = $true;	
} else {
	$disconnectOnExist = $false;
	$vcenterName = $srvConnection.Name;
}

if ((Test-Path -path $logDir) -ne $true) {
	New-Item -type directory -Path $logDir
}


$filename = ($($MyInvocation.MyCommand.Name)).TrimEnd('.ps1');

VerboseToScreen "$filename";

if ($comment -eq "" ) {
	$of = $logDir + "\"+$filename+"-"+$vcenterName+".csv"
} else {
	$of = $logDir + "\"+$filename+"-"+$comment+".csv"
}
VerboseToScreen "This script log to $of" "Yellow"

VerboseToScreen  "Enumerating clusters in $srvConnection..."
$Report = get-cluster -server $srvConnection  | %{ 
	$clustername = $_.Name
	get-vm -name $vmName -Location $clustername | Sort-Object Name | %{
			$vmObj = $_;
			$rp="";
			$vmArray = "" | Select-Object "Name";
			$vmArray.Name = $_.Name;
			$vmArray | Add-Member -Type NoteProperty -Name "cluster" -Value $clustername;
			$slaValue = ($_.CustomFields | where{$_.Key -eq "SLA"}).Value
			$vmArray | Add-Member -Type NoteProperty -Name "SLA" -Value $slaValue;
			$vmArray | Add-Member -Type NoteProperty -Name "CurrentRP" -Value $($_.ResourcePool.Name);
			$rp=$array_SLAPolicy.$slaValue;

			#VerboseToScreen  $rp;
			if ($rp) {
				#VerboseToScreen  "Moving $($vmArray.Name) to ""$rp"" resource pool"
				$vmArray | Add-Member -Type NoteProperty -Name "CorrectRP" -Value $rp;
			} else { 
				#VerboseToScreen  "Moving $($vmArray.Name) to default resource pool ""$default_rp"""
				$vmArray | Add-Member -Type NoteProperty -Name "CorrectRP" -Value $default_rp;
			}
			if ($vmArray.CurrentRP -eq $vmArray.CorrectRP){
				$vmArray | Add-Member -Type NoteProperty -Name "Task" -Value $norelocString;
				VerboseToScreen  "[skiping      ] $vmArray" "Yellow"
				$vmArray
			} else {
				$vmArray | Add-Member -Type NoteProperty -Name "Task" -Value $relocString;
				VerboseToScreen  "#########################" "Yellow"
				VerboseToScreen  "[Processing...] $vmArray " "Green"
				$vmArray

				$targetRPName = $vmArray.CorrectRP

				VerboseToScreen  "This VM has an SLA of $slaValue, therefore will be relocated to resource pool ""$targetRPName""" "Yellow"

				# Checking if the resource pool object already exists
				$count=1
				$OK=(Get-Variable "rpObj$slaValue" -valueonly -ErrorAction:SilentlyContinue)

				VerboseToScreen  "Resource Pool loaded=$($OK -eq $true)" "Cyan"
				do {
					VerboseToScreen  "Loading resource Pool ""$targetRPName"" [count=$count]..." "Cyan"
					New-Variable "rpObj$slaValue";
					#get-resourcepool -location $clustername -Name $targetRPName
					Set-Variable "rpObj$slaValue" (Get-resourcepool -location $clustername -Name $targetRPName);
					$count++;
					$OK=(Get-Variable "rpObj$slaValue" -valueonly)
					#VerboseToScreen  "OK=$OK"  "Cyan"
					#VerboseToScreen  $count
					if ($count -gt 3) { VerboseToScreen  "Exceeded retry count, skipping this migration [count=$count]" "Red"; break; }
				} while (!$OK)
				if ($OK) {					
					VerboseToScreen  "Target resource pool aquired successfully" "Cyan"
					VerboseToScreen  "Migrating ""$($vmArray.Name)"" to $targetRPName" "Yellow"
					$vmObj | Move-vm -destination (Get-Variable "rpObj$slaValue" -valueonly)
					VerboseToScreen  "" "Yellow"
				} 
			}
			
		}
}


Write-Output $Report | Export-Csv $of -NoTypeInformation
Write-Output "" >> $of
Write-Output "" >> $of
Write-Output "Collected on $(get-date)" >> $of

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}