function Get-TextFromPdf {
    [cmdletbinding()]
    Param(
        [parameter(Mandatory,ValueFromPipeline)]
        $Path
    )

    begin{
        try{
            $unzip = Join-Path $env:TEMP itextsharp
            $zip = Join-Path $env:TEMP itextsharp.zip

            if(-not ($dll = Get-ChildItem C:\powershell\itextsharp -Filter *.dll -Recurse )){
                Write-Verbose "Downloading itextsharp"

                Invoke-WebRequest https://github.com/itext/itextsharp/releases/download/5.5.13.1/itextsharp.5.5.13.1.nupkg -OutFile $zip
                Expand-Archive $zip -DestinationPath $unzip
                $dll = Get-ChildItem $unzip -Filter *.dll -Recurse
            }   

            Add-Type -Path $dll.FullName
        }
        catch{
            Write-Warning $_.exception.message
            break
        }
    }

    process{
        foreach($pdf in $Path){
            Write-Verbose "Processing $($pdf)"

            try{
                $pdfreader = New-Object iTextSharp.text.pdf.pdfreader -ArgumentList $pdf.FullName

                for ($page = 1; $page -le $pdfreader.NumberOfPages; $page++){
		    [iTextSharp.text.pdf.parser.PdfTextExtractor]::GetTextFromPage($pdfreader,$page)
	        }

	        $pdfreader.Close()
            }
            catch{
                Write-Warning $_.exception.message
            }
        }
    }
}
