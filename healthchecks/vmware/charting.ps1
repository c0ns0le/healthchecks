[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")

$scriptpath = Split-Path -parent $MyInvocation.MyCommand.Definition

# chart object
   $chart1 = New-object System.Windows.Forms.DataVisualization.Charting.Chart
   $chart1.Width = 600
   $chart1.Height = 600
   $chart1.BackColor = [System.Drawing.Color]::White

 

# title 
   [void]$chart1.Titles.Add("Virtual Machines")
   $chart1.Titles[0].Font = "Arial,13pt"
   $chart1.Titles[0].Alignment = "topLeft"

 

# chart area 
   $chartarea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
   $chartarea.Name = "ChartArea1"
   $chartarea.AxisY.Title = "Count"
   $chartarea.AxisX.Title = "Date"
   $chartarea.AxisY.Interval = 5
   $chartarea.AxisX.Interval = 5
   $chart1.ChartAreas.Add($chartarea)
 

# legend 
   $legend = New-Object system.Windows.Forms.DataVisualization.Charting.Legend
   $legend.name = "Legend1"
   $chart1.Legends.Add($legend)

 

# data source
#   $datasource = Get-Process | sort DiskUsageorySize -Descending  | Select-Object -First 5
$datasource = Import-CSV ".\output\capacity-input.csv"
 

# data series
   [void]$chart1.Series.Add("VMCount")
#   $chart1.Series["VMCount"].ChartType = "Column"
   $chart1.Series["VMCount"].ChartType = "Line"
   $chart1.Series["VMCount"].BorderWidth  = 3
   $chart1.Series["VMCount"].IsVisibleInLegend = $true
   $chart1.Series["VMCount"].chartarea = "ChartArea1"
   $chart1.Series["VMCount"].Legend = "Legend1"
   $chart1.Series["VMCount"].color = "#62B5CC"
#   $datasource | ForEach-Object {$chart1.Series["VMCount"].Points.addxy( $_.date , ($_.VMCountorySize / 1000000)) }
   $datasource | ForEach-Object {$chart1.Series["VMCount"].Points.addxy( $_.date , $_.VMCount) }

 

# data series
#   [void]$chart1.Series.Add("DiskUsage")
#   $chart1.Series["DiskUsage"].ChartType = "Column"
#   $chart1.Series["DiskUsage"].ChartType = "Line"
#   $chart1.Series["DiskUsage"].IsVisibleInLegend = $true
#   $chart1.Series["DiskUsage"].BorderWidth  = 3
#   $chart1.Series["DiskUsage"].chartarea = "ChartArea1"
#   $chart1.Series["DiskUsage"].Legend = "Legend1"
#   $chart1.Series["DiskUsage"].color = "#E3B64C"
#   $datasource | ForEach-Object {$chart1.Series["DiskUsage"].Points.addxy( $_.date , $_.DiskUsage) }

 

# save chart
   $chart1.SaveImage(".\output\SplineArea.png","png")
