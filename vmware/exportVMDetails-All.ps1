# This script
$srvConnection = get-vc "vcentername"
$writeDetailsTo=".\output\$((get-date).Day)-$((get-date).Month)-$((get-date).Year)"
Get-VM *| %{
	&.\exportVMDetails.ps1 -guestName $_.Name -srvConnection $srvconnection -verbose $true -includeSectionSysInfo $true -includeSectionPerfStats $true -logDir $outputDirectory
}