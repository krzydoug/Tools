Function Install-MSI {
    [cmdletbinding()]
    Param(
        [parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [alias('Path','FullName','FullPath')]
        [System.IO.FileInfo[]]
        $MsiFile
    )
    
    process{
        Write-Verbose "[$((Get-Date).ToString("s"))] Install-Msi function initializing"
    
        foreach($msi in $MsiFile){
            if(Test-Path $msi.FullName){
                Write-Verbose "[$((Get-Date).ToString("s"))] Installing Msi package $($msi.BaseName)"
    
                $DateStamp = Get-Date -Format yyyyMMddTHHmmss
                $log = Join-Path $env:TEMP ('{0}-{1}.log' -f $DateStamp,"MSI_Installation")
            
                Write-Verbose "[$((Get-Date).ToString("s"))] MSI logfile : $log"
    
                $MsiParams = @{
                    FilePath     = 'msiexec.exe'
    
                    ArgumentList = "/i",
                                    "`"$($msi.FullName)`"",
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
                        Write-Verbose "[$((Get-Date).ToString("s"))] MSI execution succeeded"
                    }
                    elseif($result.ExitCode -eq 3010){
                        Write-Verbose "[$((Get-Date).ToString("s"))] MSI execution succeeded but a reboot is required"
                    }
                    else{
                        Write-Warning "[$((Get-Date).ToString("s"))] MSI execution completed with error. ExitCode: $($result.ExitCode)"
                    }
                }
                catch{
                    Write-Log "[$((Get-Date).ToString("s"))] Error starting MSI installation: $($_.exception.message)"
                }
            }
        }

        Write-Verbose "[$((Get-Date).ToString("s"))] Install-Msi function complete"
    }
}
