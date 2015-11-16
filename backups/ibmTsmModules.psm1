#ibmTsmModules.psm1
#
# format numbers to good visiual formatting 
# Example= 12345 would be returned as 12,345.00
# use the "deci" value to set the number of decimal places for your numbers. the default is 0
## MAKE SURE YOU Run 
# Import-Module -Name .\ibmTsmModules.psm1 -Force -PassThru
#
#
# PUT IN THERE ALL THE REQUIRED COMMANDS AND HASH TABLE OBJECTS NECESSARY FOR ADDRESSING IN THE MAIN SCRIPT
#
#
#
# Global Parameters


function collectTSMInformation(
	[Parameter(Mandatory=$true)][string]$server,
	[Parameter(Mandatory=$true)][string]$username,
	[Parameter(Mandatory=$true)][string]$password,
	[int]$reportPeriodDays=30,
	[bool]$showRuntime=$true	
	)
{
	#$global:today=Get-Date
	#$lastDays=30
	#$startDate=(Get-Date $today).AddDays(-$lastDays)

	$node = @{}
	$node["Name"]= $server
	$node["Connection"] = @{}
	$node["Connection"]["Target"] = $server
	$node["Connection"]["Username"] = $username
	$node["Connection"]["Password"] = $password
	if ($showRuntime) {$sw = [Diagnostics.Stopwatch]::StartNew(); $sw.Start()}
	Write-Host "`t-> Getting Server Status"  -NoNewline;;	$status = queryTSM -cmd "select * from status" -connection $node.Connection
    if ($status.SUMMARYRETENTION)
    {
        Write-Host "`t-> Summary retention $($status.SUMMARYRETENTION)"
        $reportPeriodDays=$status.SUMMARYRETENTION
    }
	if ($showRuntime) {write-host "`t`t[$($sw.Elapsed.Hours) hrs $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec to complete]" -foregroundcolor yellow; $sw.Reset(); $sw.Start()}
	if ($status)
	{
		$node["Status"] = $status
		#Write-Host "`t-> Getting Platform Information";	$node["Platform"] = getServerPlatform -connection $node.Connection; if ($showRuntime) {write-host "`t`t[$($sw.Elapsed.Hours) hrs $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec to complete]" -foregroundcolor yellow; $sw.Reset(); $sw.Start()}
		Write-Host "`t-> Setting Name" -NoNewline;	$node["Name"] = $node.Status.SERVER_NAME ;	if ($showRuntime) {write-host "`t`t[$($sw.Elapsed.Hours) hrs $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec to complete]" -foregroundcolor yellow; $sw.Reset(); $sw.Start()}		
		Write-Host "`t-> Getting Libraries";
		$dataTable = queryTSM -cmd "select * from libraries" -connection $node.Connection;	
		$node["Libraries"] = @{}
		$dataTable | %{
			$library=$_			
			# Storage the library information into the Library 
			$node.Libraries.Add($library.LIBRARY_NAME,$library)
			
			# Get the list of TAPES/Volumes for that array
			Write-Host "`t`t-> Getting Library Volumes/Tapes for $($library.LIBRARY_NAME)" -NoNewline; 
			$volumesTable = queryTSM -cmd $("select * from libvolumes where LIBRARY_NAME = '$($library.LIBRARY_NAME)'") -connection $node.Connection
			if ($showRuntime) {write-host "`t`t[$($sw.Elapsed.Hours) hrs $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec to complete]" -foregroundcolor yellow; $sw.Reset(); $sw.Start()}
			$node.Libraries["$($library.LIBRARY_NAME)"] | Add-Member -MemberType NoteProperty -Name "Libvolumes" -Value $volumesTable
			
			# Get the list of Library Hardware Information
			Write-Host "`t`t-> Getting Hardware Information for ""$($library.LIBRARY_NAME)"" " -NoNewline; 
			$libdetails = queryTSM -cmd "show slots '$($library.LIBRARY_NAME)'" -connection $node.Connection;	
			if ($showRuntime) {write-host "`t`t[$($sw.Elapsed.Hours) hrs $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec to complete]" -foregroundcolor yellow; $sw.Reset(); $sw.Start()}
			($libdetails | gm -MemberType NoteProperty).Name |%{
				$node.Libraries."$($library.LIBRARY_NAME)" | Add-Member -MemberType NoteProperty -Name "$_" -Value "$($libdetails.$_)"
			}
			$node.Libraries."$($library.LIBRARY_NAME)" | Add-Member -MemberType NoteProperty -Name "USED_SLOTS" -Value $($node.Libraries."$($library.LIBRARY_NAME)".Libvolumes.Count)
			$node.Libraries."$($library.LIBRARY_NAME)" | Add-Member -MemberType NoteProperty -Name "FREE_SLOTS" -Value $($libdetails.Slots - $node.Libraries."$($library.LIBRARY_NAME)".Libvolumes.Count)

		}
		Write-Host "`t-> Getting Volumes" -NoNewline; $node["Volumes"] = queryTSM -cmd "select * from volumes" -connection $node.Connection; if ($showRuntime) {write-host "`t`t[$($sw.Elapsed.Hours) hrs $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec to complete]" -foregroundcolor yellow; $sw.Reset(); $sw.Start()}
		Write-Host "`t-> Getting Nodes/Clients" -NoNewline; $node["Clients"] = queryTSM -cmd "select * from nodes" -connection $node.Connection; if ($showRuntime) {write-host "`t`t[$($sw.Elapsed.Hours) hrs $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec to complete]" -foregroundcolor yellow; $sw.Reset(); $sw.Start()}
		Write-Host "`t-> Getting Database" -NoNewline; $node["Database"] = queryTSM -cmd "select * from db" -connection $node.Connection; if ($showRuntime) {write-host "`t`t[$($sw.Elapsed.Hours) hrs $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec to complete]" -foregroundcolor yellow; $sw.Reset(); $sw.Start()}
		Write-Host "`t-> Getting Log"  -NoNewline;	$node["Logs"] = queryTSM -cmd "select * from log" -connection $node.Connection; if ($showRuntime) {write-host "`t`t[$($sw.Elapsed.Hours) hrs $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec to complete]" -foregroundcolor yellow; $sw.Reset(); $sw.Start()}
		Write-Host "`t-> Getting TSM Options"  -NoNewline;	$node["Options"] = queryTSM -cmd "select * from options" -connection $node.Connection ;  if ($showRuntime) {write-host "`t`t[$($sw.Elapsed.Hours) hrs $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec to complete]" -foregroundcolor yellow; $sw.Reset(); $sw.Start()}
		Write-Host "`t-> Getting DB Spaces" -NoNewline; $node["DBspace"] = queryTSM -cmd "select * from dbspace" -connection $node.Connection; if ($showRuntime) {write-host "`t`t[$($sw.Elapsed.Hours) hrs $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec to complete]" -foregroundcolor yellow; $sw.Reset(); $sw.Start()}
		Write-Host "`t-> Getting Licenses" -NoNewline;	$node["Licenses"] = queryTSM -cmd "select * from licenses" -connection $node.Connection; if ($showRuntime) {write-host "`t`t[$($sw.Elapsed.Hours) hrs $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec to complete]" -foregroundcolor yellow; $sw.Reset(); $sw.Start()}
		Write-Host "`t-> Getting License Allocations" -NoNewline;	$node["License_Details"] = queryTSM -cmd "select * from license_details" -connection $node.Connection; if ($showRuntime) {write-host "`t`t[$($sw.Elapsed.Hours) hrs $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec to complete]" -foregroundcolor yellow; $sw.Reset(); $sw.Start()}
		Write-Host "`t-> Getting Occupancy" -NoNewline; $node["Occupancy"] = queryTSM -cmd "select * from occupancy" -connection $node.Connection; if ($showRuntime) {write-host "`t`t[$($sw.Elapsed.Hours) hrs $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec to complete]" -foregroundcolor yellow; $sw.Reset(); $sw.Start()}
		Write-Host "`t-> Getting Storage Pools" -NoNewline; $node["Storage_Pools"] = queryTSM -cmd "select * from stgpools" -connection $node.Connection; if ($showRuntime) {write-host "`t`t[$($sw.Elapsed.Hours) hrs $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec to complete]" -foregroundcolor yellow; $sw.Reset(); $sw.Start()}
		Write-Host "`t-> Getting Audit Occupancy" -NoNewline; $node["Auditocc"] = queryTSM -cmd "select * from auditocc" -connection $node.Connection; if ($showRuntime) {write-host "`t`t[$($sw.Elapsed.Hours) hrs $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec to complete]" -foregroundcolor yellow; $sw.Reset(); $sw.Start()}
		Write-Host "`t-> Getting DRM Status" -NoNewline; $node["DRMStatus"] = queryTSM -cmd "select * from drmstatus" -connection $node.Connection; if ($showRuntime) {write-host "`t`t[$($sw.Elapsed.Hours) hrs $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec to complete]" -foregroundcolor yellow; $sw.Reset(); $sw.Start()}
		Write-Host "`t-> Getting DR Media" -NoNewline; $node["DRMMedia"] = queryTSM -cmd "select * from drmedia" -connection $node.Connection; if ($showRuntime) {write-host "`t`t[$($sw.Elapsed.Hours) hrs $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec to complete]" -foregroundcolor yellow; $sw.Reset(); $sw.Start()}		
		Write-Host "`t-> Getting Client Schedules" -NoNewline; $node["CSchedules"] = queryTSM -cmd "query schedule format=detailed" -connection $node.Connection; if ($showRuntime) {write-host "`t`t[$($sw.Elapsed.Hours) hrs $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec to complete]" -foregroundcolor yellow; $sw.Reset(); $sw.Start()}
        	Write-Host "`t-> Getting Admin Schedules" -NoNewline; $node["ASchedules"] = queryTSM -cmd "query schedule format=detailed type=admin" -connection $node.Connection; if ($showRuntime) {write-host "`t`t[$($sw.Elapsed.Hours) hrs $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec to complete]" -foregroundcolor yellow; $sw.Reset(); $sw.Start()}
		Write-Host "`t-> Getting Event stats" -NoNewline; $node["Event_stat"] = queryTSM -cmd "select status,count(status)as Num from events group by status order by 2 desc" -connection $node.Connection; if ($showRuntime) {write-host "`t`t[$($sw.Elapsed.Hours) hrs $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec to complete]" -foregroundcolor yellow; $sw.Reset(); $sw.Start()}
        	Write-Host "`t-> Getting Client Events" -NoNewline; $node["CEvents"] = queryTSM -cmd "select * from events where domain_name is not null and (status != 'Completed' and status !='Future')" -connection $node.Connection; if ($showRuntime) {write-host "`t`t[$($sw.Elapsed.Hours) hrs $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec to complete]" -foregroundcolor yellow; $sw.Reset(); $sw.Start()}
        	Write-Host "`t-> Getting Admin Events" -NoNewline; $node["AEvents"] = queryTSM -cmd "select * from events where domain_name is null and (status != 'Completed' and status !='Future')" -connection $node.Connection; if ($showRuntime) {write-host "`t`t[$($sw.Elapsed.Hours) hrs $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec to complete]" -foregroundcolor yellow; $sw.Reset(); $sw.Start()}
        	Write-Host "`t-> Getting Actlog errors" -NoNewline; $node["ActlogE"] = queryTSM -cmd "select * from actlog where severity='E' and msgno != '2034'" -connection $node.Connection; if ($showRuntime) {write-host "`t`t[$($sw.Elapsed.Hours) hrs $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec to complete]" -foregroundcolor yellow; $sw.Reset(); $sw.Start()}
        	Write-Host "`t-> Getting Summary (up to $reportPeriodDays Days) " -NoNewline;	$node["Summary"] = queryTSM -cmd "select ENTITY,START_TIME,END_TIME,ACTIVITY,SUCCESSFUL,BYTES from summary where decimal(days(current_timestamp)-days(start_time)) <= $reportPeriodDays" -connection $node.Connection; if ($showRuntime) {write-host "`t`t[$($sw.Elapsed.Hours) hrs $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec to complete]" -foregroundcolor yellow; $sw.Reset(); $sw.Start()}

		# On success, return the object
		if ($node)
		{
			return $node
		} else {
			return $null
		}

	} else {
		Write-Host "`t-> Not able to connect to $($_.Target).." -ForegroundColor Red
		return $null
	}
}


function collectTSMInformation2(
	[Parameter(Mandatory=$true)][string]$server,
	[Parameter(Mandatory=$true)][string]$username,
	[Parameter(Mandatory=$true)][string]$password,
	[int]$reportPeriodDays=30,
	[bool]$showRuntime=$true
	)
{
	#$global:today=Get-Date
	#$lastDays=30
	#$startDate=(Get-Date $today).AddDays(-$lastDays)
	
	#Fields: <Name>,<TSM Command>,<options>
	# <Name>
	# 	- It is generally the same name and spelling of Tables inside TSMs database to avoid confusion
	#
	#<TSM Command>
	#	- Any dsmadc.exe query | select statements
	#	Special variable: <field>
	#			if using <field>, the routine below will replasce <field> with the name of the ProcessForEachPrereq=<Name>
	#
	#<options>:
	#	Prereq=<Name>:
	#		<Name> is the Name of an oject like Status, CLients, Libraries, etc..
	#	ProcessForEeach=<FieldName>:
	#		<FieldName> corresponds to a field found in the "Prereq" object defined by <Name>. For example if you specified "Prereq=Libraries,ProcessForEachPrereq=LIBRARY_NAME" the routine
	#		below would iterate throught the tsmserver.Libraries and process the command for each LIBRARY_NAME found inside the Libraries object
	#		
	#
	
	$cmd = @(
		("Status","select * from status","Prereq=,ProcessForEachPrereq="),
		("Clients","select * from nodes","Prereq=,ProcessForEachPrereq="),
		("Libraries","select * from libraries","Prereq=,ProcessForEachPrereq="),
		("Libraries\Volumes","select * from libvolumes where LIBRARY_NAME = '<field>'","Prereq=Libraries,ProcessForEachPrereq=LIBRARY_NAME"),
		("Libraries\Slots","show slots '<field>'","Prereq=Libraries,ProcessForEachPrereq=LIBRARY_NAME"),
		("Database","select * from db","Prereq=,ProcessForEachPrereq="),
		("Logs","select * from log","Prereq=,ProcessForEachPrereq="),
		("DBSpace","select * from dbspace","Prereq=,ProcessForEachPrereq="),
		("licences","select * from licenses","Prereq=,ProcessForEachPrereq="),
		("Occupancy","select * from occupancy","Prereq=,ProcessForEachPrereq="),
		("Storage_Pools","select * from stgpools","Prereq=,ProcessForEachPrereq="),
		("Auditocc","select * from auditocc","Prereq=,ProcessForEachPrereq="),
		("DRMStatus","select * from drmstatus","Prereq=,ProcessForEachPrereq="),
		("DRMedia","select * from drmedia","Prereq=,ProcessForEachPrereq="),
		("Volumes","select * from volumes","Prereq=,ProcessForEachPrereq="),
		("Schedules","query schedule format=detailed","Prereq=,ProcessForEachPrereq="),
		("Summary","select ENTITY,START_TIME,END_TIME,ACTIVITY,SUCCESSFUL,BYTES from summary where decimal(days(current_timestamp)-days(start_time)) <= $reportPeriodDays","Prereq=:,ProcessForEachPrereq=")		
	)

	$node = @{}
	$node["Name"]= $server
	$node["Connection"] = @{}
	$node["Connection"]["Target"] = $server
	$node["Connection"]["Username"] = $username
	$node["Connection"]["Password"] = $password	
	
	# Process each command and take some time measurements and put it into $runtime
	$runtime = $cmd | %{
		$fullpath=$_[0]
		$directory=$_[0] -replace "\\",'.'
		$directories=$_[0] -replace "\\",'.' -split '\.'
		$tableName = $directories[$directories.Count - 1]
		$query=$_[1]
		$specialProcessing=$_[2]
		$specialInstructions=$specialProcessing -split ","
		
		Write-Host "`t-> Getting $tableName [$tableName]" -NoNewline ; 
		$runTimeStats= New-Object System.Object
		$runTimeStats | Add-Member -MemberType NoteProperty -Name "Object" -Value $tableName
		$runTimeStats | Add-Member -MemberType NoteProperty -Name "Query" -Value $query
		$runTimeStats | Add-Member -MemberType NoteProperty -Name "Special_Instructions" -Value $specialProcessing
		$proceed=$false
		# Start STOP Watch
		$sw = [Diagnostics.Stopwatch]::StartNew(); 
		$sw.Start()
			
		$si=@{}
		$specialInstructions | %{
			$instrName,$instrValue=$_ -split '='
			$si[$instrName]=$instrValue
		}
		
		if ($si.Prereq -and $node["$($si.Prereq)"] -and $si.ProcessForEachPrereq)
		{
			# Process each object within the prerequisite
			$index=0
			$node["$($si.Prereq)"] | %{
				$table = $_
				$newCMD = $query -replace "<field>",$($table.$($si.ProcessForEachPrereq))
				$runTimeStats | Add-Member -MemberType NoteProperty -Name "Subquery$index" -Value $newCMD
				$existingPathSoFar="node"
				$directories | select -First ($directories.Count -1) | %{
					$fieldname=$_
					Write-Host "check if field $existingPathSoFar.$fieldname exists"
					$existingPathSoFar += ".$fieldname"
					# Check if the child item exists
					if (!(iex "`$$existingPathSoFar"))
					{ 
						Write-Host ">> Creating missing $existingPathSoFar"
						# It doesn't, initialise it
						$newFolder=$existingPathSoFar -replace ".$fieldname",""
						(iex "`$$newFolder").Add($fieldname,@{})
					} else {
						Write-Host ">> $existingPathSoFar already exists"
					}
				}
				# we must assume that all folders have been created		
				$newpath="node.$directory" -replace ".$tableName",""
				Write-Host ">> Latest $newpath"
				$newTable = queryTSM -cmd $newCMD -connection $node.Connection
				if ($newTable)
				{
					$newTable
					(iex "`$$newpath").Add("$tableName",$newTable)
				} else {
					Write-Host "newTable is empty"
				}
			}
		} elseif ( ($si.Prereq -and $node["$($si.Prereq)"] -and !$si.ProcessForEachPrereq) -or (!$si.Prereq -and !$si.ProcessForEachPrereq) ) {
			# The pre-requisite Object doesn't exist therefore we skip processing and get on with the next one.
			$runTimeStats | Add-Member -MemberType NoteProperty -Name "Subquery" -Value ""
			#$node["$tableName"] = @{}
			
			$node.Add("$tableName",(queryTSM -cmd $query -connection $node.Connection))
			
		}
	
		if ($showRuntime) {
			write-host "`t`t`t(The query took $($sw.Elapsed.Hours)hrs $($sw.Elapsed.Minutes)min $($sw.Elapsed.Seconds)sec to complete)" -ForegroundColor Yellow;
		}
		$runTimeStats | Add-Member -MemberType NoteProperty -Name "Time_Taken" -Value " $($sw.Elapsed.Hours)hrs $($sw.Elapsed.Minutes)min $($sw.Elapsed.Seconds)sec"
		Write-Output $runTimeStats
		Remove-Variable sw		
	}
	# Note the run time stats for this node
	$node["Runtime"]=$runtime
	
	return $node
}



#
# This function is used to accept parameters like @("Server","Username","Password") for a single server
# or @(("Server","Username","Password"),("Server","Username","Password")) for multiple server to query
# It returns a table of devices formatted nicely. 
#Example using:
#  createDevoce:ost -servers @(("Server","admin","123pwd"),("Server2","admin2","asdminPwd0123"))
# would return:
#
#	deviceList[0]
#		\ Target (value would be Server)
#		\ Username (value would be admin)
#		\ Password (value would be 123pwd)
#	deviceList[1]
#		\ Target (value would be Server2)
#		\ Username (value would be admin2)
#		\ Password (value would be asdminPwd0123)
#
# In this example you recall the information using something like $deviceList[0].Target or $deviceList[0].Username
function createDeviceList ([Parameter(Mandatory=$true)][System.Object]$servers)
{
	$deviceList = @()
	if ($servers)
	{
		if ($servers[0].Count -gt 1)
		{
			Write-Host ":: Multiple host declared - $($servers.GetType())"
			$deviceList = $servers | %{
				$obj = New-Object System.Object
				$obj | Add-Member -MemberType NoteProperty -Name "Target" -Value	$_[0]
				$obj | Add-Member -MemberType NoteProperty -Name "Username" -Value	$_[1]
				$obj | Add-Member -MemberType NoteProperty -Name "Password" -Value	$_[2]
				$obj
			}
		} else {
			Write-Host ":: Single host declared"
			$deviceList = New-Object System.Object
			$deviceList | Add-Member -MemberType NoteProperty -Name "Target" -Value	$servers[0]
			$deviceList | Add-Member -MemberType NoteProperty -Name "Username" -Value	$servers[1]
			$deviceList | Add-Member -MemberType NoteProperty -Name "Password" -Value	$servers[2]
		}
		
		if ($deviceList)
		{
			return $deviceList
		} else {
			return $null
		}
	} else {
		Write-Host "Sepcify a host,username, and password"
		return $null
	}
}

#function formatNumbers([Parameter(Mandatory=$true)]$val,$deci=0)
#{
	#return "{0:N$deci}" -f $val
#}

# THIS FUNCTON is responsible for dumping the data and meta data information on this in the same directory set by $logDir, then updates the $global:indexer file so that the 
# report generator can pick everthing up and produce the report.
function export (
		[Parameter(Mandatory=$true)][string]$title,
		[Parameter(Mandatory=$true)][object]$dataTable,
		[string]$description="",
		[string]$headerType="h2",
		[string]$displayTableOrientation="List",
		[string]$metaAnalytics="",
		[string]$showTableCaption="false"
		)
{
	$csvFilename=$global:outputCSV -replace ".csv","-$($title -replace ' ','_').csv"
	$metaFilename=$csvFilename -replace '.csv','.nfo'
	if ($global:DEBUG)
	{
		$SHOWCOMMANDS = "$cmd"
	}
	$metaInfo = @()
	$metaInfo +="tableHeader=$title $SHOWCOMMANDS"
	$metaInfo +="introduction=$description"
	$metaInfo +="titleHeaderType=$headerType"
	$metaInfo +="displayTableOrientation=$displayTableOrientation"
	$metaInfo +="chartable=false"
	$metaInfo +="showTableCaption=$showTableCaption"
	if ($metaAnalytics) {$metaInfo += $metaAnalytics}
	ExportCSV -table $dataTable -thisFileInstead $csvFilename 
	ExportMetaData -metadata $metaInfo -thisFileInstead $metaFilename
	updateReportIndexer -string "$(split-path -path $csvFilename -leaf)"
}

function setSectionHeader (
		[Parameter(Mandatory=$true)][string]$type="h1",
		[Parameter(Mandatory=$true)][object]$title
	)
{
	$csvFilename=$global:outputCSV -replace ".csv","-$($title -replace ' ','_').csv"
	$metaFilename=$csvFilename -replace '.csv','.nfo'
	$metaInfo = @()
	$metaInfo +="tableHeader=$title $SHOWCOMMANDS"
	#$metaInfo +="introduction="
	$metaInfo +="titleHeaderType=$type"
	#$metaInfo +="displayTableOrientation=$displayTableOrientation"
	#$metaInfo +="chartable=false"
	#$metaInfo +="showTableCaption=$showTableCaption"
	#if ($metaAnalytics) {$metaInfo += $metaAnalytics}
	#ExportCSV -table $dataTable -thisFileInstead $csvFilename 
	ExportMetaData -metadata $metaInfo -thisFileInstead $metaFilename
	updateReportIndexer -string "$(split-path -path $csvFilename -leaf)"
}

function getOSByName([Parameter(Mandatory=$true)][string] $version)
{
	switch ($version)
	{
		"5.00" {return "Windows 2000"}
		"5.02" { return "Windows 2003" }
		"6.00" { return "Windows 2008" }
		"6.01" { return "Windows 2008R2" }
		"6.02" { return "Windows 2012" }
		"6.03" { return "Windows 2012R2" }
		default { return $version }
	}
}

function formatTimeTaken([Parameter(Mandatory=$true)]$hhmmss)
{
	$hours,$minutes,$seconds=$hhmmss -split ":"
	$hours = $hours -replace "^0",""
	$minutes = $minutes -replace "^0",""
	$seconds = $seconds -replace "^0",""
	$finalString=""
	if ($hours -gt 0)
	{
		$finalString += "$($hours)hrs "
	}
	if ($minutes -gt 0)
	{
		$finalString += "$($minutes)min "
	}
	if ($seconds -gt 0)
	{
		$finalString += "$($seconds)sec"
	}
	return "$finalString"
}

function returnTableFrom2([Parameter(Mandatory=$true)]$output)
{
	$output_sanitised = ($output | ?{$_.Contains(":") -and !$_.Contains("ANS8000I") -and !$_.Contains("Server date/time") -and !$_.Contains("Session established")})
	$headers = $output_sanitised | %{
		$field,$content=$_ -split ":",2
		$field -replace "\s",""
	} | Select -Unique
	
	$numberOfSections = $output_sanitised.Count / $headers.Count
	$table = for ($num = 0; $num -lt $numberOfSections; $num++)
	{
		$startValue = $headers.Count * $num
		$endValue = $headers.Count * ($num + 1)
		$obj = @{} # Change to Hash #New-Object System.Object 
		for ($subNum = $startValue; $subNum -lt $endValue; $subNum++)
		{				
			#$headers | %{
				$field,$value=$output_sanitised[$subNum] -split ":",2
				#$field = $field  -replace "^\s","" -replace "\s$",""
				$field = $field -replace "\s",""
				#$field = $field #-replace "\s",""
				$value = $value -replace "^\s","" -replace "\s$",""
				# if $value contains at least 1 non digit, then set as TEXT otherwise format as numbers
				#if ($value -match "\D+")
				if (isNumeric -x $value)
				{
					if ("$field" -eq "CLIENT_OS_LEVEL")
					{
						if ($value)
						{
							#$obj.Add("$field","$(getOSByName -version $value)")
							$obj.Add("$field","$value")
						}
					} else {
						$obj.Add("$field",$(formatNumbers -value ([double]$value)))
					}
				} else {
					$obj.Add("$field","$value")
				}
				#Write-Host "field=$($field -replace '\s'),value=$($value -replace '\s')"
			#}
		}
		$obj
	}
	return $table
}


# Takes the input 
function returnTableFrom([Parameter(Mandatory=$true)]$output)
{
	$output_sanitised = ($output | ?{$_.Contains(":") -and !$_.Contains("ANS8000I") -and !$_.Contains("Server date/time") -and !$_.Contains("Session established")})
	$headers = $output_sanitised | %{
		$field,$content=$_ -split ":",2
		$field -replace "\s",""
	} | Select -Unique
	
	$numberOfSections = $output_sanitised.Count / $headers.Count
	$table = for ($num = 0; $num -lt $numberOfSections; $num++)
	{
		$startValue = $headers.Count * $num
		$endValue = $headers.Count * ($num + 1)
		$obj = New-Object System.Object
		for ($subNum = $startValue; $subNum -lt $endValue; $subNum++)
		{				
			#$headers | %{
				$field,$value=$output_sanitised[$subNum] -split ":",2
				#$field = $field  -replace "^\s","" -replace "\s$",""
				$field = $field -replace "\s",""
				#$field = $field #-replace "\s",""
				$value = $value -replace "^\s","" -replace "\s$",""
				# if $value contains at least 1 non digit, then set as TEXT otherwise format as numbers
				#if ($value -match "\D+")
				if (isNumeric -x $value)
				{
					if ("$field" -eq "CLIENT_OS_LEVEL")
					{
						if ($value)
						{
							$obj | Add-Member -MemberType NoteProperty -Name "$field" -Value $value # "$(getOSByName -version $value)"
						}
					} else {
						$obj | Add-Member -MemberType NoteProperty -Name "$field" -Value $(formatNumbers -value ([double]$value))
					}
				} else {
					$obj | Add-Member -MemberType NoteProperty -Name "$field" -Value $value
				}
				#Write-Host "field=$($field -replace '\s'),value=$($value -replace '\s')"
			#}
		}
		$obj
	}
	return $table
}


function queryTSM([Parameter(Mandatory=$true)]$cmd,[Parameter(Mandatory=$true)]$connection)
{	
	$fullList = & $dsmadm -id="$($connection.username)" -pa="$($connection.password)" -tcpserver="$($connection.target)" -optfile="dsm.opt" -displaymode="list" -dataonly="no" $cmd
	if ($fullList -match "Highest return code was 0")
	{
		return (returnTableFrom -output $fullList)
	} else {		
		Write-Host "`t-> Query or Connection error - No objects found"
		Write-Host $fullList
	}

}


# Get the platform version (Windows, linux etc..) and only return that
function getServerPlatform([Parameter(Mandatory=$true)]$connection)
{
	#$cmd="select platform from status"
	#return (& $dsmadm -id="$($connection.username)" -pa="$($connection.password)" -tcpserver="$($connection.target)" -optfile="dsm.opt" -tab -dataonly="yes" $cmd)
	
	$cmd="select platform from status"
	$installationType = & $dsmadm -id="$($connection.username)" -pa="$($connection.password)" -tcpserver="$($connection.target)" -optfile="dsm.opt" -tab -dataonly="yes" $cmd
	
	$cmd="select cast(version as char(1))||'.'||cast(release as char(1))||'.'||cast(level as  char(1))||'.'||trim(cast(sublevel as char(3))) from status"
	$installationVersion = & $dsmadm -id="$($connection.username)" -pa="$($connection.password)" -tcpserver="$($connection.target)" -optfile="dsm.opt" -tab -dataonly="yes" $cmd
	
	#$cmd="select date(audit_date)||' '||replace(time(audit_date),'.',':') from licenses"
	#$licenceVersion = & $dsmadm -pa="$($connection.password)" -tcpserver="$($connection.target)" -optfile="dsm.opt" -tab -dataonly="yes" $cmd
	
	$cmd="select tsmbasic_act,tsmbasic_lic,tsmee_lic,tsmee_act,compliance,date(audit_date)||' '||replace(time(audit_date),'.',':') from licenses"
	$tsmbasic_act,$tsmbasic_lic,$tsmee_lic,$tsmee_act,$compliance,$date,$time = (& $dsmadm -id="$($connection.username)" -pa="$($connection.password)" -tcpserver="$($connection.target)" -optfile="dsm.opt" -tab -dataonly="yes" $cmd) -split "\s"
	if ($tsmee_lic -eq "Yes")
	{
		$installEdition = "TSM Extended Edition"
	} elseif ($tsmbasic_lic -eq "Yes")
	{
		$installEdition = "TSM Basic Edition"
	}
	
	if ($compliance -eq "Valid")
	{
		$compliance = "Valid"
	} else {
		$compliance = "Not Valid"
	}

	## Determine TDP agent use (these will give numbers of clients using the product):
	$cmd="select mssql_act,msexch_act,sapr3_act from licenses"
	$mssqlLic,$msExchangeLic,$sapLicence = (& $dsmadm -id="$($connection.username)" -pa="$($connection.password)" -tcpserver="$($connection.target)" -optfile="dsm.opt" -tab -dataonly="yes" $cmd) -split "\s"

	$cmd="select a.node_name, platform_name, client_Os_Level, cast(client_version as char(1))||'.'||cast(client_release as char(1))||'.'||cast(client_level as  char(1))||'.'||trim(cast(Client_sublevel as char(2))), backup_mb+archive_mb from nodes a, auditocc b where a.node_name=b.node_name"
	$client_nodes= (& $dsmadm -id="$($connection.username)" -pa="$($connection.password)" -tcpserver="$($connection.target)" -optfile="dsm.opt" -comma -dataonly="yes" $cmd)
	$tbl_client_nodes = $client_nodes | %{
		$node_name,$node_platform,$client_os_level,$version,$clientConsumptionMb=$_ -split ","
		$row = "" | Select node_name,node_platform,client_os_level,version,clientConsumptionMb
		$row.node_name = $node_name
		$row.node_platform = $node_platform
		if ($client_os_level)
		{
			$row.client_os_level = getOSByName -version $client_os_level
		} else {
			$row.client_os_level = ""
		}
		$row.version = $version
		$row.clientConsumptionMb = $clientConsumptionMb
		$row
	}
	
	$totalConsumptionGB = [Math]::Round(($tbl_client_nodes | measure clientConsumptionMb -Sum).Sum / 1024,2)
	#logthis -msg "Results"
	$obj = New-Object System.Object
	#$obj | Add-Member -MemberType NoteProperty -Name "System" -Value $device
	$obj | Add-Member -MemberType NoteProperty -Name "Installation Type" -Value $installationType
	$obj | Add-Member -MemberType NoteProperty -Name "Version" -Value $installationVersion
	$obj | Add-Member -MemberType NoteProperty -Name "Edition" -Value $installEdition 
	$obj | Add-Member -MemberType NoteProperty -Name "Compliance" -Value $compliance
	$obj | Add-Member -MemberType NoteProperty -Name "Last Compliance Data/Time" -Value "$date $time"
	$obj | Add-Member -MemberType NoteProperty -Name "Clients" -Value $client_nodes.Count
	$obj | Add-Member -MemberType NoteProperty -Name "Size (GB)" -Value $totalConsumptionGB
	$obj | Add-Member -MemberType NoteProperty -Name "MS MSQL Agents" -Value $mssqlLic
	$obj | Add-Member -MemberType NoteProperty -Name "MS Exchange Agents" -Value $msExchangeLic
	$obj | Add-Member -MemberType NoteProperty -Name "SAP Agents" -Value $sapLicence
	
	return $obj
}

function getServerDatabasesFiltered ([Parameter(Mandatory=$true)]$connection)
{

	# Make sure the order and labels of reportColumHeaders reflect that requested type of information in the $cmd below
	$reportColumnHeaders=@("System","On Disk (MB)","Used DB (MB)","Free Space (MB)","Used (%)","Buffer Hit Ratio (%)","Last Backup","Last Reorg")
	$cmd="select  TOT_FILE_SYSTEM_MB,USED_DB_SPACE_MB,FREE_SPACE_MB,cast ((cast(USED_DB_SPACE_MB as decimal(8,2))/ cast(TOT_FILE_SYSTEM_MB as decimal(8,2)))*100 as decimal(8,1)),BUFF_HIT_RATIO,date(LAST_BACKUP_DATE),date(LAST_REORG) from db"
	$database = & $dsmadm -id="$($connection.username)" -pa="$($connection.password)" -tcpserver="$($connection.target)" -optfile="dsm.opt" -"$delimiterForTsmCMD" -dataonly="yes" $cmd
	$tbl_database = $database | %{
		$row = New-Object System.Object
		$index=0
		#$row | Add-Member -MemberType NoteProperty -Name $reportColumnHeaders[$index] -Value $device
		$index++
		$_ -split $delimiter | %{
			#Write-Host ">>>>$_<<<"
			$row | Add-Member -MemberType NoteProperty -Name $reportColumnHeaders[$index] -Value $_
			$index++
		}
		#Write-Host $row
		$row
	}
	
	$cmd="SELECT time('00.00.00') + avg(timestampdiff(2,(end_time-start_time))) second,avg(bytes) FROM summary WHERE activity='FULL_DBBACKUP'"
	$timeTaken,$bytesTaken=(& $dsmadm -id="$($connection.username)" -pa="$($connection.password)" -tcpserver="$($connection.target)" -optfile="dsm.opt" -"$delimiterForTsmCMD" -dataonly="yes" $cmd) -split "$delimiter"
	$tbl_database | Add-Member -MemberType NoteProperty -Name "Full Backup - Avg Time " -Value (formatTimeTaken -hhmmss $timeTaken)
	$tbl_database | Add-Member -MemberType NoteProperty -Name "Full Backup - Avg Amount (MB)" -Value (formatNumbers -value (([double]$bytesTaken)/1024/1024)) #"$([Math]::Round($bytesTaken/1024/1024,2))"
	Remove-Variable timeTaken
	Remove-Variable bytesTaken
	
	# Gives the average time taken (in HH:MM:SS) and average bytes backed up for incremental database backups:
	$cmd="SELECT time('00.00.00') + avg(timestampdiff(2,(end_time-start_time))) second,avg(bytes) FROM summary WHERE activity='INCR_DBBACKUP'"
	$timeTaken,$bytesTaken=(& $dsmadm -id="$($connection.username)" -pa="$($connection.password)" -tcpserver="$($connection.target)" -optfile="dsm.opt" -"$delimiterForTsmCMD" -dataonly="yes" $cmd) -split "$delimiter"
	$tbl_database | Add-Member -MemberType NoteProperty -Name "Incremental Backup - Avg Time" -Value (formatTimeTaken -hhmmss $timeTaken)
	$tbl_database | Add-Member -MemberType NoteProperty -Name "Incremental Backup - Avg Amount (MB)" -Value (formatNumbers -value (([double]$bytesTaken)/1024/1024))  #"$([Math]::Round($bytesTaken/1024/1024,2))"
	Remove-Variable timeTaken
	Remove-Variable bytesTaken
	
	return $tbl_database

}
# Simple arithmetic addition to see if the value is a number
function isNumeric ($x) {
    try {
        0 + $x | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Enables all scripts to use the character or word that indicates that data is missing
function printNoData()
{
	return "-"
}
# a standard way to format numbers for reporting purposes
function formatNumbers (
	[Parameter(Mandatory=$true)]$value,
	[int]$deci=0,
	[string]$unit="N", #N=Numbers,D=Digits with a strick window so D8 with value 10 would print out 00000010, C for currency, P for percentage
	[bool]$showPerUnit=$false
)
{
	#Write-Host $("{0:n2}" -f $val)
	#logThis -msg $($var.gettype().Name)
	if ($(isNumeric -x $value))
	{
		#if ($showPerUnit)
		#{
		
			#if ($value -le 1024)
			#{
			##	$unit="Bytes"
			#	return "{0:$unit$deci}" -f [double]$value
			#}elseif ($value -gt 1024 -and $value -le 10240)
			#{
			#	$unit="Bytes"
			#	return "{0:$unit$deci}" -f [double]$value
			#}
		#} else {
		return "{0:$unit$deci}" -f [double]$value
		#}
		
	} else {
		return printNoData
	}
	#return "$([math]::Round($val,2))"
}

