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
        Number of milliseconds before the connection should timeout (defaults to 1000)

        .PARAMETER ThrottleLimit
        Number of concurrent host threads (defaults to 32)

        .OUTPUTS
        [PSCustomObject]


        .EXAMPLE

        PS> $params = @{
                ComputerName  = (Get-ADComputer -Filter "enabled -eq '$true' -and operatingsystem -like '*server*'").name
                Port          = 20,21,25,80,389,443,636,1311,1433,3268,3269
                OutVariable   = 'results'
            }

        PS> Test-TCPPort @params | Out-GridView


        .EXAMPLE

        PS> Test-TCPPort -ComputerName www.google.com -Port 80, 443

        ComputerName     80  443
        ------------     --  ---
        www.google.com True True


        .EXAMPLE

        PS> Test-TCPPort -ComputerName google.com,bing.com,reddit.com -Port 80, 443, 25, 389 -Timeout 400

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

            [string[]]$Port,

            [int]$Timeout = 1000,

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

                    $ht = $using:ht
                    $obj = New-Object System.Net.Sockets.TcpClient
                    $ht[$using:_].$_ = ($false,$true)[$(try{$obj.ConnectAsync($Using:_, $_).Wait($using:time)}catch{})]

                } -ThrottleLimit @($using:port).count

                $ht[$_] | Select-Object -Property (,'ComputerName' + $using:port)

            } -ThrottleLimit $ThrottleLimit
        }

        end{}

    }
