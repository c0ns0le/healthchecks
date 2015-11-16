#
# This file contains a collection of parame
#
Param([Parameter(Mandatory=$true)][string]$User,
	  [Parameter(Mandatory=$true)][string]$SecureFileLocation) 
$password = Get-Content $SecureFileLocation | ConvertTo-SecureString 
$credential = New-Object System.Management.Automation.PsCredential($user,$password)
if ($credential)
{
	return $credential
} else {
	
}
