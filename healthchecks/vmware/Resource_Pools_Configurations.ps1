# Exports resource pools configurations and runtime information
#Version : 0.4
#Author : 04/06/2010, by teiva.rodiere@gmail.com
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$verbose=$false)
Write-Host "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global
$global:logfile
$global:outputCSV

# Want to initialise the module and blurb using this 1 function
InitialiseModule
$Report = $srvConnection | %{
    $vCenterName = $_.Name
	logThis -msg "Enumerating resources from this managed environment $vCenterName"
    $resourcePools = Get-ResourcePool -Server $vCenterName| sort name
    $index = 1; 
    $rpCount = 0;
    if ($resourcePools)
    {
        if ($resourcePools.Count) {
            $rpCount = $resourcePools.Count
        } else { 
            $rpCount = 1
        }
        
        logThis -msg "$rpCount found.."
        
        $resourcePools |  %{
            logThis -msg "Processing resource pool $index/$rpCount - $($_.Name)" -Foregroundcolor Yellow
            if ($_.ExtensionData.gettype().Name -eq "ResourcePool") {	
    		    $rpConfig = "" | Select-Object "vCenter";
    			$currRp = $_;
    			$rpConfig.vCenter = $vCenterName; 
                $rpConfig | Add-Member -Type NoteProperty -Name "Name" -Value $currRp.Name;
    					
    			if ($currRp.Parent.Type -eq "ResourcePool") {
                    $parentRp = Get-View -id $currRp.ParentId;
                    if ($parentRp.Name -eq "Resources")	{
                        $rpConfig | Add-Member -Type NoteProperty -Name "ParentResourcePool" -Value "";
                    } else {
    				    $rpConfig | Add-Member -Type NoteProperty -Name "ParentResourcePool" -Value $parentRp.Name;
    				}
    			}
                        
    			$rpConfig | Add-Member -Type NoteProperty -Name "Cpu-ReservationMHz" -Value $currRp.CpuReservationMHz                
                $rpConfig | Add-Member -Type NoteProperty -Name "Cpu-ReservationUsed" -Value $currRp.ExtensionData.Runtime.Cpu.ReservationUsed
                $rpConfig | Add-Member -Type NoteProperty -Name "Cpu-ReservationUsedForVm" -Value $currRp.ExtensionData.Runtime.Cpu.ReservationUsedForVm
                $rpConfig | Add-Member -Type NoteProperty -Name "Cpu-UnreservedForPool" -Value $currRp.ExtensionData.Runtime.Cpu.UnreservedForPool
                $rpConfig | Add-Member -Type NoteProperty -Name "Cpu-UnreservedForVm" -Value $currRp.ExtensionData.Runtime.Cpu.UnreservedForVm
                $rpConfig | Add-Member -Type NoteProperty -Name "Cpu-OverallUsage" -Value $currRp.ExtensionData.Runtime.Cpu.OverallUsage
                $rpConfig | Add-Member -Type NoteProperty -Name "Cpu-MaxUsage" -Value $currRp.ExtensionData.Runtime.Cpu.MaxUsage
       			$rpConfig | Add-Member -Type NoteProperty -Name "CpuSharesLevel" -Value $currRp.CpuSharesLevel;
    			$rpConfig | Add-Member -Type NoteProperty -Name "CpuExpandableReservation" -Value $currRp.CpuExpandableReservation; 
    			$rpConfig | Add-Member -Type NoteProperty -Name "CpuLimitMHz" -Value $currRp.CpuLimitMHz; 

                $rpConfig | Add-Member -Type NoteProperty -Name "Mem-ReservationMB" -Value $currRp.MemReservationMB ;
                $rpConfig | Add-Member -Type NoteProperty -Name "Mem-ReservationUsed" -Value $currRp.ExtensionData.Runtime.Memory.ReservationUsed
                $rpConfig | Add-Member -Type NoteProperty -Name "Mem-ReservationUsedForVm" -Value $currRp.ExtensionData.Runtime.Memory.ReservationUsedForVm
                $rpConfig | Add-Member -Type NoteProperty -Name "Mem-UnreservedForPool" -Value $currRp.ExtensionData.Runtime.Memory.UnreservedForPool
                $rpConfig | Add-Member -Type NoteProperty -Name "Mem-UnreservedForVm" -Value $currRp.ExtensionData.Runtime.Memory.UnreservedForVm
                $rpConfig | Add-Member -Type NoteProperty -Name "Mem-OverallUsage" -Value $currRp.ExtensionData.Runtime.Memory.OverallUsage
    			$rpConfig | Add-Member -Type NoteProperty -Name "Mem-SharesLevel" -Value $currRp.MemSharesLevel ;
    			$rpConfig | Add-Member -Type NoteProperty -Name "Mem-ExpandableReservation" -Value $currRp.MemExpandableReservation;
    			$rpConfig | Add-Member -Type NoteProperty -Name "Mem-LimitMB" -Value $currRp.MemLimitMB ;
    					
                $vms = Get-VM -Location $currRp.Name -Server $vCenterName | Select-Object -Property "NumCpu","MemoryMB"
                $vmsCount = $TotalCPU = $TotalMem = 0; 
                        
                if ($vms)
                {
                    if ($vms.Count)
                    {
                        $vmsCount = $vms.Count
                    } else { 
                        $vmsCount = 1 
                    }
                            
                    foreach ($vm in $vms) {
    				    $TotalCPU += $vm.NumCPU;
    					$TotalMem += $vm.MemoryMB;
                    }
                }
    				                    
                $rpConfig | Add-Member -Type NoteProperty -Name "VMs" -Value $vmsCount;
                $rpConfig | Add-Member -Type NoteProperty -Name "vCpus" -Value $TotalCPU;
    			$rpConfig | Add-Member -Type NoteProperty -Name "vRAM" -Value $TotalMem;
                        
                if ($verbose)
                {
                    logThis -msg $rpConfig;
                }
                
                $rpConfig
                $index++;
            }
		}
	}
}   

ExportCSV -table $Report

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}