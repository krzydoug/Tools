using namespace system.collections.generic

function Get-PingableHost{
    <#
    .Synopsis
    Rapidly tests ping to a list of computers, IPs, or domains.

    .DESCRIPTION
    Using the SendPingAsync method of the System.Net.NetworkInformation.Ping class, this function rapidly tests if a host responds to ping. 

    .NOTES   
    Name: Get-PingableHost.ps1
    Author: Doug Maurer
    Version: 2.0.1.2
    DateCreated: 2016-11-22
    DateUpdated: 2022-07-01

    .LINK

    .INPUTS
    ADComputer or list of names/IPs/domains

    .OUTPUTS
    pscustomobject

    .PARAMETER ComputerName
    Accepts ADComputer objects, IP addresses, host, or domain names via the pipeline or argument.

    .PARAMETER Summary
    Returns Ping summary that includes an array of names, total tested count, total online count, and totalseconds.  

    .PARAMETER Force
    Returns result for all objects, not just those that are pingable.

    .PARAMETER Unique
    Ensures that each host is unique in case duplicates were submitted. 

    .EXAMPLE   
    @(1..254 | foreach {"192.168.1." + $_}) | Get-PingableHost
    Description 
    -----------     
    Takes IP addresses 192.168.1.1 - 192.168.1.254 as pipeline input and returns default pingablehost object.

    .EXAMPLE
    Get-ADComputer -filter * | Get-PingableHost
    Description
    -----------
    This command pipes all ADComputer objects into Get-PingableHost and returns only those that succeeded.

    .EXAMPLE
    $hosts = @(1..255 | foreach {"192.168.0." + $_})+@(0..254 | foreach {"192.168.1." + $_}) | Get-PingableHost -Summary
    Description
    -----------
    Takes IPs from 192.168.0.0/23 and captures any returned pingablehost objects to the $hosts variable and displays the summary information in the console. 

    .EXAMPLE
    Get-Content C:\Servers.txt | Get-PingableHost -Unique -Force
    Description
    -----------
    Takes the list of servers in servers.text and ensures no duplicate names are tested then it returns a pingablehost object for all tested hosts. 

    .EXAMPLE
    Get-PingableHost -Name "google.com","cnn.com","amazon.com"
    Description
    -----------
    Tests each item provided and returns pingablehost object for those that respond. 

    .EXAMPLE
    $hosts = "google.com","cnn.com","amazon.com" | Get-PingableHost -Verbose
    Description
    -----------
    Same as the previous example except fed via pipeline and captured to a variable. 
    #>

    [Cmdletbinding()]
    Param(
        [Parameter(Mandatory,Position=0,ValueFromPipelineByPropertyName,ValueFromPipeline)]
        [Alias('ComputerName')]
        [string[]]$Name,

        [Parameter()]
        [switch]$Summary,

        [Parameter()]
        [switch]$Unique,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [int]$Timeout = 2000
    )
    Begin {
        $debugtime = $time = [System.Diagnostics.Stopwatch]::StartNew()
        Write-Verbose $("  [{0:N4}  BEGIN   ]  Initializing ping tasks..." -f $($debugtime.Elapsed.TotalSeconds))

        $dummy = [PSCustomObject]@{
            Status        = 'Failed'
            Address       = 'N/A'
            RoundTripTime = 'N/A'
            TotalSeconds  = 'N/A'
        }

        $results = $null
        $uniquetracker = New-Object list[object]
        $computerlist = New-Object list[object]
        $tasklist = New-Object list[object]

        Write-Verbose $("  [{0:N4}  PROCESS ]  Queueing ping tasks..." -f $($debugtime.Elapsed.TotalSeconds))
    }

    Process{
        foreach($Computer in $Name){
            $computerlist.Add(
                [PSCustomObject]@{
                    Name = $computer
                }
            )

            if ($unique){
                if ($uniquetracker.name -contains $computer){
                    return
                } else {
                    $uniquetracker.Add(
                        [PSCustomObject]@{
                            Name = $computer
                        }
                    )
                }
            }

            $tasklist.Add(
                [PSCustomObject]@{
                    ComputerName = $Computer
                    Task         = $(
                        try{
                            (New-Object System.Net.NetworkInformation.Ping).SendPingAsync($Computer,$Timeout)
                        }
                        catch{}
                    )
                    Timer        = [System.Diagnostics.Stopwatch]::StartNew()
                }
            )
        }
    }

    End{
        Write-Verbose $("  [{0:N4}  END     ]  Completing ping tasks..." -f $($debugtime.Elapsed.TotalSeconds))
        
        try{
            [System.Threading.Tasks.Task]::WaitAll($tasklist.Task)
        }
        catch{}
        
        foreach($task in $tasklist){
            if($task.task.result.status -eq 'Success'){
                $task.Task.result | ForEach-Object{
		    [PSCustomObject]@{
                        ComputerName  = $task.ComputerName
                        Status        = $_.Status
                        IPAddress     = $_.Address.IPAddressToString
                        RoundTripTime = $_.RoundTripTime
                        TotalSeconds  = "{0:N4}" -f $task.timer.Elapsed.TotalSeconds
	            }
                } -OutVariable +results
            }

            if($Force -and $null -eq $task.task.result){
                $dummy | Select @{n='ComputerName';e={$task.ComputerName}},* -OutVariable +results
            }
        }

        if($Force){
            foreach($computer in $computerlist | Where-Object Name -NotIn $results.computername){
                $dummy | Select @{n='ComputerName';e={$computer.Name}},*
            }
        }

        if ($Summary){
            $totalcount = $computerlist.count

            $summaryobj = [PSCustomObject]@{
                Hosts          =  @($results.computername)
                TotalTested    = $totalcount
                TotalOnline    = $results.computername.count
                TotalSeconds   = "{0:N3}" -f $([math]::round($debugtime.Elapsed.TotalSeconds,2))
                TestsPerSecond = "{0:N3}" -f $($totalcount / $debugtime.Elapsed.TotalSeconds)
            }
                
            write-host ($summaryobj | Format-Table -AutoSize | Out-String)
        }
    }
}
