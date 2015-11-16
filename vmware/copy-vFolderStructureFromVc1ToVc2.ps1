param(
	[parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()][object]$srvConnections,
	[parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()][string]$sourcevCenterName,
	[parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()][string]$targetvCenterName,
	[string]$targetFolderOnNewVC,
	[string]$sourceFolderToRecreateFromOldVC,
	[string]$logDir="output",
	[bool]$readonly=$true,
	[string]$comment=""
	)
	
if (!(get-pssnapin VMware.VimAutomation.Core))
{
	Add-pssnapin VMware.VimAutomation.Core
}

function ShowSyntax {
	Write-Host "You must delcare srvconnection with 2 vcenters with Credentials"
	Write-Host "Syntax (all fields are mandatory"
	Write-Host "Step 1 (run cmd): Set-PowerCLIConfiguration -DefaultVIServerMode 'multiple'"
	Write-Host "Step 2 (set variables): `$sourcevCenterName=<myservername>; `$targetvCenterName=targetvCenterServerName"
	Write-Host "Step 3 (run cmd): `$srvConnections = get-vc -Server `$sourcevCenterName, `$targetvCenterName"
	Write-Host "Step 4 (run cmd): ./copy-vFolderStructureFromVc1ToVc2.ps1 -srvconnections `$srvconnections -targetvCenterName `$sourcevCenterName -targetvCenterName `$targetvCenterName"
	exit;
}

if (!$srvConnections -or !$sourcevCenterName -or !$targetvCenterName)
{ 
    ShowSyntax
} 

#$srvConnections

#[vSphere PowerCLI] D:\INF-VMware\scripts> $viEvent = $vms | Get-VIEvent -Types info | where { $_.Gettype().Name -eq "VmBeingDeployedEvent"}
$runtime="$(date -f dd-MM-yyyy)"
$filename = ($($MyInvocation.MyCommand.Name)).TrimEnd('.ps1');
Write-Host "$filename";
if ($comment -eq "" ) {
	$of = $logDir + "\"+$runtime+"-"+$filename+"-"+$sourcevCenterName+"_to_"+$targetvCenterName+".csv"
} else {
	$of = $logDir + "\"+$runtime+"-"+$filename+"-"+$sourcevCenterName+"_to_"+$targetvCenterName+"-"+$comment+"_.csv"
}

Write-Host "This script log to " $of -ForegroundColor Yellow 

function Copy-VCFolderStructure {
<#
	.SYNOPSIS
		Copy-VCFolderStructure copies folder and its structure from one VC to another..

	.DESCRIPTION
		Copy-VCFolderStructure can be handy when doing migrations of clusters/hosts between
		Virtual Center servers. It takes folder structure from 'old' VC and it recreates it on 'new'
		VC. While doing this it will also output virtualmachine name and folderid. Why would you
		want to have it ? Let's say that you have a cluster on old virtual center server 
		oldvc.local.lab
		DC1\Cluster1\folder1
		DC1\Cluster1\folderN\subfolderN
		Copy-VCFolderStructure will copy entire folder structure to 'new' VC, and while doing this
		it will output to screen VMs that resides in those structures. VM name that will be shown on
		screen will show also folderid, this ID is the folderid on new VC.  After you have migrated 
		your hosts from old cluster in old VC to new cluster in new VC, and folder structure is there,
		you can use move-vm cmdlet with -Location parameter. As location you would have give the
		folder object that corresponds to vm that is being moved. Property Name is the name of VM
		that was discovered in that folder and Folder is the folderid in which the vm should be moved
		into. This folderid has to first changed to folder, for example :
		$folderobj=get-view -id $folder|Get-VIObjectByVIView
		We can then use $folderobj as parameter to move-vm Location parameter

	.PARAMETER  OldFolder
		This should be the extensiondata of folder that you want to copy to new VC.
		$folderToRecreate=Get-Folder -Server oldVC.lab.local -Name teststruct
		Have in mind that this should be an single folder and not an array.
		

	.PARAMETER  ParentOfNewFolder
		When invoking the function this is the root folder where you want to attach the copied folder.
		Let's say you are copying folder from \DatacenterA\FolderX\myfolder
		If you will have the same structure on the new VC, you would have set ParentOfNew folder
		to FolderX. Still it's not a problem if you have a new structure on new VC. Let's say that on
		new VC you have folder: \DatacenterZ\NewStructure\FolderZ and you want to copy entire
		'myfolder' beneath the FolderZ. In that case, first create a variable that has desired folder
		$anchor=get-folder 'FolderZ' -Server newVC 
		Make sure that $anchor variable will have only 1 element.
		
	.PARAMETER  NewVC
		This parameter describes virtual center to which we are copying the folder structure.
		Copy-VCFolderStructure works only when you are connected to both old and new vc at the
		same time. You need to set your configuration of PowerCLI to handle multiple connections.
		Set-PowerCLIConfiguration -DefaultVIServerMode 'Multiple'
		You can check if you are connected to both servers using $global:DefaultVIServers variable

	.PARAMETER  OldVC
		This parameter describes virtual center from which we are copying the folder structure.
		Copy-VCFolderStructure works only when you are connected to both old and new vc at the
		same time. You need to set your configuration of PowerCLI to handle multiple connections.
		Set-PowerCLIConfiguration -DefaultVIServerMode 'Multiple'
		You can check if you are connected to both servers using $global:DefaultVIServers variable
		
		

	.EXAMPLE
		PS C:\> Set-PowerCLIConfiguration -DefaultVIServerMode 'multiple'
		PS C:\> $DefaultVIServers 
		Ensure that you are connected to both VC servers
		Establish variables:
		This will be the folder that we will be copying from old VC
		$folderToRecreate=Get-Folder -Server $OldVC -Name 'teststruct'
		This will be the folder to which we will be copying the folder structure

		$anchor=get-folder 'IWantToPutMyStructureHere' -Server $NewVC
		$OldVC='myoldvc.lab.local'
		$NewVC='mynewvc.lab.local'
		Copy-VCFolderStructure -OldFolder $folderToRecreate.exensiondata -NewVC $NewVC  -OldVC $OldVC -ParentOfNewFolder $anchor

		
 expects to get exensiondata object from the folder, if you will not provide it, function will
		block it.

	.EXAMPLE
		If you are planning to move vms after hosts/vm/folders were migrated to new VC, you might use it in this way.
		By default Copy-VCFolderStructure will output also vms and their folder ids in which they should reside on new
		VC. You can grab them like this:
		$vmlist=Copy-VCFolderStructure -OldFolder $folderToRecreate.exensiondata -NewVC $NewVC -OldVC $OldVC -ParentOfNewFolder $anchor

		You can now export $vmlist to csv

		$vmlist |export-csv -Path 'c:\migratedvms.csv' -NoTypeInformation

		And once all virtual machines are in new virtual center, you can import this list and do move-vm operation on those

		vms. Each vm has name and folder properties. Folder is a folderid value, which has to be converted to Folder object.

		move-vm -vm $vmlist[0].name -Location (get-view -id $vmlist[0].folder -Server $newVC|get-viobjectbyviview) -Server $newVC
		
		move-vm -vm $vmlist[0].name -Location (get-viobjectbyviview -MoRef $vmlist[0].folder -Server $newVC) -Server $newVC
		
		$newVC = $srvconnection[1]
		$vmlist | %{
			move-vm -vm $_.name -Location (Get-VIObjectByVIView -MoRef $_.folder -Server $newVC) -Server $newVC
		}
		This would move vm that was residing in previously on old VC in migrated folder to its equivalent on new VC.

	.NOTES
		NAME:  Copy-VCFolderStructure
		
		AUTHOR: Grzegorz Kulikowski
		
		NOT WORKING ? #powercli @ irc.freenode.net 
		
		THANKS: Huge thanks go to Robert van den Nieuwendijk for helping me out with the recursion in this function.

	.LINK

http://psvmware.wordpress.com

#>

   param(
   [parameter(Mandatory = $true)]
   [ValidateNotNullOrEmpty()]
   #[VMware.Vim.Folder]$OldFolder,
   [Object]$OldFolder,
   [parameter(Mandatory = $true)]
   [ValidateNotNullOrEmpty()]
   [VMware.VimAutomation.ViCore.Impl.V1.Inventory.FolderImpl]$ParentOfNewFolder,
   [parameter(Mandatory = $true)]
   [ValidateNotNullOrEmpty()]
   [string]$NewVC,
   [parameter(Mandatory = $true)]
   [ValidateNotNullOrEmpty()]
   [string]$OldVC,
   [bool]$readonly=$true
   )
  	if ($readonly)
  	{
		Write-Host "[READ-ONLY] Will create new folder [$NewVC\$ParentOfNewFolder\$($OldFolder.Name)]" -ForegroundColor Magenta
  	} else {
  		Write-Host "[WRITE] New folder [$NewVC\$ParentOfNewFolder\$($OldFolder.Name)]" -ForegroundColor Blue
  		$NewFolder = New-Folder -Location $ParentOfNewFolder -Name $OldFolder.Name -Server $NewVC
  	}
	Write-Host "[Old Folders MoRef]"
	Write-Host "---------------"
	Write-Host "$($OldFolder.MoRef)"
	Write-Host "---------------"
  	Get-VM -NoRecursion -Location ( Get-VIObjectByVIView -Moref $OldFolder.MoRef) -Server $OldVC | Select-Object Name, @{N='Folder';E={$NewFolder.id}}
	#Get-VM -NoRecursion -Location (Get-VIObjectByVIView -MoRef "$($OldFolder.MoRef)") -Server $OldVC | Select-Object Name, @{N='Folder';E={$NewFolder.id}}	
  	foreach ($childfolder in $OldFolder.ChildEntity|Where-Object {$_.type -eq 'Folder'})
	{
		Copy-VCFolderStructure -OldFolder (Get-View -Id $ChildFolder -Server $OldVC) -ParentOfNewFolder $NewFolder -NewVC $NewVC -OldVC $OldVC -readonly $readonly
	}
}

#Write-Host "Here"
#Set-PowerCLIConfiguration -DefaultVIServerMode 'multiple'
#$DefaultVIServers 
#$OldVC='bnevcm01'#$NewVC='aubne-s-msvcenter'
#get-vc -Server $OldVC, $NewVC


###############################################################################################
# SOURCE VCENTER
###############################################################################################
$datacenter = ""
#if (!$sourceFolderToRecreateFromOldVC -or $sourceFolderToRecreateFromOldVC -eq "*")
#{	
	#$sourceFolderToRecreateFromOldVC="*"
	#$targetFolderOnNewVC="*"
	#$sourcevCenterName 
	#$sourceFolderToRecreateFromOldVC
	$sourcevCenterName
	write-host "($srvConnections | ?{$_.Name -eq $sourcevCenterName})"
	$datacenters=Get-datacenter -Server ($srvConnections | ?{$_.Name -eq $sourcevCenterName})
	#Write-Host $datacenters
	if ($datacenters)
	{
		Write-Host ""  -ForegroundColor Magenta
		Write-Host "[ SOURCE VCENTER ]"  -ForegroundColor Magenta
		if ($datacenters.Count)
		{
			Write-Host ""  -ForegroundColor Magenta
			Write-Host "[ SOURCE VCENTER ]"  -ForegroundColor Magenta
			Write-Host "Multiple Datacenters [$($datacenters.Count)] were found in the source vCenter server [$($sourcevCenterName.ToUpper())]" -ForegroundColor Magenta
			Write-Host "Please select from one of the below datacenters:" -ForegroundColor Magenta
			Write-Host ""  -ForegroundColor Magenta
			$index=0
			$indexStartValue=$index
			$datacenters | %{
				Write-Host "       $index) $_" -ForegroundColor Magenta
				$index++;
			}
			$exitValue = $index;
			#Write-Host ""
			Write-Host "       $exitValue) To exit" -ForegroundColor Magenta
			Write-Host "" -ForegroundColor Magenta
			$continue = $true
			$userResponse=""
			while($continue)
			{
				if ($userResponse -eq "")
				{
					$userResponse = Read-Host "Enter the number corresponding to the datacenter ? [$indexStartValue .. $($datacenters.Count-1), or $exitValue to exit]";
				} else {	
					if ($userResponse -ge $indexStartValue -and $userResponse -lt $datacenters.Count)
					{
						Write-Host "" -ForegroundColor Yellow
						Write-Host "--> User choice value = [$userResponse]" -ForegroundColor Yellow
						Write-Host "--> Source datacenter is ""$($sourcevCenterName.ToUpper())\$($datacenters[$userResponse].Name)"""  -ForegroundColor Yellow;
						$continue = $false; 
						$datacenter = $datacenters[$userResponse]
						
					} elseif ($userResponse -eq $exitValue)
					{
						Write-Host "User selected to exit" -ForegroundColor yellow; $continue = $false; 
						exit;
					} else {
						Write-Host "Invalid selection [$userResponse - $($userResponse.Type)]-- please try again"; $userResponse="";
					}
				}
			}
		} else {
			Write-Host "[1] Datacenter found in $sourcevCenterName" -ForegroundColor Yellow
			Write-Host "--> Auto-selecting [$sourcevCenterName\$datacenters]" -ForegroundColor Yellow
			$datacenter = $datacenters
		}
	
		if ($datacenter)
		{
			#Write-Host "[Source vcenter = $sourcevCenterName]"
			#Write-Host "[Target Folder = $targetFolderOnNewVC]" -BackgroundColor Red -ForegroundColor Yellow
			if (!$sourceFolderToRecreateFromOldVC -or $sourceFolderToRecreateFromOldVC -eq "*")
			{
				$sourceFolderToRecreateFromOldVC = "*"; # The top root folder is called VM
			}
			#$sourceFolderToRecreateFromOldVCObj = Get-folder -Name $sourceFolderToRecreateFromOldVC -Server ($srvConnections | ?{$_.Name -eq $sourcevCenterName}) -Type VM | ?{$_.Parent.Name -eq $datacenter.Name}
			$sourceFolderToRecreateFromOldVCObj = Get-folder -Name $sourceFolderToRecreateFromOldVC -Type VM -Location $datacenter -Server ($srvConnections | ?{$_.Name -eq $sourcevCenterName}) |?{$_.Name -ne "vm"}
			#Write-host "$sourceFolderToRecreateFromOldVCObj.Name $datacenter.Name" -ForegroundColor Green
			if ($sourceFolderToRecreateFromOldVCObj.Name -eq $datacenter.Name)
			{
				
			}
			if ($sourceFolderToRecreateFromOldVCObj)
			{
				if ($sourceFolderToRecreateFromOldVCObj.Count)
				{
					$sourceFolderCount = $sourceFolderToRecreateFromOldVCObj.Count
				} else {
					$sourceFolderCount = 1
				}	
				Write-Host "   --> $sourceFolderCount Folders found in $sourcevCenterName\$datacenter" -ForegroundColor Red
			} else {
				Write-Host "   --> NO Folders found in $sourcevCenterName\$datacenter" -ForegroundColor Red
				Write-Host "Exiting.." -ForegroundColor Yellow;
				exit
			}
			

		} else {
			Write-Host "No datacenter was selected. Cannot proceed";
			exit;
		}
		
	} else {
		Write-Host "There are No datacenters in this environment, exiting..."
		exit
	}


	
	
###############################################################################################
# TARGET VCENTER
###############################################################################################	
$datacenter = ""
#if (!$targetFolderOnNewVC -or $targetFolderOnNewVC -eq "*")
#{
	#$targetFolderOnNewVC="*"
	$datacenters=Get-datacenter -Server ($srvConnections | ?{$_.Name -eq $targetvCenterName})
	#Write-Host $datacenters
	if ($datacenters)
	{
		Write-Host ""  -ForegroundColor Magenta
		Write-Host "[ TARGET VCENTER ]"  -ForegroundColor Magenta
		if ($datacenters.Count)
		{
			
			Write-Host "Multiple Datacenters [$($datacenters.Count)] were found in the target vCenter server [$($targetvCenterName.ToUpper())]" -ForegroundColor Magenta
			Write-Host "Please select from one of the below datacenters:" -ForegroundColor Magenta
			Write-Host ""  -ForegroundColor Magenta
			$index=0
			$indexStartValue=$index
			$datacenters | %{
				Write-Host "       $index) $_" -ForegroundColor Magenta
				$index++;
			}
			$exitValue = $index;
			#Write-Host ""
			Write-Host "       $exitValue) To exit" -ForegroundColor Magenta
			Write-Host "" -ForegroundColor Magenta
			$continue = $true
			$userResponse=""
			while($continue)
			{
				if ($userResponse -eq "")
				{
					$userResponse = Read-Host "Enter the number corresponding to the datacenter ? [$indexStartValue .. $($datacenters.Count-1), or $exitValue to exit]"
					
				} else {				
					if ($userResponse -ge $indexStartValue -and $userResponse -lt $datacenters.Count)
					{
						Write-Host "" -ForegroundColor Yellow
						Write-Host "--> User choice value = [$userResponse]" -ForegroundColor Yellow
						Write-Host "--> Target datacenter is ""$($targetvCenterName.ToUpper())\$($datacenters[$userResponse].Name)"""  -ForegroundColor Yellow;
						$continue = $false; 
						$datacenter = $datacenters[$userResponse]
						
					} elseif ($userResponse -eq $exitValue)
					{
						Write-Host "User selected to exit" -ForegroundColor yellow; $continue = $false; 
						exit;
					} else {
						Write-Host "Invalid selection [$userResponse - $($userResponse.Type)]-- please try again"; $userResponse="";
					}
				}
			}
		} else {
			Write-Host "[1] Datacenter found in $targetvCenterName" -ForegroundColor Yellow
			Write-Host "--> Auto-selecting [$targetvCenterName\$datacenters]" -ForegroundColor Yellow
			$datacenter = $datacenters
		}
	
		if ($datacenter)
		{
			#Write-Host "[Target vcenter = $targetvCenterName]"
			#Write-Host "[Target Folder = $targetFolderOnNewVC]" -BackgroundColor Red -ForegroundColor Yellow
			if (!$targetFolderOnNewVC -or $targetFolderOnNewVC -eq "*")
			{
				$targetFolderOnNewVC = "vm"; # The top root folder is called VM
				Write-Host "`ttargetFolderOnNewVC=$targetFolderOnNewVC"
			}
			$targetFolderOnNewVCObj = Get-folder -Name $targetFolderOnNewVC -Server ($srvConnections | ?{$_.Name -eq $targetvCenterName}) -Type VM -Location $datacenter # | ?{((get-view $_.Parent).Parent).Type -eq "Datacenter"}
			Write-Host "`ttargetFolderOnNewVCObj=$targetFolderOnNewVCObj"
			#Get-Folder -Type VM -Server ($srvConnections | ?{$_.Name -eq $sourcevCenterName}) -Name $sourceFolderToRecreateFromOldVC | ?{((get-view $_.Parent).Parent).Type -eq "Datacenter"}
			#Write-Host "   --> $($targetFolderOnNewVCObj.Count) Folders found in $targetvCenterName\$datacenter" -ForegroundColor Red
		} else {
			Write-Host "No datacenter was selected. Cannot proceed";
			exit;
		}
		
	} else {
		Write-Host "There are No datacenters in this environment, exiting..."
		exit
	}
#}


Write-Host "sourceFolderToRecreateFromOldVC=$sourceFolderToRecreateFromOldVC, targetFolderOnNewVC=$targetFolderOnNewVC"
if (!$sourceFolderToRecreateFromOldVC -or !$targetFolderOnNewVC -or !$targetFolderOnNewVCObj)
{
	#$targetFolderOnNewVCObj = Get-Folder -Type VM -Server ($srvConnections | ?{$_.Name -eq $targetvCenterName}) -Name $targetFolderOnNewVC
	if (!$sourceFolderToRecreateFromOldVC)
	{
		Write-Host "Invalid sourceFolderToRecreateFromOldVC value [$sourceFolderToRecreateFromOldVC]" -ForegroundColor Red
	}
	if (!$targetFolderOnNewVCObj)
	{
		Write-Host "Invalid object targetFolderOnNewVCObj [$targetFolderOnNewVCObj]" -ForegroundColor Red
	}
	
	ShowSyntax
	
} else {
	#Write-Host "You have selected to write the content of [$sourcevCenterName\$sourceFolderToRecreateFromOldVC] to [$targetvCenterName\$targetFolderOnNewVC]" -ForegroundColor Yellow
	#Write-Host "Gathering a list of folders from to [$sourcevCenterName]..."
	#$sourceFolderToRecreateFromOldVCObj=Get-Folder -Type VM -Server ($srvConnections | ?{$_.Name -eq $sourcevCenterName}) -Name $sourceFolderToRecreateFromOldVC | ?{((get-view $_.Parent).Parent).Type -eq "Datacenter"}
	$folderCount=0
	if ($sourceFolderToRecreateFromOldVCObj)
	{
		if ($sourceFolderToRecreateFromOldVCObj.Count)
		{
			$folderCount=$sourceFolderToRecreateFromOldVCObj.Count
		} else {
			$folderCount=1
		}
	}
	Write-Host "--> [$folderCount] Found -- Processing each" -ForegroundColor Magenta
	
	$index=1
	$vmlist = $sourceFolderToRecreateFromOldVCObj | %{
			Write-Host "  [$index/$folderCount] - $_" -ForegroundColor Yellow		
			#Write-Host "Processing folder(s) and sub-folder(s) from [$sourcevCenterName\$($_.Name)]" -ForegroundColor Green
			$foldervmlist=Copy-VCFolderStructure -OldFolder $_.ExtensionData -NewVC ($srvConnections | ?{$_.Name -eq $targetvCenterName}) -OldVC  ($srvConnections | ?{$_.Name -eq $sourcevCenterName}) -ParentOfNewFolder $targetFolderOnNewVCObj -readonly $readonly
			Write-Output $foldervmlist
			Write-host $foldervmlist
			$index++;
	}
	#$vmlist=Copy-VCFolderStructure -OldFolder $sourceFolderToRecreateFromOldVCObj.ExtensionData -NewVC ($srvConnections | ?{$_.Name -eq $sourcevCenterName}) -OldVC ($srvConnections | ?{$_.Name -eq $targetvCenterName}) -ParentOfNewFolder $targetFolderOnNewVCObj -readonly $false
	#$vmlist=Copy-VCFolderStructure -OldFolder $sourceFolderToRecreateFromOldVCObj.ExtensionData -NewVC $NewVC -OldVC $OldVC -ParentOfNewFolder $targetFolderOnNewVCObj -readonly $false

	#$vmlist
	if ($vmlist)
	{
		$vmlist | Export-csv -Path $of -NoTypeInformation	
		Write-Host "Output written to $of" -ForegroundColor Yellow
	}
}
