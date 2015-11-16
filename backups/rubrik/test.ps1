# TEST
cd "D:\Personal\scripts\healthchecks\test\backups\rubrik\test_scripts\"
$SecureFileLocation="D:\Personal\scripts\healthchecks\test\backups\rubrik\test_scripts\rubrik01.test.ait.local-password.txt"
$username="admin"
$server="rubrik01.test.ait.local"
.\rubrik-documentor.ps1 -Server $server -Username $username  -SecureFileLocation $SecureFileLocation
#
