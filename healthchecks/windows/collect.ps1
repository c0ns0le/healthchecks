# Collect Active Directory Summary
.\SCRIPT_ADAssetReport.ps1 -ReportFormat HTML -ReportType ForestAndDomain -ExportGraphvizDefinitionFiles -SaveData -Verbose -ExportPrivilegedUsers -ExportAllUsers

# Collect Exchange 2007 Capacity Summary
.\exchange2007-capacityreporter.ps1