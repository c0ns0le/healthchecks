$strComputer = “.”

$Excel = New-Object -Com Excel.Application
$Excel.visible = $True
$Excel = $Excel.Workbooks.Add()

$Sheet = $Excel.WorkSheets.Item(1)
$Sheet.Cells.Item(1,1) = “Computer”
$Sheet.Cells.Item(1,2) = “Drive Letter”
$Sheet.Cells.Item(1,3) = “Description”
$Sheet.Cells.Item(1,4) = “FileSystem”
$Sheet.Cells.Item(1,5) = “Size in GB”
$Sheet.Cells.Item(1,6) = “Free Space in GB”

$WorkBook = $Sheet.UsedRange
$WorkBook.Interior.ColorIndex = 8
$WorkBook.Font.ColorIndex = 11
$WorkBook.Font.Bold = $True

$intRow = 2
$Sheet.Cells.Item($intRow,1) = "Teiva"

$WorkBook.EntireColumn.AutoFit()
#Clear