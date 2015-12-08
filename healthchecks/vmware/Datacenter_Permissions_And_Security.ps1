# Exports all Inventory objects which have permissions set on them
#Version : 0.1
#Updated : 8th May 2012
#Author  : teiva.rodiere-at-gmail.com
param([object]$srvConnection="",[string]$logDir="output",[string]$comment="",[bool]$returnOnly=$false)
logThis -msg "Importing Module vmwareModules.psm1 (force)"
Import-Module -Name .\vmwareModules.psm1 -Force -PassThru
Set-Variable -Name scriptName -Value $($MyInvocation.MyCommand.name) -Scope Global
Set-Variable -Name logDir -Value $logDir -Scope Global


# Want to initialise the module and blurb using this 1 function

Function Get-LDAPUser ($UserName) {
    $queryDC = $env:logonserver.Replace('\','');
    $domain = new-object DirectoryServices.DirectoryEntry ("LDAP://$queryDC")
    $searcher = new-object DirectoryServices.DirectorySearcher($domain)
    $searcher.filter = "(&(objectClass=user)(sAMAccountName=$UserName))"
    return $searcher.FindOne().Properties.displayname
} 

logThis -msg "Listing All Inventory objects from $srvConnection..."
$Report = $srvConnection | %{
    $vcentername = $_.Name
    logThis -msg "Exporting permissions from $vcentername..."
    $viperms = Get-VIPermission -Server $_.Name
    logThis -msg "$($viperms.Count) found."
    $index=0;
    $viperms | %{
        logThis -msg "Processing $_ $index/$($viperms.Count)" -foregroundcolor "Yellow"
       	$perms = "" | Select-Object "vCenter";
        $perms.vCenter = $vcentername;
        if ($_.Entity) {
            $objtype = (Get-View $_.Entity).MoRef.Type;
        } else {
            $objtype = "";
        }
       	$perms | Add-Member -Type NoteProperty -Name "Entity" -Value $_.Entity;
        $perms | Add-Member -Type NoteProperty -Name "ObjectType" -Value  $objtype;
        $perms | Add-Member -Type NoteProperty -Name "Principal" -Value $_.Principal;
        $username = ($_.Principal).Replace($env:userdomain,'').Replace('\','');
        #$username = ($userdomain).Replace($env:userdomain,'').Replace('\','');
        $UserDisplayName = Get-LDAPUser $username;
        #$UserDisplayName = Get-LDAPUser $_.Principal;
            
        #$events.Username = $_.UserName;
           	
        $perms | Add-Member -Type NoteProperty -Name "DisplayName" -Value $UserDisplayName; 
        $perms | Add-Member -Type NoteProperty -Name "Role" -Value $_.Role;
        $perms | Add-Member -Type NoteProperty -Name "IsGroup" -Value $_.IsGroup;
        $perms | Add-Member -Type NoteProperty -Name "Propagate" -Value $_.Propagate;
        logThis -msg $perms
        $perms
        $index++;
	}
}

if ($returnOnly)
{
	return $Report
} else {
	ExportCSV -table $Report 
}



if ($srvConnection -and $disconnectOnExist) {
	Disconnect-VIServer $srvConnection -Confirm:$false;
}