Function Test-TCPPort {
    <#
    .SYNOPSIS
    Test one or more TCP ports against one or more hosts
    .DESCRIPTION
    Test for open port(s) on one or more hosts
    .PARAMETER ComputerName
    Specifies the name of the host(s)
    .PARAMETER Port
    Specifies the TCP port(s) to test
    .PARAMETER Timeout
    Number of milliseconds before the connection should timeout (defaults to 2000)
    .PARAMETER ThrottleLimit
    Number of concurrent host threads (defaults to 32)
    .OUTPUTS
    [PSCustomObject]
    .EXAMPLE
    $params = @{
        ComputerName  = (Get-ADComputer -Filter "enabled -eq '$true' -and operatingsystem -like '*server*'").name
        Port          = 20,21,25,80,389,443,636,1311,1433,3268,3269
        OutVariable   = 'results'
        Timeout       = 1000
    }
    Test-TCPPort @params | Out-GridView
    .EXAMPLE
    Test-TCPPort -ComputerName www.google.com -Port 80, 443 -Timeout 600
    ComputerName     80  443
    ------------     --  ---
    www.google.com True True
    .EXAMPLE
        
    $params = @{
        ComputerName  = (Get-ADComputer -Filter "enabled -eq '$true' -and operatingsystem -like '*server*'").name
        Port          = 20,21,25,80,389,443,636,1311,1433,3268,3269
        OutVariable   = 'results'
        ThrottleLimit = 150
    }
    [PSCustomObject]@{
        'Total hosts'      = ($hosts = $params.ComputerName.count)
        'Total ports'      = ($ports = $params.Port.count)
        'Total tests'      = ($total = $hosts * $ports)
        'Total seconds'    = ($seconds = (Measure-Command -Expression {Test-TCPPort @params}).totalseconds)
        'Tests per second' = $total / $seconds
        'Total open ports' = $results.foreach{$_.psobject.members.where{$_.value -eq $true}}.count
    }
    $results | Out-GridView
        
    Total hosts      : 27
    Total ports      : 11
    Total tests      : 297
    Total seconds    : 4.6290259
    Tests per second : 64.1603668711381
    Total open ports : 38
        
        
    .EXAMPLE
    Test-TCPPort -ComputerName google.com,bing.com,reddit.com -Port 80, 443, 25, 389 -Timeout 400
    ComputerName : google.com
    80           : True
    443          : True
    25           : False
    389          : False
    ComputerName : bing.com
    80           : True
    443          : True
    25           : False
    389          : False
    ComputerName : reddit.com
    80           : True
    443          : True
    25           : False
    389          : False
    
    .Notes
    Requires powershell core (foreach-object -parallel) and it's only been tested on 7.2
    #>

    [cmdletbinding()]
    Param(
        [string[]]$ComputerName,

        [validaterange(1,65535)]
        [string[]]$Port,

        [int]$Timeout = 2000,

        [int]$ThrottleLimit = 32
    )

    begin{
        $ErrorActionPreference = 'Stop'
        $syncedht = [HashTable]::Synchronized(@{})
    }

    process{
        $ComputerName | ForEach-Object -Parallel {

            $ht = $using:syncedht
            $ht[$_] = @{ComputerName=$_}
            $time = $using:Timeout

            $using:port | ForEach-Object -Parallel {
                
                $result = $false

                $ht = $using:ht
                $obj = New-Object System.Net.Sockets.TcpClient
                $ht[$using:_].$_ = $false
                    
                try{
                    if($obj.ConnectAsync($Using:_, $_).Wait($using:time)){
                        $ht[$using:_].$_ = $true
                    }
                }
                catch{
                }

            } -ThrottleLimit @($using:port).count

            $ht[$_] | Select-Object -Property (,'ComputerName' + $using:port)
`
        } -ThrottleLimit $ThrottleLimit
    }

    end{}

}
