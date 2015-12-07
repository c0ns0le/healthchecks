# Website to assist
# http://bytecookie.wordpress.com/2012/04/13/tutorial-powershell-and-microsoft-chart-controls-or-how-to-spice-up-your-reports/
# https://onedrive.live.com/?cid=7e14a0e81de18909&id=7E14A0E81DE18909!126&Bsrc=Photomail&Bpub=SDX.Photos&sff=1&authkey=!AF3EHmx8l1TDj0I#cid=7E14A0E81DE18909&id=7E14A0E81DE18909!126&authkey=!AF3EHmx8l1TDj0I
# generate-chartImageFile.ps1 -table
# This script inputs an array and creates an image chart from it
param ( [array]$datasource,
		[string]$outputImageName,
		[string]$chartType="line",
		[int]$xAxisIndex=0,
		[int]$yAxisIndex=1,
		[int]$xAxisInterval=1,
		[string]$xAxisTitle,
		[int]$yAxisInterval=50,
		[string]$yAxisTitle="Count",
		[int]$startChartingFromColumnIndex=1, # 0 = All columns, 1 = starting from 2nd column, because you want to use Colum 0 for xAxis
		[string]$title="EnterTitle",
		[int]$width=800,
		[int]$height=800,
		[string]$BackColor="White",
		[string]$fileType="png"
	  )


[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")
$chartColorChoices=@("#E3B64C,#0000CC","#00CC00","#FF0000","#2F4F4F","#006400","#9900CC","#FF0099","#62B5FC","#228B22","#000080","#00F080")
#chartTypes are: Line, Column, StackedColumn, StackedBar
$scriptpath = Split-Path -parent $outputImageName
$headers = $datasource | Get-Member -membertype NoteProperty | select -Property Name
#LogThis -msg "+++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor Yellow
#LogThis -msg "Output image: $outputImageName" -ForegroundColor Yellow

#LogThis -msg "Table to chart:" -ForegroundColor Yellow
#LogThis -msg "" -ForegroundColor Yellow
#LogThis -msg $datasource  -ForegroundColor Yellow
#LogThis -msg "+++++++++++++++++++++++++++++++++++++++++++ " -ForegroundColor Yellow
# chart object
$chart1 = New-object System.Windows.Forms.DataVisualization.Charting.Chart
$chart1.Width = $width
$chart1.Height = $height
$chart1.BackColor = [System.Drawing.Color]::$BackColor

# title 
[void]$chart1.Titles.Add($title)
$chart1.Titles[0].Font = "Arial,13pt"
$chart1.Titles[0].Alignment = "topLeft"

# chart area 
$chartarea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
$chartarea.Name = "ChartArea1"
$chartarea.AxisY.Title = $yAxisTitle #$headers[$yAxisIndex]
$chartarea.AxisY.Interval = $yAxisInterval
$chartarea.AxisX.Interval = $xAxisInterval
if ($xAxisTitle) {
	$chartarea.AxisX.Title = $xAxisTitle
} else {
	$chartarea.AxisX.Title = $headers[$xAxisIndex].Name
}
$chart1.ChartAreas.Add($chartarea)


# legend 
$legend = New-Object system.Windows.Forms.DataVisualization.Charting.Legend
$legend.name = "Legend1"
$chart1.Legends.Add($legend)

# chart data series
$index=0
#$index=$startChartingFromColumnIndex
#$yAxisHeaderName=$headers[$xAxisIndex]
$headers | %{
	$header = $_.Name
	if ($index -ge $startChartingFromColumnIndex)# -and $index -lt $headers.Count)
    {
		#LogThis -msg "Creating new series: $($header)"
		[void]$chart1.Series.Add($header)
		$chart1.Series[$header].ChartType = $chartType #Line,Column,Pie
		$chart1.Series[$header].BorderWidth  = 3
		$chart1.Series[$header].IsVisibleInLegend = $true
		$chart1.Series[$header].chartarea = "ChartArea1"
		$chart1.Series[$header].Legend = "Legend1"
		#LogThis -msg "Colour choice is $($chartColorChoices[$index])"
		$chart1.Series[$header].color = "$($chartColorChoices[$index])"
	#   $datasource | ForEach-Object {$chart1.Series["VMCount"].Points.addxy( $_.date , ($_.VMCountorySize / 1000000)) }
		$datasource | %{
			$chart1.Series[$header].Points.addxy( $_.$($headers[$xAxisIndex].Name), $_.$header )
		}
	}
	$index++;
}

# save chart
$chart1.SaveImage($outputImageName,$fileType)

