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
	[Parameter(Mandatory=$false)][bool]$logToScreen = $true,
	[Parameter(Mandatory=$false)][bool]$NoNewline = $false
	)
{
	if ($logToScreen -and !$global:silent)
	{
		# Also verbose to screent
		if ($NoNewline)
		{
			Write-Host $msg -ForegroundColor $ForegroundColor -NoNewline;
		} else {
			Write-Host $msg -ForegroundColor $ForegroundColor;
		}
	} 
	if ($logFile)
	{
		$msg  | out-file -filepath $logFile -append
	} else 
	{
		if (!(Test-Path -path $global:logDir)) {
					
			New-Item -type directory -Path $global:logDir
			$childitem = Get-Item -Path $global:logDir
			$global:logDir = $childitem.FullName
		}
		if ($global:runtimeLogFile)
		{
			$msg  | out-file -filepath $global:runtimeLogFile -append
		} 
	}
}

function printToScreen([string]$msg,[string]$ForegroundColor="Yellow")
{
	if (!$global:silent)
	{
		Write-Host $msg -ForegroundColor $ForegroundColor
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

	$Credential = Get-Credential -Message "Enter your credentials for this connection: "
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
	Write-Host "[$attachments]" -ForegroundColor Blue
	if (!$smtpServer -or !$from -or !$replyTo -or !$toAddress -or !$subject -or !$body)
	{
		Write-Host "Cannot Send email. Missing parameters for this function. Note that All fields must be specified" -BackgroundColor Red -ForegroundColor Yellow
		Write-Host "smtpServer = $smtpServer"
		Write-Host "from = $from"
		Write-Host "replyTo = $replyTo"
		Write-Host "toAddress = $toAddress"
		Write-Host "subject = $subject"
		Write-Host "body = $body"
	} else {		
		if ($attachments)
		{
			$attachments | %{
				#Write-Host $_ -ForegroundColor Blue
				$attachment = new-object System.Net.Mail.Attachment($_,"Application/Octet")
				$msg.Attachments.Add($attachment)
			}
			Write-Host "Sending email with attachments"
			Send-MailMessage -SmtpServer $smtpServer -Credential $Credentials -From $from -Subject $subject -To $toAddress -BodyAsHtml $body -Attachments $attachments 
		} else {
			Write-Host "Sending email without attachments"
			Send-MailMessage -SmtpServer $smtpServer -Credential $Credentials -From $from -Subject $subject -To $toAddress -BodyAsHtml $body -DeliveryNotificationOption OnFailure
		}
		
		
	}
}
