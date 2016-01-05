param(
[Parameter(ValueFromPipelineByPropertyName=$true)]
[string]$name, # Entity Name VMname, Hostname, Clustername
[string]$objType="VirtualMachine", # Type of Entity, if left Empty assumes VirtualMachine. Choices VirtualMachine, HostSystem, ComputeResource
[String[]]$EventTypes, # list of Events available in http://pubs.vmware.com/vfabric5/index.jsp?topic=/com.vmware.vfabric.hyperic.4.6/Events.html
[string[]]$EventCategories, #info, warning, error (case sensitive, must be all in lower case)
[string]$MessageFilter, # pass a string if you want to filter on FullFormattedMessage, usefull if you don't know the EventType and/or Catgory
[object]$MoRef, # Entity MoRef if known
[object]$vCenterObj, # pass an object obtain using command ""get-vc <vcentername>""
[string]$functionlogFile, # set the filename for this procedure to verbose log to
[int]$eventnumber = 1000 # can only read 1000 events at a time
)

function Get-MyEvents {
param(
[Parameter(ValueFromPipelineByPropertyName=$true)]
[string]$name, # Entity Name VMname, Hostname, Clustername
[string]$objType, # Type of Entity, if left Empty assumes VirtualMachine
[String[]]$EventTypes, # list of Events available in http://pubs.vmware.com/vfabric5/index.jsp?topic=/com.vmware.vfabric.hyperic.4.6/Events.html
[string[]]$EventCategories, #Info, warning, error
[string]$MessageFilter, # pass a string if you want to filter on FullFormattedMessage, usefull if you don't know the EventType and/or Catgory
[object]$MoRef, # Entity MoRef if known
[object]$vCenterObj, # pass an object obtain using command ""get-vc <vcentername>""
[string]$functionlogFile # set the filename for this procedure to verbose log to
)
	$result = ""
	if ($functionlogFile)
	{
		$ofverbose = $true
	}
	
	if ($vCenterObj)
	{
		if ($ofverbose) 
		{ 
			Write-Output "-----  vCenter Details -----" | Out-File -FilePath $functionLogFile -Append
			$vCenterObj | select * | Out-File -FilePath $functionLogFile -Append
		}
		
		$global:DefaultVIServer = $vCenterObj
		$si = $vCenterObj.ExtensionData
		
		if ($ofverbose) 
		{	 
			Write-Output "-----  si -----" | Out-File -FilePath $functionLogFile -Append
			$si | select * | Out-File -FilePath $functionLogFile -Append
			
			Write-Output "-----  si.Content.EventManager  -----" | Out-File -FilePath $functionLogFile -Append
			$eventManager | select * | Out-File -FilePath $functionLogFile -Append
			
		}
	} else {
		$si = Get-view ServiceInstance     	
	}
	
	# get the even manager object which is key to this function. Without this no events is exported
	$eventManager = Get-view $si.Content.EventManager
		
	if($eventManager.Client.Version -eq "Vim4" -and $eventnumber -gt 1000){
		Write-Host "Sorry, API 4.0 only allows a maximum event window of 1000 entries!" -ForegroundColor $global:colours.Error
		Write-Host "Please set the variable `$eventnumber to 1000 or less" -ForegroundColor $global:colours.Error
		exit
	}
	if ($ofverbose) 
	{ 
		Write-Output "-----  Event Manager -----" | Out-File -FilePath $functionLogFile -Append
		$eventManager | select * |  Out-File -FilePath $functionLogFile -Append
	}
	
    $EventFilterSpec = New-Object VMware.Vim.EventFilterSpec
	if ($EventTypes)
	{
		$EventFilterSpec.Type = $EventTypes
	}
	$EventFilterSpec.time = New-Object VMware.Vim.EventFilterSpecByTime
    #$EventFilterSpec.time.beginTime = $startdate
    $EventFilterSpec.time.endtime = (Get-Date)
	if($EventCategories){
		$EventFilterSpec.Category = $EventCategories
	}
	if ($MoRef -and $name -ne "")
	{
		Write-Host "Pass either a Entity MoRef or Name, but not both" -ForegroundColor $global:colours.Error
		return
	}
	if ($MoRef)
	{
		if ($ofverbose) 
		{ 
			Write-Output "-----  Event searched by Entity MoRef -----" | Out-File -FilePath $functionLogFile -Append
			Write-Output $MoRef | Out-File -FilePath $functionLogFile -Append
		}
		$EventFilterSpec.Entity = New-Object VMware.Vim.EventFilterSpecByEntity
		$EventFilterSpec.Entity.Entity = $MoRef
	} 
	if ($name -ne "")
	{
		if ($ofverbose) 
		{ 
			Write-Output "-----  Event searched by Entity Name-----" | Out-File -FilePath $functionLogFile -Append
			Write-Output $name | Out-File -FilePath $functionLogFile -Append
		}
		#
		$objEntity = get-view -ViewType $objType -Filter @{'name'=$name} -Server $global:DefaultVIServer
		
		if ($ofverbose) 
		{ 
			Write-Output "-----  Object details -----" | Out-File -FilePath $functionLogFile -Append
			Write-Output $objEntity | Out-File -FilePath $functionLogFile -Append
		}
		$EventFilterSpec.Entity = New-Object VMware.Vim.EventFilterSpecByEntity
		$EventFilterSpec.Entity.Entity = $objEntity.moref
		if ($ofverbose) 
		{ 
			Write-Host "---- EventFilterSpec ----"  | Out-File -FilePath $functionLogFile -Append
			Write-Output $EventFilterSpec | Out-File -FilePath $functionLogFile -Append
		}
		#$eventManager.QueryEvents($EventFilterSpec)
		#return
	}
	
	#$EventFilterSpec.disableFullMessage = $false
	#$result = $eventManager.QueryEvents($EventFilterSpec)
	#$eventnumber = 1000 # can only read 1000 events at a time
	$ecollectionImpl = Get-View ($eventManager.CreateCollectorForEvents($EventFilterSpec))
	$ecollection = $ecollectionImpl.ReadNextEvents($eventnumber)
	$result = $ecollection
	$index = 1
	#Write-Host "---- Iteration: $index :- Events located $($result.count)"
	$index++
	while($ecollection -ne $null){			
		$ecollection = $ecollectionImpl.ReadNextEvents($eventnumber)
		if ($ecollection)
		{
			if ($MessageFilter)
			{
				$result += $ecollection | ?{$_.FullFormattedMessage -match $MessageFilter}
			} else {
				$result += $ecollection
			}
			#Write-Host "---- Iteration: $index :- Events located $($result.count)"
		}
		$index++;
	}
	$ecollectionImpl.DestroyCollector()
	
	$result
}

Get-MyEvents -name $name -objType $objType -EventTypes $EventTypes -EventCategories $EventCategories -MoRef $MoRef -vCenterObj $vCenterObj -functionlogFile $functionlogFile -MessageFilter $MessageFilter