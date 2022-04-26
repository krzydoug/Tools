Function Get-InstalledPrograms {
    [cmdletbinding()]
    Param(
        $Computername,
        [string[]]$Name = ''
    )

    Write-Verbose "Gathering programs on $computername"

    $params = @{
        ScriptBlock   = {
            Param(
                [string]$name
            )

            Function Get-InstalledPrograms{
                [cmdletbinding()]
                Param([alias("CN","ComputerName","HostName","Computer")][parameter(ValuefromPipeline=$true,ValueFromPipelineByPropertyName=$true)]$Name)

                begin{}
                process{
                    if(-not $Name){$Name = $env:COMPUTERNAME}
                        FOREACH ($PC in $Name) {
                        $computername=$PC
 
                        # Branch of the Registry  
                        $Branch='LocalMachine'
                        0..1 | ForEach-Object {
                            try{
                                $regservice = Get-Service -Name RemoteRegistry -ComputerName $pc -ErrorAction Stop
                            }catch{
                                if($_ -eq 2){
                                    Write-Warning "Unable to query remoteregistry on $PC"
                                    break
                                }
                            }
                        }
                        $tracker = New-Object System.Collections.ArrayList
                        try{
                            if($regservice.StartType -eq 'disabled'){Set-Service -InputObject $regservice -StartupType Manual -ErrorAction stop;$servicedisabled = $true}
                            if($regservice.Status -ne 'running'){Start-Service -InputObject $regservice  -ErrorAction SilentlyContinue;$servicestarted = $true;Start-Sleep -Seconds 2}
                        }catch{
                            write-warning "Unable to reach remote registry service on $PC";break
                        }

                        if((Get-Service -Name RemoteRegistry -ComputerName $computername -ErrorAction SilentlyContinue).status -ne 'running'){write-warning "Unable to reach remote registry service on $PC";break}
                        $SubBranch="SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall"   
                        @{View=512;Bit='32-Bit'},@{View=256;Bit='64-Bit'} | ForEach-Object{
                            $registry= [microsoft.win32.registrykey]::OpenremoteBaseKey($Branch,$PC,$_.view)
                            $registrykey=$registry.OpenSubKey($Subbranch)
                            $subkeys = $registrykey.GetSubKeyNames()
                            Foreach ($key in $subkeys)  
                            {
                                if($key -in $tracker.key){continue}
                                [void]$tracker.Add(@{Key=$key})
                                $NewSubKey = $SubBranch+"\\"+$key
                                $Readkey = $registry.OpenSubKey($NewSubKey)
                                try{
                                $Displayname = $Readkey.GetValue("DisplayName")
                                $Installdate = $readkey.GetValue("InstallDate")
                                $InstallLocation = $Readkey.GetValue("InstallLocation")
                                $DisplayVersion = $Readkey.GetValue("DisplayVersion")
                                $UninstallString = $readkey.GetValue("UninstallString")
                                }
                                catch{}
                                $properties = [ordered]@{
                                    PC = $PC
                                    Displayname = $displayname
                                    Version = $DisplayVersion
                                    Architecture = $_.bit
                                    Installed = $Installdate
                                    InstallPath = $InstallLocation
                                    UninstallString = $UninstallString
                                    Subkey= $key
                            }
                            $obj = New-Object -TypeName PSObject -Property $properties
                            write-output $obj
                            }
                        }

                        if($servicedisabled){Set-Service -InputObject $regservice -StartupType Disabled}
                        if($servicestarted){Stop-Service -InputObject $regservice -ErrorAction SilentlyContinue}
            
                    }
                }
                end{}
    
            }

            Get-InstalledPrograms | Where-Object displayname -Match $name
        }
        ErrorAction   = 'SilentlyContinue'
        ErrorVariable = '+errs'
        ArgumentList  = ($name -join '|')
    }

    if($Computername){
        $params.ComputerName  = $Computername
        $params.ThrottleLimit = 300 
    }

    Invoke-Command @params
}
