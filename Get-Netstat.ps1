Function Get-Netstat {
    [cmdletbinding()]
    [outputtype([PSCustomObject[]])]
    Param(
        [switch]$IncludeProcessDetails
    )
    
    # https://www.reddit.com/r/PowerShell/comments/khiwjo/parsing_netstat_ano/

    $sb = {
        param($proto,$local,$remote,$pcid,$state)
        $pcid, $program = $pcid -split '/'
        $localaddr,$localport,$remoteaddr,$remoteport = $local,$remote |
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
            '(?<Line>TCP.+)\s(?<PID>\d+/.+?|-)$' {
                , -split $_ | ForEach-Object {
                    $sb.Invoke($($_[0,3,4,6] + $_[5]))
                }
            }
            '(?<Line>UDP.+)\s(?<PID>\d+/.+?|-)$' {
                , -split $_ | ForEach-Object {
                    $sb.Invoke($($_[0,3,4,5] + 'STATELESS'))
                }
            }
        }

        if($IncludeProcessDetails){
            $output | ForEach-Object {
                if($_.ProcessID -match '\d+'){
                    $process = Get-Process -PID $_.ProcessID -IncludeUserName
                    $starttime = $process.StartTime

                    $owner = ((ps -o user,pid) + $(if($sudo){(ps -U root -o user,pid) + (sudo ps -o user,pid)}) | ForEach-Object{
                        , -split $_ | ForEach-Object{
                            [PSCustomObject]@{User=$_[0];PID=$_[1]}
                        }}|where pid -eq  $_.ProcessID).user
                    $owner = $process.Username
                }

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
                $process = Get-Process -Id $_.ProcessID -IncludeUserName
                $owner = $process.username
                $process = $processlist[$_.processid]
                $starttime = $process.CreationDate

                if($null -eq $owner){
                    $process | Invoke-CimMethod -MethodName GetOwner | ForEach-Object{
                        $owner = if($_.returnvalue -eq 0){$_.Domain,$_.User -join '\'}
                    }
                }

                $_ | Select-Object $selectprops
            }
        }
        else{
            $output
        }
    }
}
