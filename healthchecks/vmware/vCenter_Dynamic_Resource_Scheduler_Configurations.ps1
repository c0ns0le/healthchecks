# Exports DRS rules for each Cluster in a virtual center server
# Last updated: 15/10/2009
# Authored by: teiva.rodiere-at-gmail.com
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$verbose=$false)
logThis -msg "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global




# Want to initialise the module and blurb using this 1 function


#logThis -msg "Enumerating ..."
$run1Report =   $srvConnection | %{
        $vCenterServer = $_.Name;
        logThis -msg "Processing DRS Rules in vCenter server ""$vCenterServer""..." -ForegroundColor Cyan
		$drsRules = Get-DrsRule -Cluster * -Server $vCenterServer 
        if ($drsRules)
        {
            if ($drsRules -is [system.array])
            {
                $drsRulesCount = $drsRules.Count
            } else { $drsRulesCount = 1 }
            $index=1;
    		$drsRules |  %{
    			logThis -msg "Processing DRS rules $index/ $drsRulesCount - $($_.Name)" -ForegroundColor Yellow
    			$drsrule = "" | Select-Object "Name";
    			$drsrule.Name = $_.Name;
                $drsrule | Add-Member -MemberType NoteProperty -Name "Enabled" -Value $_.Enabled;					
    			$vmlist =@(); 
    			foreach ($vm in (Get-VM -Id  $_.VMIDs)) {
    				$vmlist += $vm.Name; 
    			}
    			
    			$drsrule | Add-Member -MemberType NoteProperty -Name "AffectedVMs" -Value "$($vmlist)";
    			$drsrule | Add-Member -MemberType NoteProperty -Name "KeepTogether" -Value $_.KeepTogether;
                $drsrule | Add-Member -MemberType NoteProperty -Name "UserCreated" -Value $_.ExtensionData.UserCreated;
                $drsrule | Add-Member -MemberType NoteProperty -Name "Mandatory" -Value $_.ExtensionData.Mandatory;
                $drsrule | Add-Member -MemberType NoteProperty -Name "Cluster" -Value $_.Cluster;
    			$drsrule | Add-Member -Type NoteProperty -Name "vCenter" -Value $vCenterServer;
                $drsrule | Add-Member -Type NoteProperty -Name "Datacenter" -Value  $(Get-Datacenter -Cluster $($_.Cluster)).Name
    			if ($verbose)
                {
                    logThis -msg $drsrule
                }
                $drsrule
                
                $index++;
            }
        } else {
            logThis -msg "No DRS rules found" -ForegroundColor Yellow;
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

ExportCSV -table $Report

logThis -msg "Logs written to " $of -ForegroundColor  yellow;

if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}