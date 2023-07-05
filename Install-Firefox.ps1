function Install-Firefox {
    [cmdletbinding()]
    Param()

    $regpath="hklm:\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\" 
    $installed = Get-ChildItem $regpath | Where-Object name -like '*firefox*'

    if($installed){
        $version = [version]($installed | Get-ItemPropertyValue -Name DisplayVersion)

        if($version -ge [version]'115.0.0'){
            Write-Verbose "[$(Get-Date -Format s)] Firefox version $version is installed."
            return
        }
    }

    $firefoxmsiurl = 'https://download.mozilla.org/?product=firefox-msi-latest-ssl&os=win64&lang=en-US'
    $firefoxmsi = Join-Path $env:TEMP firefox.msi

    if(Test-Path $firefoxmsi){
        Write-Verbose "[$(Get-Date -Format s)] Firefox MSI found at $firefoxmsi"
    }
    else{
        Write-Verbose "[$(Get-Date -Format s)] Downloading Firefox MSI to $firefoxmsi"

        try{
            Invoke-WebRequest -Uri $firefoxmsiurl -UseBasicParsing -OutFile $firefoxmsi
        }
        catch{
            Write-Warning "[$(Get-Date -Format s)] Error downloading firefox MSI: $($_.exception.message)"
        }

        if(Test-Path $firefoxmsi){
            Write-Verbose "[$(Get-Date -Format s)] Firefox MSI download succeeded"
        }
        else{
            Write-Warning "[$(Get-Date -Format s)] Firefox MSI not found"
            break
        }
    }

    Write-Verbose "[$(Get-Date -Format s)] Installing Firefox"

    $DateStamp = Get-Date -Format yyyyMMddTHHmmss
    $log = '{0}-{1}.log' -f $DateStamp,'Firefox_Installation'

    $MsiParams = @{
        FilePath     = 'msiexec.exe'

        ArgumentList = "/i",
                        "`"$firefoxmsi`"",
                        "/qn",
                        "/norestart",
                        "/L",
                        "`"$log`""

        Wait         = [switch]::Present

        PassThru     = [switch]::Present
    }

    try{
        $result = Start-Process @MsiParams

        if($result.ExitCode -eq 0){
            Write-Verbose "[$(Get-Date -Format s)] MSI execution succeeded"
        }
        else{
            $msg = "[$(Get-Date -Format s)] Firefox MSI execution completed with error. ExitCode: $($result.ExitCode)"
            Write-Error $msg
        }
    }
    catch{
        $msg = "[$(Get-Date -Format s)] Error starting MSI installation: $($_.exception.message)"
        Write-Error $msg
    }
}
