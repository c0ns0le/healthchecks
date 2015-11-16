param([string]$mode="readonly");

$currStr="MINCOM-PROD"; 
$newStr="MINCOM_01";

Get-Datastore "*$currStr*" | %{
	$replaceStr=($_.Name).Replace($currStr,$newStr); 
	Write-Host "Renaming "$_.Name "with "$replaceStr".." -Foregroundcolor Cyan
	if ($mode -eq "execute") {
		Set-Datastore $_ -Name $replaceStr -Confirm:$false
	} elseif ($mode -eq "readonly") {
		Write-Host "READONLY MODE"  -Foregroundcolor Blue
	}
}