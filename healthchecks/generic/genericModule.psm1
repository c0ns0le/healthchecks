function showError ([Parameter(Mandatory=$true)][string] $msg, $errorColor="Red")
{
	logThis ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" -ForegroundColor $errorColor
	logThis ">> " -ForegroundColor $errorColor
	logThis ">> $msg" -ForegroundColor $errorColor
	logThis ">> " -ForegroundColor $errorColor
	logThis ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" -ForegroundColor $errorColor
}

function verboseThis ([Parameter(Mandatory=$true)][object] $msg, $errorColor="Cyan")
{
	logThis ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" -ForegroundColor $errorColor
	logThis ">> " -ForegroundColor $errorColor
	logThis ">> $msg" -ForegroundColor $errorColor
	logThis ">> " -ForegroundColor $errorColor
	logThis ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" -ForegroundColor $errorColor
}

function logThis (
	[Parameter(Mandatory=$true)][string] $msg, 
	[Parameter(Mandatory=$false)][string] $logFile,
	[Parameter(Mandatory=$false)][string] $ForegroundColor = "yellow",
	[Parameter(Mandatory=$false)][string] $BackgroundColor = "black",
	[Parameter(Mandatory=$false)][bool]$logToScreen = $false,
	[Parameter(Mandatory=$false)][bool]$NoNewline = $false,
	[Parameter(Mandatory=$false)][bool]$keepLogInMemoryAlso=$false
	)
{
	if ($global:logToScreen -or $logToScreen -and !$global:silent)
	{
		# Also verbose to screent
		if ($NoNewline)
		{
			Write-Host $msg -ForegroundColor $ForegroundColor -NoNewline;
		} else {
			Write-Host $msg -ForegroundColor $ForegroundColor;
		}
	} 
	if ($global:logTofile)
	{
		Write-Host "Also writing message to file.log"		
		if ($logFile) { $msg  | out-file -filepath $logFile -append}
		if ((Test-Path -path $global:logDir) -ne $true) {
					
			New-Item -type directory -Path $global:logDir
			$childitem = Get-Item -Path $global:logDir
			$global:logDir = $childitem.FullName
		}	
		if ($global:runtimeLogFile)
		{
			$msg  | out-file -filepath $global:runtimeLogFile -append
		} 
	}
	
	if ($global:logInMemory -or $keepLogInMemoryAlso)
	{
		$global:runtimeLogFileInMemory += $msg
	}
}

function getRuntimeLogFileContent()
{
	if ($global:runtimeLogFile) { return get-content $global:runtimeLogFile }
	if ($global:logInMemory ) { return Get-Content $global:logInMemory }
	#Get-Content $logFile
}


function printToScreen([string]$msg,[string]$ForegroundColor="Yellow")
{
	if (!$global:silent)
	{
		logThis -msg $msg -ForegroundColor $ForegroundColor
	}
}

function getmycredentialsfromFile (
	[Parameter(Mandatory=$true)][string]$User,
	[Parameter(Mandatory=$true)][string]$SecureFileLocation) 
{
	#logThis -msg $SecureFileLocation
	$password = Get-Content $SecureFileLocation | ConvertTo-SecureString 
	return (New-Object System.Management.Automation.PsCredential($user,$password))
}

function set-mycredentials ([string]$filename)
{

	#$Credential = Get-Credential -Message "Enter your credentials for this connection: "
	# old versions of powershell can't display custom messages
	$Credential = Get-Credential #-Message "Enter your credentials for this connection: "
	$credential.Password | ConvertFrom-SecureString | Set-Content $filename
}

########################################################################################
# examples
# $card = Get-HashtableAsObject @{
#	Card = {2..9 + "Jack", "Queen", "King", "Ace" | Get-Random}
#	Suit = {"Clubs", "Hearts", "Diamonds", "Spades" | Get-Random}
# }
# $card
#
# $userInfo = @{
#    LocalUsers = {Get-WmiObject "Win32_UserAccount WHERE LocalAccount='True'"}
#    LoggedOnUsers = {Get-WmiObject "Win32_LoggedOnUser" }    
# }
# $liveUserInfo = Get-HashtableAsObject $userInfo
function Get-HashtableAsObject([Hashtable]$hashtable)
{  
    #.Synopsis
    #    Turns a Hashtable into a PowerShell object
    #.Description
    #    Creates a new object from a hashtable.
    #.Example
    #    # Creates a new object with a property foo and the value bar
    #    Get-HashtableAsObject @{"Foo"="Bar"}
    #.Example
    #    # Creates a new object with a property Random and a value
    #    # that is generated each time the property is retreived
    #    Get-HashtableAsObject @{"Random" = { Get-Random }}
    #.Example
    #    # Creates a new object from a hashtable with nested hashtables
    #    Get-HashtableAsObject @{"Foo" = @{"Random" = {Get-Random}}} 
    process {       
        $outputObject = New-Object Object
        if ($hashtable -and $hashtable.Count) {
            $hashtable.GetEnumerator() | Foreach-Object {
                if ($_.Value -is [ScriptBlock]) {
                    $outputObject = $outputObject | 
                        Add-Member ScriptProperty $_.Key $_.Value -passThru
                } else {
                    if ($_.Value -is [Hashtable]) {
                        $outputObject = $outputObject | 
                            Add-Member NoteProperty $_.Key (Get-HashtableAsObject $_.Value) -passThru
                    } else {                    
                        $outputObject = $outputObject | 
                            Add-Member NoteProperty $_.Key $_.Value -passThru
                    }
                }                
            }
        }
        $outputObject
    }
}

function sendEmail
	(	[Parameter(Mandatory=$true)][string] $smtpServer,  
		[Parameter(Mandatory=$true)][string] $from, 
		[Parameter(Mandatory=$true)][string] $replyTo=$from, 
		[Parameter(Mandatory=$true)][string] $toAddress,
		[Parameter(Mandatory=$true)][string] $subject, 
		[Parameter(Mandatory=$true)][string] $body="",
		[Parameter(Mandatory=$false)][PSCredential] $credentials,
		[Parameter(Mandatory=$false)][string]$fromContactName="",
		[Parameter(Mandatory=$false)][object] $attachements # An array of filenames with their full path locations
		
	) 
{
	logThis -msg "[$attachments]" -ForegroundColor Blue
	if (!$smtpServer -or !$from -or !$replyTo -or !$toAddress -or !$subject -or !$body)
	{
		logThis -msg "Cannot Send email. Missing parameters for this function. Note that All fields must be specified" -BackgroundColor Red -ForegroundColor Yellow
		logThis -msg "smtpServer = $smtpServer"
		logThis -msg "from = $from"
		logThis -msg "replyTo = $replyTo"
		logThis -msg "toAddress = $toAddress"
		logThis -msg "subject = $subject"
		logThis -msg "body = $body"
	} else {		
		if ($attachments)
		{
			$attachments | %{
				#logThis -msg $_ -ForegroundColor Blue
				$attachment = new-object System.Net.Mail.Attachment($_,"Application/Octet")
				$msg.Attachments.Add($attachment)
			}
			logThis -msg "Sending email with attachments"
			Send-MailMessage -SmtpServer $smtpServer -Credential $Credentials -From $from -Subject $subject -To $toAddress -BodyAsHtml $body -Attachments $attachments 
		} else {
			logThis -msg "Sending email without attachments"
			Send-MailMessage -SmtpServer $smtpServer -Credential $Credentials -From $from -Subject $subject -To $toAddress -BodyAsHtml $body -DeliveryNotificationOption OnFailure
		}
		
		
	}
}

function New-ZipFile {
	#.Synopsis
	#  Create a new zip file, optionally appending to an existing zip...
	[CmdletBinding()]
	param(
		# The path of the zip to create
		[Parameter(Position=0, Mandatory=$true)]
		$ZipFilePath,
 
		# Items that we want to add to the ZipFile
		[Parameter(Position=1, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
		[Alias("PSPath","Item")]
		[string[]]$InputObject = $Pwd,
 
		# Append to an existing zip file, instead of overwriting it
		[Switch]$Append,
 
		# The compression level (defaults to Optimal):
		#   Optimal - The compression operation should be optimally compressed, even if the operation takes a longer time to complete.
		#   Fastest - The compression operation should complete as quickly as possible, even if the resulting file is not optimally compressed.
		#   NoCompression - No compression should be performed on the file.
		[System.IO.Compression.CompressionLevel]$Compression = "Optimal"
	)
	begin {
		# Make sure the folder already exists
		Add-Type -As System.IO.Compression.FileSystem
		[string]$File = Split-Path $ZipFilePath -Leaf
		[string]$Folder = $(if($Folder = Split-Path $ZipFilePath) { Resolve-Path $Folder } else { $Pwd })
		$ZipFilePath = Join-Path $Folder $File
		# If they don't want to append, make sure the zip file doesn't already exist.
		if(!$Append) {
			if(Test-Path $ZipFilePath) { Remove-Item $ZipFilePath }
		}
		$Archive = [System.IO.Compression.ZipFile]::Open( $ZipFilePath, "Update" )
	}
	process {
		foreach($path in $InputObject) {
			foreach($item in Resolve-Path $path) {
				# Push-Location so we can use Resolve-Path -Relative
				Push-Location (Split-Path $item)
				# This will get the file, or all the files in the folder (recursively)
				foreach($file in Get-ChildItem $item -Recurse -File -Force | % FullName) {
					# Calculate the relative file path
					$relative = (Resolve-Path $file -Relative).TrimStart(".\")
					# Add the file to the zip
					$null = [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($Archive, $file, $relative, $Compression)
				}
				Pop-Location
			}
		}
	}
	end {
		$Archive.Dispose()
		Get-Item $ZipFilePath
	}
}
     
     
function Expand-ZipFile {
	#.Synopsis
	#  Expand a zip file, ensuring it's contents go to a single folder ...
	[CmdletBinding()]
	param(
		# The path of the zip file that needs to be extracted
		[Parameter(ValueFromPipelineByPropertyName=$true, Position=0, Mandatory=$true)]
		[Alias("PSPath")]
		$FilePath,
 
		# The path where we want the output folder to end up
		[Parameter(Position=1)]
		$OutputPath = $Pwd,
 
		# Make sure the resulting folder is always named the same as the archive
		[Switch]$Force
	)
	process {
		Add-Type -As System.IO.Compression.FileSystem
		$ZipFile = Get-Item $FilePath
		$Archive = [System.IO.Compression.ZipFile]::Open( $ZipFile, "Read" )
 
		# Figure out where we'd prefer to end up
		if(Test-Path $OutputPath) {
			# If they pass a path that exists, we want to create a new folder
			$Destination = Join-Path $OutputPath $ZipFile.BaseName
		} else {
			# Otherwise, since they passed a folder, they must want us to use it
			$Destination = $OutputPath
		}
 
		# The root folder of the first entry ...
		$ArchiveRoot = ($Archive.Entries[0].FullName -Split "/|\\")[0]
 
		Write-Verbose "Desired Destination: $Destination"
		Write-Verbose "Archive Root: $ArchiveRoot"
 
		# If any of the files are not in the same root folder ...
		if($Archive.Entries.FullName | Where-Object { @($_ -Split "/|\\")[0] -ne $ArchiveRoot }) {
			# extract it into a new folder:
			New-Item $Destination -Type Directory -Force
			[System.IO.Compression.ZipFileExtensions]::ExtractToDirectory( $Archive, $Destination )
		} else {
			# otherwise, extract it to the OutputPath
			[System.IO.Compression.ZipFileExtensions]::ExtractToDirectory( $Archive, $OutputPath )
 
			# If there was only a single file in the archive, then we'll just output that file...
			if($Archive.Entries.Count -eq 1) {
				# Except, if they asked for an OutputPath with an extension on it, we'll rename the file to that ...
				if([System.IO.Path]::GetExtension($Destination)) {
					Move-Item (Join-Path $OutputPath $Archive.Entries[0].FullName) $Destination
				} else {
					Get-Item (Join-Path $OutputPath $Archive.Entries[0].FullName)
				}
			} elseif($Force) {
				# Otherwise let's make sure that we move it to where we expect it to go, in case the zip's been renamed
				if($ArchiveRoot -ne $ZipFile.BaseName) {
					Move-Item (join-path $OutputPath $ArchiveRoot) $Destination
					Get-Item $Destination
				}
			} else {
				Get-Item (Join-Path $OutputPath $ArchiveRoot)
			}
		}
 
		$Archive.Dispose()
	}
}

# Add the aliases ZIP and UNZIP
#new-alias zip new-zipfile
#new-alias unzip expand-zipfile
