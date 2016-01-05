<#
.SYNOPSIS
Merges an arbitrary amount of CSV files based on an ID column or several combined ID columns.

Author: Joakim Svendsen,
Svendsen Tech (C) 2014,
All rights reserved.

.EXAMPLE
ipcsv users.csv | ft -AutoSize

Username Department
-------- ----------
John     IT        
Jane     HR        

PS C:\> ipcsv user-mail.csv | ft -AutoSize

Username Email           
-------- -----           
John     john@example.com
Jane     jane@example.com

PS C:\> Merge-Csv -Path users.csv, user-mail.csv -Shared Username | Export-Csv -enc UTF8 merged.csv

PS C:\> ipcsv .\merged.csv | ft -AutoSize

Username Department Email           
-------- ---------- -----           
John     IT         john@example.com
Jane     HR         jane@example.com

.EXAMPLE
Merge-Csv -In (ipcsv .\csv1.csv), (ipcsv csv2.csv), (ipcsv csv3.csv) -SharedColumn Username | sort username | ft -AutoSize

Merging three files.

WARNING: Duplicate identifying (shared column(s) ID) entry found in CSV data/file 0: user42
WARNING: Identifying column entry 'firstOnly' was not found in all CSV data objects/files. Found in object/file no.: 1
WARNING: Identifying column entry '2only' was not found in all CSV data objects/files. Found in object/file no.: 2
WARNING: Identifying column entry 'user2and3only' was not found in all CSV data objects/files. Found in object/file no.: 2, 3

Username      File1A      File1B      TestID File2A  File2B  TestX      File3  
--------      ------      ------      ------ ------  ------  -----      -----  
2only                                        a       b       c                 
firstOnly     firstOnlyA1 firstOnlyB1 foo                                      
user1         1A1         1B1         same   1A3     2A3     same       same   
user2         2A1         2B1         diff2  2A3     2B3     diff2_2    testC2 
user2and3only                                2and3A2 2and3B2 test2and3X testID 
user3         3A1         3B1         same   3A3     3B3     same       same   
user42        42A1        42B1        same42 testA42 testB42 testX42    testC42

.EXAMPLE
Merge-Csv -Path csvmerge1.csv, csvmerge2.csv, csvmerge3.csv -SharedColumn Username, TestID | sort username | ft -a

Two shared/ID column, three filess.
	
WARNING: Duplicate identifying (shared column(s) ID) entry found in CSV data/file 1: user42, same42
WARNING: Identifying column entry 'user2, diff2' was not found in all CSV data objects/files. Found in object/file no.: 1
WARNING: Identifying column entry 'user2and3only, testID' was not found in all CSV data objects/files. Found in object/file no.: 3
WARNING: Identifying column entry 'user2, testC2' was not found in all CSV data objects/files. Found in object/file no.: 3
WARNING: Identifying column entry '2only, c' was not found in all CSV data objects/files. Found in object/file no.: 2
WARNING: Identifying column entry 'user2and3only, test2and3X' was not found in all CSV data objects/files. Found in object/file no.: 2
WARNING: Identifying column entry 'user2, diff2_2' was not found in all CSV data objects/files. Found in object/file no.: 2
WARNING: Identifying column entry 'firstOnly, foo' was not found in all CSV data objects/files. Found in object/file no.: 1

Username      TestID     File1A      File1B      File2A  File2B 
--------      ------     ------      ------      ------  ------ 
2only         c                                  a       b      
firstOnly     foo        firstOnlyA1 firstOnlyB1                
user1         same       1A1         1B1         1A3     2A3    
user2         diff2      2A1         2B1                        
user2         diff2_2                            2A3     2B3    
user2         testC2                                            
user2and3only testID                                            
user2and3only test2and3X                         2and3A2 2and3B2
user3         same       3A1         3B1         3A3     3B3    
user42        same42     42A1        42B1        testA42 testB42

#>
#function Merge-Csv {
    #[CmdletBinding(
        #DefaultParameterSetName='Files'
    #)]
    param(
        # Shared ID column(s)/header(s).
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string[]] $Id,
        # CSV files.
        [Parameter(ParameterSetName='Files',Mandatory=$true)][ValidateScript({Test-Path $_ -PathType Leaf})][string[]] $Path,
        # Input custom PowerShell objects.
        [Parameter(ParameterSetName='Objects',Mandatory=$true)][psobject[]] $InputObject,
        # Optional delimiter that's used if you pass file paths (default is a comma).
        [string] $Delimiter = ',',
        # Optional multi-ID column string separator (default "#Merge-Csv-Separator#").
        [string] $Separator = '#Merge-Csv-Separator#'
    )
    
    [psobject[]] $CsvObjects = @()
    if ($PSCmdlet.ParameterSetName -eq 'Files') {
        $CsvObjects = foreach ($File in $Path) { ,@(Import-Csv -Delimiter $Delimiter -Path $File) }
    }
    else {
        $CsvObjects = $InputObject
    }

    $Headers = @()
    foreach ($Csv in $CsvObjects) {
        $Headers += , @($Csv | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name)
    }
	

	$Counter = 0
    foreach ($h in $Headers) {
        $Counter++
		Write-Host $h
        foreach ($Column in $Id) {
            if ($h -notcontains $Column) {
                Write-Error "Headers in object/file $Counter doesn't include $Column. Exiting."
                return
            }
        }
    }

    $HeadersFlatNoShared = $Headers | ForEach-Object { $_ } | Where-Object { $Id -notcontains $_ }
    if ($HeadersFlatNoShared.Count -ne ($HeadersFlatNoShared | Sort-Object -Unique).Count) {
        Write-Error "Some headers are shared. Are you just looking for '@(ipcsv csv1) + @(ipcsv.csv2) | Export-Csv ...'?`nTo remove duplicate (between the files to merge) headers from a CSV file, Import-Csv it, pass it to Select-Object, and omit the duplicate header(s)/column(s).`nExiting."
        return
    }
    
    $SharedColumnHashes = @()
    $SharedColumnCount = $Id.Count
    $Counter = 0
    foreach ($Csv in $CsvObjects) {
        $SharedColumnHashes += @{}
        $Csv | ForEach-Object {
			$row = $_
			#Write-Host "row = $row"
			#Write-Host "Counter=$Counter"
			#Write-Host "--->$($Headers[$Counter])<---"
            $CurrentID = $(for ($i=0; $i -lt $SharedColumnCount; $i++) {
                $_ | Select -ExpandProperty $Id[$i] -EA SilentlyContinue
            }) -join $Separator
            #Write-Host "-->CurrentID=$CurrentID"
            if (!$SharedColumnHashes[$Counter].ContainsKey($CurrentID)) {
				Write-Host "-->`$_=$_, `$Counter=$Counter, `$CurrentID=$CurrentID, `$Headers[`$Counter]=$Headers[$Counter]" -ForegroundColor $global:colours.Information
				$rowvalues=$_
				#Write-Host "`$CurrentID=$CurrentID"
				#Write-Host "`$(`$Headers[`$Counter])=$($Headers[$Counter])"
                $SharedColumnHashes[$Counter].Add($CurrentID,($rowvalues | Select -Property "$($Headers[$Counter])"))
				#$SharedColumnHashes[$Counter].Add($CurrentID,$rowvalues)
            }
            else {
                Write-Warning ("Duplicate identifying (shared column(s) ID) entry found in CSV data/file $($Counter+1): " + ($CurrentID -replace ([regex]::Escape($Separator)), ', '))
            }
        } 
        $Counter++
    }

    $Result   = @{}
    $NotFound = @{}
    
    foreach ($Counter in 0..($SharedColumnHashes.Count-1)) {
        
        foreach ($InnerCounter in (0..($SharedColumnHashes.Count-1) | Where-Object { $_ -ne $Counter })) {
            
            foreach ($Key in $SharedColumnHashes[$Counter].Keys) {
                Write-Verbose "Key: $Key, Counter: $Counter, InnerCounter: $InnerCounter"
				
                $Obj = New-Object PSObject
                if ($SharedColumnHashes[$InnerCounter].ContainsKey($Key)) {
                    
                    foreach ($Header in $Headers[$InnerCounter]) {
                        if ($Id -notcontains $Header) {
							$val=$SharedColumnHashes[$InnerCounter].$Key | Select "$Header"
							Write-Host "Key: $Key, Counter: $Counter, InnerCounter: $InnerCounter, Header=$Header, val=$val" -ForegroundColor $global:colours.Information
							#Write-Host "--->>`$header=$header, `$val=$val"
                            Add-Member -InputObject $Obj -MemberType NoteProperty -Name "$Header" -Value "$val"
                        }
                    }
                    
                }
                else {
                    foreach ($Header in $Headers[$Counter]) {
                        if ($Id -notcontains $Header) {
                            Add-Member -InputObject $Obj -MemberType NoteProperty -Name $Header -Value ($SharedColumnHashes[$Counter].$Key | Select $Header)
                        }
                    }
                    if (-not $NotFound.ContainsKey($Key)) {
                        $NotFound.Add($Key, (@($Counter)))
                    }
                    else {
                        $NotFound[$Key] += $Counter
                    }
                }
                
                if (-not $Result.ContainsKey($Key)) {
                    $Result.$Key = $Obj
                }
                else {
                    foreach ($Property in $Obj | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name) {
                        if (-not ($Result.$Key | Get-Member -MemberType NoteProperty -Name $Property)) {
							#Write-Host "`t`t--->> `$Property=$Property, `$Obj.`$Property=$Obj.$Property"
                            Add-Member -InputObject $Result.$Key -MemberType NoteProperty -Name $Property -Value $Obj.$Property #-EA SilentlyContinue
                        }
                    }
                }
                
            }
            
        }

    }
    
    if ($NotFound) {
        foreach ($Key in $NotFound.Keys) {
            Write-Warning "Identifying column entry '$($Key -replace ([regex]::Escape($Separator)), ', ')' was not found in all CSV data objects/files. Found in object/file no.: $(
                if ($NotFound.$Key) { ($NotFound.$Key | %{([int]$_)+1} | Sort -Unique) -join ', '}
                elseif ($CsvObjects.Count -eq 2) { '1' }
                else { 'none' }
                )"
        }
    }
    
    #$Global:Result = $Result
    
    $Counter = 0
    [hashtable[]] $SharedHeaders = $Id | ForEach-Object {
        @{n="$($Id[$Counter])";e=[scriptblock]::Create("(`$_.Name -split ([regex]::Escape('$Separator')))[$Counter]")}
        $Counter++
    }
    
    [hashtable[]] $HeaderProperties = $HeadersFlatNoShared | ForEach-Object {
		#Write-Host "`t`t---> `$_=$_"
		#@{n=$_.ToString(); e=[scriptblock]::Create("`$_.Value.$_ | Select -ExpandProperty $_")}
		@{n=$_.ToString(); e=[scriptblock]::Create("`$_.Value.""$_"" | Select -ExpandProperty ""$_""")}
    }
    
    # Return results.
    $Result.GetEnumerator() | Select -Property ($SharedHeaders + $HeaderProperties)
	
#}
