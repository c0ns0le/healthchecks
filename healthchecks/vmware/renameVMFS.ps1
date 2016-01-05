param([string]$mode="readonly");

$currStr="Customer-PROD"; 
$newStr="Customer_01";

Get-Datastore "*$currStr*" | %{
	$replaceStr=($_.Name).Replace($currStr,$newStr); 
	Write-Host "Renaming "$_.Name "with "$replaceStr".." -ForegroundColor $global:colours.Information
	if ($mode -eq "execute") {
		Set-Datastore $_ -Name $replaceStr -Confirm:$false
	} elseif ($mode -eq "readonly") {
		Write-Host "READONLY MODE"  -ForegroundColor $global:colours.ChangeMade
	}
}