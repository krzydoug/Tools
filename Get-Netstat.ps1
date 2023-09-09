Function Get-Netstat {
    [cmdletbinding()]
    [outputtype([PSCustomObject[]])]
    Param(
        [switch]$IncludeProcessDetails
    )
    
    # https://www.reddit.com/r/PowerShell/comments/khiwjo/parsing_netstat_ano/

    $sb = {
        param($proto,$remote,$local,$pcid,$state)
        $localaddr,$localport,$remoteaddr,$remoteport = $remote,$local |
            Foreach-Object {-split ($_ -replace '(^.+):(.+$)','$1 $2')}
            
        [PSCustomObject]@{
            Protocol      = $proto
            LocalAddress  = $localaddr
            LocalPort     = $localport
            RemoteAddress = $remoteaddr
            RemotePort    = $remoteport
            ProcessID     = $pcid
            State         = $state
        }
    }

    $selectprops = '*',
                   @{n='FilePath';e={$process.Path}},
                   @{n='Owner';e={$owner}},
                   @{n='StartTime';e={$StartTime}},
                   @{n='CommandLine';e={$process.CommandLine}}

    if($IsLinux){
        $netstat = which netstat

        if(-not $netstat){
            Write-Warning "netstat utility not found"
            continue
        }

        $sudo = which sudo

        $output = if($sudo){
            & $sudo $netstat -tunpl
            & $sudo $netstat -tunp
        }else{
            & $netstat -tunpl
            & $netstat -tunp
        }

        $output = switch -Regex ($output){
            '(TCP.+)\s(?<PID>\d+/.+?)$' {
                $processid,$program = $matches.PID -split '/'
                , -split $matches.1 | ForEach-Object {
                    $sb.Invoke($($_[0,3,4] + $processid + $_[5]))
                }
            }
        }

        if($IncludeProcessDetails){
            $output | ForEach-Object {
                $process = Get-Process -PID $_.ProcessID
                $starttime = $process.StartTime

                $owner = (ps -o user,pid | ForEach-Object{
                    , -split $_ | ForEach-Object{
                        [PSCustomObject]@{User=$_[0];PID=$_[1]}
                    } }|where pid -eq  $_.ProcessID).user

                $_ | Select-Object $selectprops
            }
        }
        else{
            $output
        }
    }
    else{
        $output = switch -Regex (netstat -ano){
            'TCP' {
                , -split $_ | ForEach-Object {
                    $sb.Invoke($($_[0,1,2,4,3]))
                }
            }
            'UDP' {
                , -split $_ | ForEach-Object {
                    $sb.Invoke($_[0..3] + 'STATELESS')
                }
            }
        }

        if($IncludeProcessDetails){
            $processlist = Get-CimInstance -ClassName Win32_Process | Group-Object -Property ProcessID -AsHashTable -AsString

            $output | ForEach-Object {
                $process = $processlist[$_.processid]
                $starttime = $process.CreationDate

                $owner = $process | Invoke-CimMethod -MethodName GetOwner |ForEach-Object{
                    if($_.returnvalue -eq 0){$_.Domain,$_.User -join '\'}
                }

                $_ | Select-Object $selectprops
            }
        }
        else{
            $output
        }
    }
}
