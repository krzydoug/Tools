function Install-7zip {
    [cmdletbinding()]
    Param(
        [switch]$Cleanup
    )

    $baseurl = 'https://www.7-zip.org/'

    Write-Verbose "Searching for latest 7zip installation packages"

    $downloadlist = Invoke-WebRequest -Uri "$baseurl\download.html" -UseBasicParsing

    $pattern = '(?s)href="(?<URL>a.+?)(?=").+?\r?\n.+?>(?<Extension>\S+?)(?=<).+?\r?\n.+?>(?<System>.+?)(?=<)(.+?\r?\n.+?>(?<Description>.+?)(?=<))?'

    $downloadlist = switch -Regex ($downloadlist.RawContent -split '<TR>'){
        $pattern {
            if($Matches.Description){
                $description = $Matches.Description
                $Matches.Remove(1)
            }
            else{
                $Matches.Description = $description
            }

            $Matches.FileName = $Matches.URL -replace 'a/'
            $Matches.URL = "$baseurl{0}" -f $Matches.URL
            $Matches.Remove(0)

            [PSCustomObject]$Matches
        }
    }

    $OS = [System.Environment]::OSVersion.Platform

    Switch ($OS){
        Win32NT {
            $7z = $downloadlist | Where-Object extension -like '*.msi' |
                Select-Object -First 1
            $7zfile = "$env:USERPROFILE\$($7z.FileName)"
            Write-Verbose "Downloading $($7z.FileName)"
            Invoke-WebRequest $7z.URL -OutFile $7zfile
            Write-Verbose "Installing $7zfile" -Verbose
            $process = Start-Process msiexec -ArgumentList '/i',$7zfile,'/quiet','/qn' -Wait -PassThru
            if($process.exitcode -eq 0){
                Write-Verbose "7zip installed successfully"
            }
            else{
                Write-Warning "Process exited with code $($process.ExitCode)"
            }
        }

        Unix {
            $7z = $downloadlist | Where-Object FileName -like '*linux-x64.tar.xz' |
                Select-Object -First 1
            $7zfile = "~/$($7z.FileName)"
            Write-Verbose "Downloading $($7z.FileName)"
            Invoke-WebRequest $7z.URL -OutFile $7zfile
            set-location ~
            Write-Verbose "Extracting $7zfile" -Verbose
            tar -xf $7zfile
        }

        Darwin {
            $7z = $downloadlist | Where-Object FileName -like '*mac.tar.xz' |
                Select-Object -First 1
            $7zfile = "~/$($7z.FileName)"
            Write-Verbose "Downloading $($7z.FileName)"
            Invoke-WebRequest $7z.URL -OutFile $7zfile
            set-location ~
            Write-Verbose "Extracting $7zfile" -Verbose
            tar -xf $7zfile
        }
    }
        
    if($Cleanup){
        if(Test-Path $7zfile){
            Write-Verbose "Deleting $7zfile" -Verbose
            Remove-Item $7zfile -Force
        }
    }
}
