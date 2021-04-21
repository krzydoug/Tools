Function Get-ImagesFromPdf {

    [cmdletbinding()]
    Param(
        [Parameter(Mandatory,ValueFromPipeline,Position=0)]$SourcePdf,

        $DestinationPath = $env:temp,

        $Prefix = 'IMG'
    )

    Begin{
        $errpreference = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'

        $pdfdir = Join-Path $env:temp Xpdf\cmdtools

        if(!(Test-Path $pdfdir)){
            $null = New-Item -Path $pdfdir -ItemType Directory
        }

        $findimgtool = {Get-ChildItem $pdfdir -Filter pdfimages.exe -Recurse |
                          Select-Object -Last 1 | Select-Object -ExpandProperty FullName}

        $pdfimgtool = & $findimgtool

        if(!$pdfimgtool){
            try{
                $nc = New-Object System.Net.WebClient
                $zipfile = Join-Path $pdfdir 'xpdf-tools-win-4.03.zip'
                $url = 'https://dl.xpdfreader.com/xpdf-tools-win-4.03.zip'
                $nc.DownloadFile($url,$zipfile)
                Expand-Archive $zipfile $pdfdir
            }
            catch{
                Write-Warning "Error downloading Xpdf cmd tools"
                break
            }
        }

        $pdfimgtool = & $findimgtool
        
        if(!$pdfimgtool){
            Write-Warning "pdfimgages.exe not found"
            break
        }
    }

    Process{
        foreach($pdffile in $SourcePdf){

            if($pdffile -is [string]){
                try{
                    $pdffile = Get-Item $pdffile
                }
                catch{
                    Write-Warning $_.exception.message
                    continue
                }
            }

            try{
                Write-Verbose "Processing $($pdffile.fullname)"
                $arguments = "-j",$pdffile.fullname ,"$DestinationPath\$Prefix"
                & $pdfimgtool $arguments
            }
            catch{
                Write-Warning "Error encountered on $($pdffile.fullname)"
                Write-Warning $_.exception.message
            }
        }
    }

    End{
        $ErrorActionPreference = $errpreference
    }

}
