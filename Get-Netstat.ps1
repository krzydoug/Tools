Function Get-Netstat {
    [cmdletbinding()]
    [outputtype([PSCustomObject[]])]
    Param(
        [switch]$IncludeProcessDetails
    )
    
    # https://www.reddit.com/r/PowerShell/comments/khiwjo/parsing_netstat_ano/

    $sb = {
        param($proto,$pcid,$state)
        $localaddr,$localport,$remoteaddr,$remoteport = $_[1..2] |
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

    $output = switch -Regex (netstat -ano){
        'TCP' {
            , -split $_ | ForEach-Object {
                $sb.Invoke($($_[0,4,3]))
            }
        }
        'UDP' {
            , -split $_ | ForEach-Object {
                $sb.Invoke($_[0],$_[3],'STATELESS')
            }
        }
    }

    if($IncludeProcessDetails){
        $process = Get-CimInstance -ClassName Win32_Process | Group-Object -Property ProcessID -AsHashTable -AsString

        $output | ForEach-Object {
            $owner = $process[$_.processid] | Invoke-CimMethod -MethodName GetOwner |ForEach-Object{
                if($_.returnvalue -eq 0){$_.Domain,$_.User -join '\'}
            }

            $_ | Select-Object *,@{n='FilePath';e={$process.$($_.processid).Path}},
                                 @{n='Owner';e={$owner}},
                                 @{n='StartTime';e={$process.$($_.processid).CreationDate}},
                                 @{n='CommandLine';e={$process.$($_.processid).CommandLine}}
        }
    }
    else{
        $output
    }
}
