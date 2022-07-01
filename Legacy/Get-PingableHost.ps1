function Get-PingableHost{
    <#
.Synopsis
Rapidly sends 1 ping to a list of computers, IPs, or domains and returns a pingablehost object.
 
.DESCRIPTION
Using .net runspaces, this functoin rapidly tests if a host responds to ping. If so, it returns a PingableHost object with the host (IP or name), boolean result, and the time it took.  

.NOTES   
Name: Get-PingableHost.ps1
Author: Doug Maurer
Version: 1.0.2.1
DateCreated: 2016-11-22
DateUpdated: 2017-12-10

.LINK

.INPUTS
ADComputer or list of names/IPs/domains

.OUTPUTS
PingableHost pscustomobject

.PARAMETER InputObject
Accepts ADComputer objects, IP addresses, host, or domain names via the pipeline or argument.

.PARAMETER Hostname
Accepts a list of IP addresses, host, or domain names as an argument.

.PARAMETER NameOnly
Returns only the name of the host, omitting the boolean result of the ping and the time it took.

.PARAMETER Summary
Returns PingableHostSummary object that includes an array of names, total tested count, total online count, and totalseconds.  

.PARAMETER Force
Returns PingableHost object for all objects, not just those that are pingable.

.PARAMETER Unique
Ensures that each host is unique in case duplicates were submitted. 

.EXAMPLE   
@(1..254 | foreach {"192.168.1." + $_}) | Get-PingableHost
Description 
-----------     
Takes IP addresses 192.168.1.1 - 192.168.1.254 as pipeline input and returns default pingablehost object.

.EXAMPLE
Get-ADComputer -filter * | Get-PingableHost -NameOnly
Description
-----------
This command pipes all ADComputer objects into Get-PingableHost and returns only the name of pingable hosts. 

.EXAMPLE
$hosts = @(1..255 | foreach {"192.168.0." + $_})+@(0..254 | foreach {"192.168.1." + $_}) | Get-PingableHost -summary
Description
-----------
Takes IPs from 192.168.0.0/23 and captures any returned pingablehost objects to the $hosts variable and displays the summary information in the console. 

.EXAMPLE
Get-Content C:\Servers.txt | Get-PingableHost -Unique -Force
Description
-----------
Takes the list of servers in servers.text and ensures no duplicate names are tested then it returns a pingablehost object for all tested hosts. 

.EXAMPLE
Get-PingableHost -Hostname "google.com","cnn.com","amazon.com"
Description
-----------
Tests each item provided and returns pingablehost object for those that respond. 

.EXAMPLE
$hosts = "google.com","cnn.com","amazon.com" | Get-PingableHost
Description
-----------
Same as the previous example except fed via pipeline and captured to a variable. 
#>

    [Cmdletbinding()]
    Param(
        [Parameter(ValueFromPipelineByPropertyName,ValueFromPipeline)][object[]]$InputObject,
        [Parameter()][string[]]$Hostname,
        [Parameter()][switch]$NameOnly,
        [Parameter()][switch]$Summary,
        [Parameter()][switch]$Unique,
        [Parameter()][switch]$Force
    )
    Begin {
        $debugtime = $time = [System.Diagnostics.Stopwatch]::StartNew()
        write-verbose $("  [{0:N4}  BEGIN   ]  Creating runspacepool..." -f $($debugtime.Elapsed.TotalSeconds))
        $computername = $runspaces = $pingablecomputers = @()
        $max = 4000
        $pool = [RunspaceFactory]::CreateRunspacePool(1,$max)
        $pool.ApartmentState = "MTA"
        $pool.Open()
        $namescriptblock = {
                Param (
                [string]$pc,
                $timer
                )
                [void]($test = Test-Connection `
                    -Count 1 `
                    -ComputerName $pc `
                    -ErrorAction SilentlyContinue)
                Return [PSCustomObject]@{
                    PSTypename = 'PingableHost'
                    Name = $pc
                    Pingable = $([bool]($test.statuscode -eq 0))
                    IPv4 = $test.IPV4Address.ipaddresstostring
                    TotalSeconds = "{0:N4}" -f $timer.Elapsed.TotalSeconds
                }
                $test = $null

        }
        $ipscriptblock = {
                Param (
                [string]$pc,
                $timer
                )
                Return [PSCustomObject]@{
                    PSTypename = 'PingableHost'
                    Name = $pc
                    Pingable = $([bool](Test-Connection `
                                -Count 1 `
                                -ComputerName $pc `
                                -ErrorAction SilentlyContinue))
                    IPv4 = $pc
                    TotalSeconds = "{0:N4}" -f $timer.Elapsed.TotalSeconds
                }

        }
        $index = 0
        if ($unique){
            $uniquetracker = @()
        }
    }
    Process{
        if ($PSBoundParameters.inputobject.name){
            $computer = $PSBoundParameters.inputobject.name
        }else{
            $computer = $PSBoundParameters.inputobject
        }
        if ($unique){
            if ($uniquetracker.name -contains $computer){
                return
            } else {
                $uniquetracker += @{
                    Name = $computer
                }
            }
        }
        $computername += $computer
        write-verbose $("  [{0:N4}  PROCESS ]  Creating runspace for $($computer)..." -f $($debugtime.Elapsed.TotalSeconds))
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        $runspace = [PowerShell]::Create()
        $currscript = $namescriptblock
        try{
            if ([System.Net.IPAddress]$_ -is [System.Net.IPAddress]){$currscript = $ipscriptblock}
        }
        Catch{}
        try{
            $null = $runspace.AddScript($currscript)
            $null = $runspace.AddArgument($computer)
            $null = $runspace.AddArgument($timer)
            $runspace.RunspacePool = $pool
            $runspaces += [PSCustomObject]@{ Index = $index; Pipe = $runspace; Status = $runspace.BeginInvoke() }
        }
        Catch{
            Write-warning $("  [{0:N4}  PROCESS ]  Error creating runspace for $($computer)..." -f $($debugtime.Elapsed.TotalSeconds))
        }
        $index++
    }
    End{
#region gather results
        $totalcount = $($computername.count)
        $results = [object[]]::new($index + 1)
        write-verbose $("  [{0:N4}  END     ]  Completing runspaces and grabbing output..." -f $($debugtime.Elapsed.TotalSeconds))
        $tracker = @()
        do {
            foreach ($runspace in ($runspaces | Where-Object {$_.index -notin $tracker.index -and $_.status.IsCompleted -eq $true})){
                $results[($runspace.index)] = $runspace.Pipe.EndInvoke($runspace.Status)
                $runspace.Pipe.Dispose()
                $tracker += @{
                    Index = $runspace.index
                }
            }
        }
        until($tracker.Count -eq $totalcount)
        $timer = $null
        $pool.Close()
        $pool.Dispose()
#endregion
#region process results
        write-verbose $("  [{0:N4}  END     ]  Processing output of jobs..." -f $($debugtime.Elapsed.TotalSeconds))
        $pingable = 0
        $pingablecomputers = foreach ($computer in $computername){
            $index = [int]$computername.IndexOf($computer)
            write-verbose $("  [{0:N4}  END     ]  Processing host $($computer)..." -f $($debugtime.Elapsed.TotalSeconds))
            if ($results[$index].Pingable){
                #$pingablecomputers += $results[$computername.IndexOf(($computer))]
                $results[$index]
                $pingable += 1
            } elseif ($Force){
                $results[$index]
            }
        }
#endregion
#region Switch return statements
        Try{
            if ($NameOnly){
                $pingablecomputers.name
            }
            else{
            $pingablecomputers
            }
        }
        Finally{
            if ($Summary){
                    $summaryoutput = [ordered]@{
                    PSType = 'PingableHostSummary'
                    Hosts  =  @($pingablecomputers.name)
                    TotalTested = $totalcount
                    TotalOnline = $pingable
                    TotalSeconds = "{0:N3}" -f $([math]::round($time.Elapsed.TotalSeconds,2))
                    TestsPerSecond = "{0:N3}" -f $($totalcount / $time.Elapsed.TotalSeconds)
                }
                $summaryobj = New-Object -TypeName psobject -property $summaryoutput
                write-host ($summaryobj | Format-Table -AutoSize | Out-String)
            }
        }
        remove-variable -name computername,debugtime,runspaces,results,pool,pingablecomputers,pingable,uniquetracker,totalcount,time -ErrorAction SilentlyContinue
#endregion
    }
}
