#Check vSwitches/Port Groups config in VCS for the 1st host in every cluster
#Version : 0.4
#Author : 04/06/2010, by teiva.rodiere@gmail.com
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[string]$scanType="one",[bool]$showTimestamp=$true)
Write-Host "Executing script $($MyInvocation.MyCommand.path)" -ForegroundColor  green;
Write-Host "Current path is $($pwd.path)" -ForegroundColor  yellow;

$disconnectOnExist = $true;

if (!$srvConnection -or ( ($srvconnection.GetType().Name -ne "VIServerImpl") -and ($srvconnection.GetType().Name -ne "Object[]") ) )
{
	$vcenterName = Read-Host "Enter virtual center server name"
	Write-Host "Connecting to virtual center server $vcenterName.."
	$srvConnection = Connect-VIServer -Server $vcenterName
	$disconnectOnExist = $true;	
} else {
	$disconnectOnExist = $false;
	$vcenterName = $srvConnection.Name;
}

if ((Test-Path -path $logDir) -ne $true) {
	New-Item -type directory -Path $logDir
}


$runtime="$(date -f dd-MM-yyyy)"
$filename = ($($MyInvocation.MyCommand.Name)).TrimEnd('.ps1');
Write-Host "$filename";
if ($comment -eq "" ) {
	$of = $logDir + "\"+$runtime+"_"+$vcenterName.ToUpper()+"_"+$filename+".csv"
} else {
	$of = $logDir + "\"+$runtime+"_"+$vcenterName.ToUpper()+"_"+$filename+"-"+$comment+".csv"
}
Write-Host "This script log to " $of -ForegroundColor Yellow 

Write-Host "Enumerating datacenters..."
$run1Report = $srvConnection | %{ 
  $vcenterName = $_
  Get-Datacenter -Server $vcenterName | %{
  # Store the DC Name ($_ will not be the same in the next loop)
  $DCName = $_.Name
  Write-Host "Processing datacenter " $DCName "..."
  $_ | Get-Cluster | %{
   
    # Store the Cluster Name ($_ will not be the same in the next loop)
    $ClusterName = $_;
 
    # Select only the first returned host
	Write-Host "Gathering ESX hosts deatils in cluster" $ClusterName "...";
	if ($scanType -eq "one") { 
		$esxHosts = $_ | Get-VMHost | Select-Object -First 1;
	} elseif ($scanType -eq "all") {
		$esxHosts = $_ | Get-VMHost * ;
    } else {
	    Write-Host "Invalid scan type (options are; one, all)";
	}
	
	$esxHosts | %{
      # Store the Host ID
      $esxhost = $_
      #$hostView = $_ | Get-View
	  Write-Host "Processing ESX server " $esxhost.Name " from cluster " $ClusterName "..."
      $esxhost | Get-VirtualSwitch | %{
        $vSwitch = $_
        # Create an instance of the $vSwitchConfig object. Store values for DCName, ClusterName, vSwitchName ($_), vSwitchNic and the number of ports
        $vSwitchConfig =  $vSwitch | Select-Object `
          @{n='Datacenter';e={ $DCName }}, `
          @{n='Cluster';e={ $ClusterName }}, `
          @{n='vSwitch';e={ $_.Name }}, `
          @{n='vmNIC';e={ $_.NIC }}, `
          @{n='Ports';e={ $_.NumPorts }}
 
        # Store details of this Virtual Switch
 
        #$NetworkSystem = Get-View $esxhost.ExtensionData.ConfigManager.NetworkSystem
        #$VSwitch = $NetworkSystem.NetworkConfig.VSwitch | ?{ $_.Name -eq $vSwitchConfig.VSwitch }
        $vSwitchConfig | Add-Member -Type NoteProperty -Name "QueriedESXHost" -Value $esxhost.ExtensionData.Name
        $vSwitchConfig | Add-Member -Type NoteProperty -Name "vCenterServer" -Value "$($vcenterName.Name)";
        $vSwitchConfig | Add-Member -Type NoteProperty -Name "AllowPromiscuous" -Value "$($vSwitch.ExtensionData.Spec.Policy.Security.AllowPromiscuous)"
        $vSwitchConfig | Add-Member -Type NoteProperty -Name "AllowMacChanges" -Value "$($vSwitch.ExtensionData.Spec.Policy.Security.MacChanges)"		
        $vSwitchConfig | Add-Member -Type NoteProperty -Name "AllowForgedTransmits" -Value "$($vSwitch.ExtensionData.Spec.Policy.Security.ForgedTransmits)"
        $vSwitchConfig | Add-Member -Type NoteProperty -Name "ShappingEnabled" -Value "$($vSwitch.ExtensionData.Spec.Policy.ShapingPolicy.Enabled)"
        $vSwitchConfig | Add-Member -Type NoteProperty -Name "ActiveNic" -Value "$($vSwitch.ExtensionData.Spec.Policy.NicTeaming.NicOrder.ActiveNic)"
        #$vSwitchConfig | Add-Member -Type NoteProperty -Name "StandbyNic" -Value "$($VSwitch.Spec.Policy.NicTeaming.NicOrder.StandbyNic)"
		
		
		If ($VSwitch.Spec.Policy.NicTeaming.NicOrder.StandbyNic) 
        {
            # If the value is not null, store it
            $vSwitchConfig | Add-Member -Type NoteProperty -Name "StandbyNic" -Value "$($VSwitch.Spec.Policy.NicTeaming.NicOrder.StandbyNic)"
 
        } Else {
 
            # Store StandbyNic as none 
            $vSwitchConfig | Add-Member -Type NoteProperty -Name "StandbyNic" -Value "None"
        }

        # A simple ID for the Port Group (used for column / member name)
        $i = 1
        # Get the port groups from the current vSwitch
        $portGroupsConfig = $vSwitch | Get-VirtualPortGroup | %{
            #$PG = "" | Select-Object "PGName";
            $portGroup = $_
            #$PG.PGName = $_.Name
			#$portGroupConfig = $NetworkSystem.NetworkConfig.PortGroup | ?{ $_.Spec.Name -eq $portGroup.Name }
		    $portGroupConfig = "" | Select-Object "$i.PGName"
            $portGroupConfig."$i.PGName" = $portGroup.Name
            $portGroupConfig | Add-Member -Type NoteProperty -Name "$i.PGVLanId" -Value $portGroup.VLanId
            $portGroupConfig | Add-Member -Type NoteProperty -Name "$i.PGAllowPromiscuous" -Value $portGroupConfig.Spec.Policy.Security.AllowPromiscuous
            $portGroupConfig | Add-Member -Type NoteProperty -Name "$i.PGMacChanges" -Value $portGroupConfig.Spec.Policy.Security.MacChanges
            $portGroupConfig | Add-Member -Type NoteProperty -Name "$i.PGForgedTransmits" -Value $portGroupConfig.Spec.Policy.Security.ForgedTransmits
            
            
            #$vSwitchConfig | Add-Member -Type NoteProperty -Name "$i.PGName" -Value $portGroup.Name
            #$vSwitchConfig | Add-Member -Type NoteProperty -Name "$i.PGVLanId" -Value $portGroup.VLanId
            #$vSwitchConfig | Add-Member -Type NoteProperty -Name "$i.PGAllowPromiscuous" -Value $portGroupConfig.Spec.Policy.Security.AllowPromiscuous
            #$vSwitchConfig | Add-Member -Type NoteProperty -Name "$i.PGMacChanges" -Value $portGroupConfig.Spec.Policy.Security.MacChanges
            #$vSwitchConfig | Add-Member -Type NoteProperty -Name "$i.PGForgedTransmits" -Value $portGroupConfig.Spec.Policy.Security.ForgedTransmits
		
            # Check for Null value on ActiveNic
            If ($portGroupConfig.Spec.Policy.NicTeaming.NicOrder.ActiveNic) {
                # If the value is not null, store it
    		
    					$vSwitchConfig | Add-Member -Type NoteProperty -Name "$i.PGActiveNic" -Value "$($portGroupConfig.Spec.Policy.NicTeaming.NicOrder.ActiveNic)"
    		
    				} Else {
    		
    					# Assuming at least one ActiveNic
    		
    					$vSwitchConfig | Add-Member -Type NoteProperty -Name "$i.PGActiveNic" -Value "Inherited"
    				}
    				
    				# Check for Null value on StandbyNic
    		
    				If ($portGroupConfig.Spec.Policy.NicTeaming.NicOrder.StandbyNic) {
    		
    					# If the value is not null, store it
    		
    					$vSwitchConfig | Add-Member -Type NoteProperty -Name "$i.PGStandbyNic" -Value "$($portGroupConfig.Spec.Policy.NicTeaming.NicOrder.StandbyNic)"
    		
    				} Else {
    		
    					# Check to see if the number of ActiveNics in the Port Group equals the number of Nics on the Virtual Switch
    					# If it does, all Nics are Active, no standby Nics exist
    		
    					If (([Array]$portGroupConfig.Spec.Policy.NicTeaming.NicOrder.ActiveNic).Count -eq ($vSwitchConfig.vmNIC.Count))
    					{
    		
    					# If all NICs are Active
    					$vSwitchConfig | Add-Member -Type NoteProperty -Name "$i.PGStandbyNic" -Value "None"
    		
    					} Else {
    		
    					# Otherwise inherit
    					$vSwitchConfig | Add-Member -Type NoteProperty -Name "$i.PGStandbyNic" -Value "Inherited"
    					}
    				}
    				# Increment the port group counter
    				$i++;
    				# Return the $vSwitchConfig object to the pipeline (added to $Report)
            		#Write-Host $vSwitchConfig -ForegroundColor green
    				$vSwitchConfig
    	    	} 
   	  		}
   		}
	}
  }
}

# Fix the object array, ensure all objects within the 
# array contain the same members (required for Format-Table / Export-CSV)
 
$Members = $run1Report | Select-Object `
  @{n='MemberCount';e={ ($_ | Get-Member).Count }}, `
  @{n='Members';e={ $_.PsObject.Properties | %{ $_.Name } }}
$AllMembers = ($Members | Sort-Object MemberCount -Descending)[0].Members

$Report = $run1Report | %{
  ForEach ($Member in $AllMembers)
  {
    If (!($_ | Get-Member -Name $Member))
    { 
      $_ | Add-Member -Type NoteProperty -Name $Member -Value ""
    }
  }
  Write-Output $_
}

Write-Output $Report | Export-Csv $of -NoTypeInformation
if ($showTimestamp) {
	Write-Output "" >> $of
	Write-Output "" >> $of
	Write-Output "Collected on $(get-date)" >> $of
}

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}