function Get-RebootTimespan {
    <#
    .SYNOPSIS
        Retrieve and correlate shutdown/startup events to measure reboot time
    .DESCRIPTION
        Retrieve and correlate shutdown/startup events to measure reboot time
    .EXAMPLE
        PS C:\> Get-RebootTimespan
    .EXAMPLE
        PS C:\> Get-RebootTimespan -ComputerName WIN-7DF08FA
    .EXAMPLE
        PS C:\> ‘WIN-7DF08FA’,’2016DC’  | Get-RebootTimespan
    .INPUTS
        String
    .OUTPUTS
        PSCustomObject
    .NOTES
        Since it depends on the OS logging, the timespan doesn't reflect the full time from clicking restart until ready for login. The shutdown event
        occurs near the end of the shutdown process and the startup event is early in the boot process. There are also times when a startup event exists
        without a related shutdown, this is usually unexpected shutdowns. 
    #>

    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline,ValueFromPipelineByPropertyName,Position=0)]
        [Alias('CN','Computer','Server','Host','Hostname')]
        [string]$ComputerName = $env:COMPUTERNAME
    )
    
    begin {
        $params = @{
            FilterHashtable = @{
                Logname      = 'System'
                ID           = 6005,6006
                ProviderName = 'Eventlog'
            }

            Oldest = $true
            ComputerName = $ComputerName
        }
    }
    
    process {

        $params.ComputerName = $ComputerName

        switch (Get-WinEvent @params){
            {$_.id -eq 6005} {
        
                if(!$stopped){            
                    $stopped = 'No related shutdown event found'
                    $total = 'N/A'
                }
                else{
                    [decimal]$total = "{0:n2}" -f ($_.timecreated - $stopped).totalseconds
                }

                [PSCustomObject]@{
                    ComputerName      = $ComputerName
                    ShutdownTimestamp = $stopped
                    StartupTimestamp  = $_.timecreated
                    TotalSeconds      = $total
                }

                Remove-Variable started,stopped,total -ErrorAction SilentlyContinue
            }

            {$_.id -eq 6006} {
                $stopped = $_.timecreated
            }
        }
    }
}
