$outputFile="D:\Personal\scripts\healthchecks\test\output\ffox.html"
$outputFile2="D:\Personal\scripts\healthchecks\test\output\ffox2.html"
Import-Module -Name "D:\Personal\scripts\healthchecks\test\vmware\VisualizeInHtml.psm1"
New-ViChart -outputFile $outputFile  `
 -input (`
	New-ViChartInfo `
		-data `
		   ((1..20|%{[DateTime]::Now.AddHours($_*6)}),
		   (1..20|%{[DateTime]::Now.AddMinutes($_)}),
		    (1..20|%{[DateTime]::Now.AddHours($_*6).AddMinutes($_*(Get-Random -min 0 -max 3))}))`
		-lines 'Hours','Minutes','Hours+Minutes'),
	
	(New-ViChartInfo `
		-data `
		   (1..10|%{[DateTime]::Now.AddMinutes($_*(Get-Random -min 0 -max 8))})`
		-lines 'Minute','Hour',@{'n'='min+hour';'e'={$_.Minute+$_.Hour}})


$ff = 1..10|%{start-sleep -sec 3; get-process firefox}
New-ViChart -outputFile $outputFile2 -input (New-ViChartInfo -data $ff -lines ('WorkingSet','PagedMemorySize','PrivateMemorySize'))#, 
	#(New-ViChartInfo -data $ff -lines '"TotalProcessorTime"."TotalMilliseconds"',@{'n'='uproc';'e'={$_.UserProcessorTime.TotalMilliseconds}}  )