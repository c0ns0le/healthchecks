# The purpose of this script is to scan a VirtualCenter infrastructure for LUNs and report on the following attributes
# Version : 2
# Updated : 10/11/2009
# Author : teiva.rodiere@gmail.com
param(
	[object]$srvConnection="",
	[string]$logDir="output",
	[string]$comment="",
	[bool]$verbose=$false,
	[int]$headerType=1,
	[bool]$returnResults=$true,
	[bool]$showDate=$false
)
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru -Verbose:$false
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global
Set-Variable -Name vCenter -Value $srvConnection -Scope Global
InitialiseModule

$metaInfo = @()
$metaInfo +="tableHeader=Datastores"
$metaInfo +="introduction=The table below provides a comprehensive list of datastores in your environment as well as capacity information for each."
$metaInfo +="chartable=false"
$metaInfo +="titleHeaderType=h$($headerType)"

logThis -msg "Exporting datastores..."
#$datastores = Get-Datastore -Server $srvConnection" -Name ""DTE-EXCHANGE" | sort name;
$datastores = Get-Datastore -Server $srvConnection | sort name;
$index=1;
$dataTable = $datastores | %{
    $datastore = $_;
    logThis -msg "Processing datastore $index of $($datastores.Count) - ""$($datastore.Name)""" -Foregroundcolor Yellow;
    
    #logThis -msg "Processig extent " . $diskExtent.DiskName ." on the datastore" -ForegroundColor white;
	
    # Process each extents as an individual LUN
	$datastore.ExtensionData.Info.Vmfs.Extent | %{
	    $diskExtent = $_;
	   $diskCanonicalName = $diskExtent.DiskName
	   	$esxserver=$datastore  | get-vmhost | Select -First 1
		$esxcli = Get-EsxCli -Vmhost $esxserver
		$allPartitions = ($esxcli.storage.core.device.partition.list())
		$startSectores = ($allPartitions | ?{$_.Type -eq 0 -and $_.Device -eq $diskExtent.DiskName}).StartSector
		#$esxcli.storage.core.device.vaai.status.get()
		$wasVMFS3Volume = $startSectores -contains "128"
		
	    $row = "" | Select "Name"
		$row.Name = $datastore.Name
	    $usedMb = $datastore.CapacityMb - $datastore.FreeSpaceMB
	    $usedPerc = [math]::ROUND( $usedMb / $datastore.CapacityMb * 100)
		#$row | Add-Member -MemberType "NoteProperty" -Name "Cluster" -Value $clustername
	    #$row | Add-Member -MemberType "NoteProperty" -Name "BlockSize" -Value $datastore.ExtensionData.Info.Vmfs.BlockSizeMb
	    	if ($datastore.Type -eq "VMFS")
	    	{
	    		$row | Add-Member -MemberType "NoteProperty" -Name "Type" -Value "$datastore.Type ($($datastore.ExtensionData.Info.Vmfs.BlockSizeMb)MB)"
		} else {
			$row | Add-Member -MemberType "NoteProperty" -Name "Type" -Value $datastore.Type
		}
	    $row | Add-Member -MemberType "NoteProperty" -Name "SizeGB" -Value "$([math]::ROUND($datastore.CapacityMB / 1024))"
	    $row | Add-Member -MemberType "NoteProperty" -Name "FreeGB" -Value "$([math]::ROUND($datastore.FreeSpaceMB / 1024))"
	    #$row | Add-Member -MemberType "NoteProperty" -Name "UsedGB" -Value "$([math]::ROUND($usedMb / 1024))"
	    $row | Add-Member -MemberType "NoteProperty" -Name "Used%" -Value $usedPerc
	    $row | Add-Member -MemberType "NoteProperty" -Name "Mode" -Value $([string]($datastore.ExtensionData.Host.MountInfo.AccessMode | sort -Unique) -replace " ",",") #$datastore.ExtensionData.Host[0].MountInfo.AccessMode	   
	    $row | Add-Member -MemberType "NoteProperty" -Name "Accessible" -Value $datastore.Accessible
	    $row | Add-Member -MemberType "NoteProperty" -Name "Hosts" -Value ($datastore.ExtensionData.Host | measure).Count
	    $row | Add-Member -MemberType "NoteProperty" -Name "VMs" -Value ($datastore.ExtensionData.Vm | measure).Count
	    $row | Add-Member -MemberType "NoteProperty" -Name "Vmfs Upgradable" -Value $datastore.ExtensionData.Info.Vmfs.VmfsUpgradable
	    #$row | Add-Member -MemberType "NoteProperty" -Name "Storage IO Enabled" -Value $datastore.ExtensionData.IormConfiguration.Enabled
	    #$row | Add-Member -MemberType "NoteProperty" -Name "Storage IO Threshold" -Value $datastore.ExtensionData.IormConfiguration.CongestionThreshold
	    $row | Add-Member -MemberType "NoteProperty" -Name "Was Upgraded from VMFS3" -Value $wasVMFS3Volume
	    #$row | Add-Member -MemberType "NoteProperty" -Name "Uuid" -Value $datastore.ExtensionData.Info.Vmfs.Uuid
#	 	$row | Add-Member -MemberType "NoteProperty" -Name "SAN_LunID" -Value $diskExtent.DiskName
	    #$row | Add-Member -MemberType "NoteProperty" -Name "Partition Extents" -Value $diskExtent.Partition      
		
		
		if ($diskCanonicalName)
		{
	        #$scsiLun = Get-ScsiLun -VMHost  $esxhost -CanonicalName $diskCanonicalName #| Select-Object -Property "MultipathPolicy","Vendor","Model"
			# For some reason using the diskCanonicalName of a LUN sometime fails
			# Reason for the failure is weird. When you query a lun which has a canonical name of "vmhbx:y:lunid" where y is 1 or more, the Get-ScsiLun will fail
			# If you try to get-scsilun for the same lun and change "y" to 0, it works.
			#$scsiLun = Get-ScsiLun -VMHost  $esxhost -CanonicalName $($device + ":0:" + $lunid)
            # Find scsi information such as model type brand serial Numbers RuntimeName
            #logThis -msg $diskExtent.DiskName;
            #logThis -msg $diskCanonicalName;
            #logThis -msg $esxhost.Name;
            
            $scsiLunTemp = Get-ScsiLun -CanonicalName $diskCanonicalName -VmHost (Get-VMhost -id ($datastore.ExtensionData.Host | select -First 1).Key) | select -First 1;
            if ($scsiLunTemp)
			{
                #logThis -msg $scsiLunTemp.LunType 
                #logThis -msg $scsiLunTemp.RuntimeName
                #exit;
#                $hbadev,$c,$target,$LID = $scsiLunTemp.RuntimeName.Split(':')					
			#$lunid = $LID.replace("L","");
		
				$lunid = $scsiLunTemp.RuntimeName
				verboseThis $scsiLunTemp
				#Write-Host $scsiLunTemp | fl
               $row | Add-Member -MemberType "NoteProperty" -Name "Scsi Lun Id" -Value $lunid
               $row | Add-Member -MemberType "NoteProperty" -Name "Extent Capacity (GB)" -Value ([math]::ROUND($scsiLunTemp.CapacityMB / 1024, 2))
#				switch ($lunid)
#				{
#				    {$_ %2} {$row | Add-Member -MemberType "NoteProperty" -Name "ExtentLunParity " -Value "Odd"}
#					default {$row | Add-Member -MemberType "NoteProperty" -Name "LunParity" -Value "Even"}
#                }                    
                
                #$row | Add-Member -MemberType "NoteProperty" -Name "Runtime Name" -Value $scsiLunTemp.RuntimeName
			$row | Add-Member -MemberType "NoteProperty" -Name "Multipathing Policy" -Value $scsiLunTemp.MultipathPolicy
			$row | Add-Member -MemberType "NoteProperty" -Name "Vendor" -Value $scsiLunTemp.Vendor
			$row | Add-Member -MemberType "NoteProperty" -Name "Model" -Value $scsiLunTemp.Model
               $row | Add-Member -MemberType "NoteProperty" -Name "SerialNumber" -Value $scsiLunTemp.SerialNumber
                
                $scsiPaths = $scsiLunTemp | Get-ScsiLunPath;
                $row | Add-Member -MemberType "NoteProperty" -Name "Total Paths" -Value $scsiPaths.Count
                $scsiPathsActive = $scsiPaths |where{$_.State -eq "Active"}
                if (!$scsiPathsActive)
                {
                    $row | Add-Member -MemberType "NoteProperty" -Name "Active Paths Count" -Value "0"
		    $row | Add-Member -MemberType "NoteProperty" -Name "Active Adapter" -Value "N/A"
                } else {
		   if ($scsiPathsActive.Count) {
			$row | Add-Member -MemberType "NoteProperty" -Name "Active Paths Count" -Value $scsiPathsActive.Count
		   } else {
	                $row | Add-Member -MemberType "NoteProperty" -Name "ActivePathsCount" -Value "1"
			$row | Add-Member -MemberType "NoteProperty" -Name "ActiveAdapter" -Value $($scsiPathsActive.ExtensionData.Adapter.replace("key-vim.host.",""))
	                $row | Add-Member -MemberType "NoteProperty" -Name "TargetSANPort" -Value $scsiPathsActive.SanId
		
			verboseThis $($scsiPathsActive.ExtensionData.Adapter.replace("key-vim.host.",""))
		
        	   }
		}

                $scsiPathsStandby = $scsiPaths |where{$_.State -eq "Standby"}
		

                if (!$scsiPathsStandby)
                {
                    $row | Add-Member -MemberType "NoteProperty" -Name "StandbyPathCount" -Value "0"
                } else {
		    if ($scsiPathsStandby.Count) {
                    	$row | Add-Member -MemberType "NoteProperty" -Name "StandbyPathCount" -Value $scsiPathsStandby.Count
                    } else {
                    	$row | Add-Member -MemberType "NoteProperty" -Name "StandbyPathCount" -Value "1"
		    }
                }

                $scsiPathsFailed = $scsiPaths |where{$_.State -eq "Fail"}
                if (!$scsiPathsFailed)
                {
                    $row | Add-Member -MemberType "NoteProperty" -Name "FailedPathCount" -Value "0"
                } else {
		    if($scsiPathsFailed.Count) {
	                    $row | Add-Member -MemberType "NoteProperty" -Name "FailedPathCount" -Value $scsiPathsFailed.Count
                    } else {
                    	$row | Add-Member -MemberType "NoteProperty" -Name "FailedPathCount" -Value "1"
		    }
                }
                
                if ($scsiPaths |where{$_.State -eq "Active" -and $_.Preferred -eq $true})
                {
                    $row | Add-Member -MemberType "NoteProperty" -Name "ActiveOnPreferred" -Value "True"
                } else { 
                    $row | Add-Member -MemberType "NoteProperty" -Name "ActiveOnPreferred" -Value "False"
                }

			}
		}
        $row | Add-Member -MemberType "NoteProperty" -Name "Datacenter" -Value $datastore.Datacenter
        if ($verbose)
        {
            logThis -msg $row -ForegroundColor white
        }
		$row
        $index++;
		#}	
	}
	Remove-Variable datastore
}

if ($dataTable)
{
	#$dataTable $dataTable
	if ($metaAnalytics)
	{
		$metaInfo += "analytics="+$metaAnalytics
	}	
	if ($returnResults)
	{
		return $dataTable,$metaInfo,(getRuntimeLogFileContent)
	} else {
		ExportCSV -table $dataTable
		ExportMetaData -meta $metaInfo
	}
}

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
	logThis -msg "-> Disconnected from $srvConnection.Name <-" -ForegroundColor Magenta
}

logThis -msg "Log file written to $of" -ForegroundColor Yellow