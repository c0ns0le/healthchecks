
$srvconnection = get-vc -server bnevcm01, aubne-s-dvcenter

#Send list of assets for RnD to Individual Users AND the Manager Report to Vasu
#sendListOfVMsToContacts-shortlist.ps1 -srvConnection $srvconnection -includeIndividualReports $true -includeManagersReport $true -emailReport $true

#Send list of assets for RnD the Manager Report only to Vasu
#sendListOfVMsToContacts-shortlist.ps1 -srvConnection $srvconnection -includeIndividualReports $false -includeManagersReport $true -emailReport $true


# Export to asset list and Individual Reports AND the Manager report, but HTML only -- no emails
#sendListOfVMsToContacts-shortlist.ps1 -srvConnection $srvconnection -includeIndividualReports $true -includeManagersReport $true -emailReport $false -verboseHTMLFilesToFile $true

# only send manager report
$srvconnection = get-vc -server bnevcm01, aubne-s-dvcenter
./sendListOfVMsToContacts-shortlist.ps1 -srvConnection $srvconnection -includeIndividualReports $false -includeManagersReport $true -emailReport $true -verboseHTMLFilesToFile $false
