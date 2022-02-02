function Test-NetConnectionUDP {
    <#
    .NOTES
    https://cloudbrothers.info/en/test-udp-connection-powershell/
    #>
    
    [CmdletBinding()]
    param (
        # Desit
        [Parameter(Mandatory = $true)]
        [int32]$Port,

        # Parameter help description
        [Parameter(Mandatory = $true,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [alias('Name','Host','HostName','CN','Computer')]
        [string]$ComputerName,

        # Parameter help description
        [Parameter(Mandatory = $false)]
        [int32]$SourcePort = 50000
    )

    begin {
        $ErrorActionPreference = 'Stop'
        Write-Verbose "Test-NetconnectionUDP initializing"

        # Create a UDP client object
        try{
            $UdpObject = New-Object system.Net.Sockets.Udpclient($SourcePort)
            # Define connect parameters
            $UdpObject.Connect($ComputerName, $Port)
        }
        catch{
            Write-Warning $_.exception.message
            break
        }
    }

    process {
        Write-Verbose "Sending UDP packet to $ComputerName port $Port"

        # Convert current time string to byte array
        $ASCIIEncoding = New-Object System.Text.ASCIIEncoding
        $Bytes = $ASCIIEncoding.GetBytes("$(Get-Date -UFormat "%Y-%m-%d %T")")

        # Send data to server
        try{
            [void]$UdpObject.Send($Bytes, $Bytes.length)
            continue
        }
        catch{
            Write-Warning $_.exception.message
        }
    }

    end {
        # Cleanup
        if($UdpObject){
            $UdpObject.Close()
        }
    }
}
