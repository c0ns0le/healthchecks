#genericModule.psm1

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
	logThis ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" -ForegroundColor $errorColor
}

#Log To Screen and file
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
		if ((Test-Path -path $global:logDir) -ne $true) {
					
			New-Item -type directory -Path $global:logDir
			$childitem = Get-Item -Path $global:logDir
			$global:logDir = $childitem.FullName
		}
		if ($global:logFile)
		{
			$msg  | out-file -filepath $global:logFile -append
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

function get-mycredentials-fromFile (
	[Parameter(Mandatory=$true)][string]$User,
	[Parameter(Mandatory=$true)][string]$SecureFileLocation
) 
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