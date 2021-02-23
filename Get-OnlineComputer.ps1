function Get-OnlineComputer{
[Cmdletbinding(DefaultParameterSetName='Timeout')]
Param(
    
    [Alias('ComputerName')]
    [Parameter(
        Position=0,
        ValueFromPipelineByPropertyName=$true,
        ValueFromPipeline=$true
        )][string[]]$Name,

    [Parameter()][switch]$Passthru,

    [Parameter(ParameterSetName='Timeout')][int]$Timeout = 10,

    [Parameter(ParameterSetName='Force')][switch]$Force
    
)
    begin{
        $debugtime = [System.Diagnostics.Stopwatch]::StartNew()
        write-verbose $("  [{0:N4}  BEGIN    Get-OnlineComputer ]  Get-OnlineComputer Start..." -f $($debugtime.Elapsed.TotalSeconds))

        $scriptblock = {
            Param([parameter(position=0)]$pc,
                  [parameter(position=1)]$timer
            )
                        
            $online = $false
            try{
                Push-Location "\\$pc\admin$" -ErrorAction stop
            }
            catch{
                Write-Warning "unable to push location to $pc"
            }
            $loc = get-location
            if ($loc.path.split('::')[2] -eq "\\$pc\admin$"){
                $online = $true
                pop-location
            }
            $outobject = [pscustomobject]@{
                Name = $pc
                Online = $online
                TotalSeconds = "{0:N4}" -f $timer.Elapsed.TotalSeconds
            }
            write-output $outobject
            $outobject = $online = $pc = $loc = $null
        }
        $runspaces = $tracker = @()
        $pool = [RunspaceFactory]::CreateRunspacePool(1,1000)
        $pool.ApartmentState = "MTA"
        $pool.Open()
        $index = 0
        $runspaces = New-Object System.Collections.ArrayList
    }
    
    process{
        $currobj = ($_)
        foreach($n in $PSBoundParameters.name){if($n){
            write-verbose $("  [{0:N4}  PROCESS  Get-OnlineComputer ]  Creating runspace for $n..." -f $($debugtime.Elapsed.TotalSeconds))
            $timer = [System.Diagnostics.Stopwatch]::StartNew()                                                                                                                                                                                                                                                                                         
            $runspace = [PowerShell]::Create()
            try{
                $null = $runspace.AddScript($Scriptblock)
                $null = $runspace.AddArgument($n)
                $null = $runspace.AddArgument($timer)
                $runspace.RunspacePool = $pool
                [void]$runspaces.add([PSCustomObject]@{ Name = $n; Index = $index; Pipe = $runspace; Status = $runspace.BeginInvoke(); Object = $currobj})
            }
            Catch{
                Write-warning $("  [{0:N4}  PROCESS  Get-OnlineComputer ]  Error creating runspace for $n..." -f $($debugtime.Elapsed.TotalSeconds))
            }
            $index++
            foreach ($runspace in ($runspaces | Where-Object {$_.status.IsCompleted -and $_.name -notin $tracker.name} | sort -Property index -Descending)){
                $result = $runspace.Pipe.EndInvoke($runspace.Status)
                $tracker += ([PSCustomObject]@{Name = $runspace.name})
                if (($result.Online -eq $true) -or ($force)){
                    write-verbose $("  [{0:N4}  END      Get-OnlineComputer ]  Runspace completed for $($runspace.name)..." -f $($debugtime.Elapsed.TotalSeconds))
                    if ($Passthru){
                        $outobject = $runspace.object
                        $outobject | Add-Member -MemberType NoteProperty -Name Online -Value $result.online -Force
                    }else{
                        $outobject = [pscustomobject]@{
                            Name = $result.name
                            Online = $result.online
                            TotalSeconds = $result.totalseconds
                        }
                    }
                    write-output $outobject
                }
                $runspace.Pipe.dispose()
                $runspaces.RemoveAt(($runspaces.IndexOf($runspace)))
            }
         }}
    } #Process

    end{
        $results = @()
        $t = [System.Diagnostics.Stopwatch]::StartNew()
        do{
            foreach ($runspace in ($runspaces | Where-Object {$_.status.IsCompleted -and $_.name -notin $tracker.name} | sort -Property index -Descending)){
                write-verbose $("  [{0:N4}  END      Get-OnlineComputer ]  Runspace completed for $($runspace.name)..." -f $($debugtime.Elapsed.TotalSeconds))
                $tracker += ([PSCustomObject]@{Name = $runspace.name})
                $result = $runspace.Pipe.EndInvoke($runspace.Status)
                if (($result.Online -eq $true) -or ($force)){
                    if ($Passthru){
                        $outobject = $runspace.object 
                        $outobject | Add-Member -MemberType NoteProperty -Name Online -Value $result.online -Force
                    }else{
                        $outobject = [pscustomobject]@{
                            Name = $result.name
                            Online = $result.online
                            TotalSeconds = $result.totalseconds
                        }
                    }
                    write-output $outobject
                }
                $runspace.Pipe.dispose()
                $runspaces.RemoveAt(($runspaces.IndexOf($runspace)))
            }
            if (!$force){
                if($t.Elapsed.TotalSeconds -gt $timeout){
                    write-verbose $("  [{0:N4}  END      Get-OnlineComputer ]  Trying to end runspaces forcefully..." -f $($debugtime.Elapsed.TotalSeconds))
                    foreach($runspace in ($runspaces | sort -Property index -Descending)){
                        write-verbose $("  [{0:N4}  END      Get-OnlineComputer ]  Closing runspace for $($runspace.name)..." -f $($debugtime.Elapsed.TotalSeconds))
                        $tracker += ([PSCustomObject]@{Name = $runspace.name})
                        $runspace.Pipe.dispose()
                        #$runspace.Pipe.endstop($runspace.Pipe.BeginStop($null,$runspace.Status))
                        $runspaces.RemoveAt(($runspaces.IndexOf($runspace)))
                    }
                }
            }
        }while($tracker.count -lt $index)
        $pool.Close()
        $pool.Dispose()
        write-verbose $("  [{0:N4}  END      Get-OnlineComputer ]  Get-OnlineComputer complete..." -f $($debugtime.Elapsed.TotalSeconds))
        $timer = $runspace = $debugtime = $results = $outobject = $null

    }

}
