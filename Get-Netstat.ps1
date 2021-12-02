Function Get-Netstat {
    [cmdletbinding()]
    [outputtype([PSCustomObject[]])]
    Param()
    
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

    switch -Regex (netstat -ano){
        'TCP' {
            , -split $_ | ForEach-Object {
                $sb.Invoke($($_[0,4,3]))
            }
        }
        'UDP' {
            , -split $_ | ForEach-Object {
                $sb.Invoke($_[0],$_[3],'Stateless')
            }
        }
    }
}
