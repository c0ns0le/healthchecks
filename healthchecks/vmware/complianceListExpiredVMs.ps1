# This scripts looks for entries in the "Expiry Date" custom attribute of a Virtual machine
# version: 0.1
# Author: teiva.rodiere-at-gmail.com
# Date: 30 Sept 2009


Get-VM * | Sort-Object Name | Get-View | %{
	if ($_.AvailableField) {
		foreach ($field in $_.AvailableField) {
			$custField = $_.CustomValue | ?{$_.Key -eq $field.Key}
			$GuestConfig | Add-Member -Type NoteProperty -Name $field.Name -Value $custField.Value
		}
	}
}