Function Search-Excel {
<#
    .SYNOPSIS
    Search for specific text/pattern inside excel files.

    .DESCRIPTION
    Search for specific text/pattern inside excel files.

    .EXAMPLE
    $SourceLocation = "C:\Some\Folder"
    $SearchText = "???-??-????"
    Get-ChildItem -Path $SourceLocation -Recurse -Include *.xlsx | Search-Excel -SearchText $SearchText -OutVariable results
    
    .EXAMPLE
    $params = @{
        FileName    = (Get-ChildItem -Path 'c:\temp\*' -Include *.xlsx).FullName
        SearchText  = '???-??-????'
        OutVariable = 'results'
    }
    
    .EXAMPLE
    $params = [PSCustomObject]@{
        FileName    = (Get-ChildItem -Path 'c:\temp\' -Filter *.xlsx -Recurse).FullName
        SearchText  = '???-??-????'
        OutVariable = 'results'
    }

    $params | Search-Excel

Search-Excel @params

    .NOTES
    The search does not appear to be regex based, so just wildcards * and ? that I know of. 
#>
    [cmdletbinding()]
    Param(
        [parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [alias('Path','FullName','FulllPath')]
        [string[]]$FileName,
        
        [parameter(Mandatory,ValueFromPipelineByPropertyName)]
        [alias('Pattern','Searchstring')]
        [string[]]$SearchText
    )

    begin {
        $Excel = New-Object -ComObject Excel.Application

        Function Search-ExcelFile {
            [cmdletbinding()]
            Param($Excel,$File,$SearchText)

            try{
                $Workbook = $Excel.Workbooks.Open($File)
            }
            catch{
                Write-Warning $_.exception.message
                continue
            }
            ForEach ($Worksheet in @($Workbook.Sheets)) {
                try{
                    $Found = $WorkSheet.Cells.Find($SearchText)
                }
                catch{
                    Write-Warning $_.exception.message
                    continue
                }

                If ($Found) {
                    $BeginAddress = $Found.Address(0,0,1,1)
                    [pscustomobject]@{
                        WorkSheet = $Worksheet.Name
                        Column    = $Found.Column
                        Row       = $Found.Row
                        Text      = $Found.Text
                        Address   = $File
                    }
                    Do {
                        try{
                            $Found = $WorkSheet.Cells.FindNext($Found)
                        }
                        catch{
                            Write-Warning $_.exception.message
                        }
                        $Address = $Found.Address(0,0,1,1)
                        If ($Address -eq $BeginAddress) {
                            break
                        }
                        [pscustomobject]@{
                            WorkSheet = $Worksheet.Name
                            Column    = $Found.Column
                            Row       = $Found.Row
                            Text      = $Found.Text
                            Address   = $File
                        }                 
                    } Until ($False)
                }
            }

            if($Workbook){
                try{
                    $workbook.close($false)
                }
                catch{
                    Write-Warning $_.exception.message
                }
            }
        }
    }

    process{
        foreach ($File in $FileName) 
        {
            Write-Verbose "[$(Get-Date)] Processing $File"
            Search-ExcelFile -Excel $Excel -File $File -SearchText $SearchText
        }
    }

    end{
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$excel)
        [gc]::Collect()
        [gc]::WaitForPendingFinalizers()
        Remove-Variable excel -ErrorAction SilentlyContinue
    }
}
