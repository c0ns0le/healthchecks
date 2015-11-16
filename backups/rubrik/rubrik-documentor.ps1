#https://rubrik01.test.ait.local/swagger-ui/
param ( 
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

Import-Module -Force -Name ".\rubrik-Module.psm1"

$session = connect -Server $server -Username $username -SecureFileLocation $SecureFileLocation

$get_requests= @('host','vcenter','datacenter','oracledb','clusterIps','compute_cluster','slaDomain','mount','system/version','vm','vm/list','virtual/disk','system/ntp/servers','support/tunnel') #,'internal/job/type/backup','internal/config/crystal','report/vm')
$report = @{}
$get_requests | %{
	$request=$_
	Write-Host "Processing $request"
	#$fieldname = $request -split '/' | select -Last 1
	$fieldname = $request -replace '/','_' #| select -Last 1
	try {	
		$response = Invoke-WebRequest -Uri "$($session.ConnectionUri)/$request" -Headers $session.Headers -Method Get
		$jsonResponse = ConvertFrom-Json -InputObject $response.Content
		$report[$fieldname] = $jsonResponse
	} catch 
	{
		throw "Error gathering ""$request"" from $($session.Servername)"
	}
}

return $report

