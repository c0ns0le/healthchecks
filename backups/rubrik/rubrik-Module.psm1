#rubrik-Module.psm1
#
# https://192.168.11.61/swagger-ui/

function connect ( 
	[Parameter(Mandatory = $true,Position = 0,HelpMessage = 'Rubrik FQDN or IP address')]
     [ValidateNotNullorEmpty()]
     [String]$server,
	[Parameter(Mandatory = $false,Position = 0,HelpMessage = 'Rubrik username')]
     [ValidateNotNullorEmpty()]
     [String]$username="admin",
	[Parameter(Mandatory = $true,Position = 0,HelpMessage = 'File that contains the encrypted password for the username to be used in this connection')]
     [ValidateNotNullorEmpty()]
     [String]$SecureFileLocation

)
{
	#Import-Module -Force -Name "Rubrik.psd1"
	# Allow untrusted SSL certs
     Add-Type -TypeDefinition @"
	    using System.Net;
	    using System.Security.Cryptography.X509Certificates;
	    public class TrustAllCertsPolicy : ICertificatePolicy {
	        public bool CheckValidationResult(
	            ServicePoint srvPoint, X509Certificate certificate,
	            WebRequest request, int certificateProblem) {
	            return true;
	        }
	    }
"@
     [System.Net.ServicePointManager]::CertificatePolicy = New-Object -TypeName TrustAllCertsPolicy
	# Create secure credentials to use in the remaining script.
	
	
	if ($SecureFileLocation)
	{	 
		$password = Get-Content $SecureFileLocation | ConvertTo-SecureString 
		$credential = New-Object System.Management.Automation.PsCredential($username,$password)

	}
	if (-not $credential)
	{
		$credential = Get-Credential -UserName $username -Message "Enter the password to use for this connection"
		#$password = $credentialObject.Password | ConvertFrom-SecureString 
	}

	
	
	try 
	{				
		$rubrik = Connect-Rubrik -Server $server -Username $username -Password $credential.Password
		return $rubrik
	}
	catch 
	{
		throw "Error connecting to Rubrik server ""$server"""
		return $null
	}
}


#Requires -Version 3
function Connect-Rubrik 
{
    <#  
            .SYNOPSIS
            Connects to Rubrik and retrieves a token value for authentication
            .DESCRIPTION
            The Connect-Rubrik function is used to connect to the Rubrik RESTful API and supply credentials to the /login method. Rubrik then returns a unique token to represent the user's credentials for subsequent calls. Acquire a token before running other Rubrik cmdlets.
            .NOTES
            Written by Chris Wahl for community usage
            Twitter: @ChrisWahl
            GitHub: chriswahl
            .LINK
            https://github.com/rubrikinc/PowerShell-Module
            .EXAMPLE
            Connect-Rubrik -Server 192.168.1.1 -Username admin
            This will connect to Rubrik with a username of "admin" to the IP address 192.168.1.1. The prompt will request a secure password.
            .EXAMPLE
            Connect-Rubrik -Server 192.168.1.1 -Username admin -Password (ConvertTo-SecureString "secret" -asplaintext -force)
            If you need to pass the password value in the cmdlet directly, use the ConvertTo-SecureString function.
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true,Position = 0,HelpMessage = 'Rubrik FQDN or IP address')]
        [ValidateNotNullorEmpty()]
        [String]$Server,
        [Parameter(Mandatory = $true,Position = 1,HelpMessage = 'Rubrik username')]
        [ValidateNotNullorEmpty()]
        [String]$Username,
        [Parameter(Mandatory = $true,Position = 2,HelpMessage = 'Rubrik password')]
        [ValidateNotNullorEmpty()]
        [SecureString]$Password,
	   [Parameter(Mandatory = $false,Position = 2,HelpMessage = 'Set this to false if you want to simply return the connection settings instead setting a global variable')]
        [ValidateNotNullorEmpty()]
	   $setglobalVar=$true,
	   [Parameter(Mandatory = $false,Position = 2,HelpMessage = 'Verbose the connection to troubleshoot')]
        [ValidateNotNullorEmpty()]
	   $verboseInfo=$false

    )

    Process {

        # Allow untrusted SSL certs
        Add-Type -TypeDefinition @"
	    using System.Net;
	    using System.Security.Cryptography.X509Certificates;
	    public class TrustAllCertsPolicy : ICertificatePolicy {
	        public bool CheckValidationResult(
	            ServicePoint srvPoint, X509Certificate certificate,
	            WebRequest request, int certificateProblem) {
	            return true;
	        }
	    }
"@
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object -TypeName TrustAllCertsPolicy

        # Build the URI
        $uri = 'https://'+$server+':443/login'

        # Build the login call JSON
        $credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $Username, $Password        
        $body = @{
            userId   = $username
            password = $credentials.GetNetworkCredential().Password
        }

        # Submit the token request
        try 
        {
            $r = Invoke-WebRequest -Uri $uri -Method: Post -Body (ConvertTo-Json -InputObject $body)
        }
        catch 
        {
            throw 'Error connecting to Rubrik server'
        }
        $RubrikServer = $server
        $RubrikToken = (ConvertFrom-Json -InputObject $r.Content).token
        if($verboseInfo) { Write-Host -Object "Acquired token: $RubrikToken`r`nYou are now connected to the Rubrik API." }

        # Validate token and build Base64 Auth string
        $auth = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($RubrikToken+':'))
        if ($setglobalVar)
	   {
	   	$global:RubrikServer = $server
	   	$global:RubrikToken = $RubrikToken
	   	$global:RubrikHead = @{
          	  'Authorization' = "Basic $auth"
        	}
	   }

	  return @{
	  	'Servername' = $server
		'Token' = (ConvertFrom-Json -InputObject $r.Content).token
		'Headers' = @{
			'Authorization' = "Basic $auth"
		}
		'ConnectionUri' = "https://$($server):443"
	  }
		

    } # End of process
} # End of function