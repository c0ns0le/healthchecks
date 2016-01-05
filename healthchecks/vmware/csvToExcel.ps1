# This scripts reads in *.csv files in the script execution directory, creates a new EXCEL instance + File
# imports the CSV into individual TAB, saves the script in the current directory
# Syntax: csvToExcel.ps1
# Version : 0.2
# Author : 27/06/2010, by teiva.rodiere-at-gmail.com
# 
param([object]$if=$pwd.path,[string]$of=$pwd.path)
Write-Host "Executing script $($MyInvocation.MyCommand.path)" -ForegroundColor  green;
Write-Host "Current path is $($pwd.path)" -ForegroundColor  yellow;


$files = (Get-Item "$if\*.csv" | sort-object -property Name)

$fileCount = $files.Count;
Write-Host "Number of CSV files found in folder $if (count = $fileCount)" -ForegroundColor  green;
if ($fileCount -le 0)
{
	Write-Host "No input files (*.CSV) found in folder $if (count = $fileCount)" -ForegroundColor  green;
	exit;
}

$excelApp = New-Object -com Excel.Application
#$excelApp.Visible = $True
$excelApp.DisplayAlerts = $false
$excelApp.Visible = $true
$book = $excelApp.Workbooks.Add()
#Remove other worksheets
$book.worksheets.Item(2).delete()
#After the first worksheet is removed,the next one takes its place
$book.worksheets.Item(2).delete()   

$fileNum=2
while ($fileNum -lt $files.Count)
{
	$book.Worksheets.Add()
	$fileNum++;
}

$fileNum = 1
foreach ($file in $files) {	
	Write-Host "Processing input file $file" -ForegroundColor  yellow;
	$name,$extension = $file.Name.Split("-")
	$sheetName = $name.replace("document","").Replace("compliance","").Replace(".csv","")
	
	if ($fileNum -gt $book.Worksheets.Count) {
		#Write-Host "$fileNum ###################################### "-BackgroundColor Cyan -ForegroundColor $global:colours.Error
		$book.Worksheets.Add()
	}

	Write-Host "Verifying if Sheet $name already exists " -BackgroundColor Cyan -ForegroundColor $global:colours.Error
	$fileNameIndexer=2;
	$tempSheetName = $sheetName
	while ($book.Worksheets | where{$_.Name -eq $tempSheetName })
	{
		$tempSheetName = $sheetName +""+ $fileNameIndexer
		$fileNameIndexer++
		Write-Host "Trying new Name: $tempSheetName " -ForegroundColor $global:colours.Information
	}
	$currSheet = $book.Worksheets.Item($fileNum)
	Write-Host "Naming Sheet ""$sheetName""" -BackgroundColor Cyan -ForegroundColor $global:colours.Error
	$currSheet.Name = $tempSheetName;
	Write-Host "Activating Sheet $($currenSheet.Name)"-BackgroundColor Cyan -ForegroundColor $global:colours.Error
	Write-Host $currenSheet.Name -BackgroundColor Cyan -ForegroundColor $global:colours.Error
	$currSheet.Activate()
	

	
	#temporary open CSV file in a new separate work book to copy it and paste it into our target XLS file
	$tempBook = $excelApp.Workbooks.Open($file);
	$tempsheet = $tempBook.Worksheets.Item(1);
	#Copy contents of the CSV file
    $tempSheet.UsedRange.Copy() | Out-Null
    #Paste contents of CSV into existing workbook
    $currSheet.Paste()
	$tempBook.Close($false)
		

	$table = $currSheet.UsedRange;
	$table.Name = $currSheet.Name;
	$table.AutoFormat();
	$table.Style.ShrinkToFit = $true;
	$table.Columns.AutoFilter();
	$table.Columns.AutoFit();
	$table.Style.Interior.Color = 16777215;
	$table.Style.Interior.Pattern = 0;
	$table.Style.Interior.ThemeColor = -4142
	$fileNum++;
}

$book.SaveAs("$of\csvToExcel-" + $($(get-date).tostring('yyyyMMdd')) +".xlsx")
#$book.SaveAs("$csvToExcel.xlsx")
Start-Sleep 5
$book.Close()
$excelApp.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excelApp)
Remove-Variable excelApp
