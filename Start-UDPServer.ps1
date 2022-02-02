function Start-UDPServer {
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter(Mandatory = $false)]
        $Port = 10000
    )
    
    # Create a endpoint that represents the remote host from which the data was sent.
    try{
        $RemoteComputer = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
    }
    catch{
        Write-Warning $_.exception.message
        break
    }
    Write-Host "Server is waiting for connections - $($UdpObject.Client.LocalEndPoint)"
    Write-Host "Stop with CRTL + C"

    # Loop de Loop
    do {
        # Create a UDP listender on Port $Port
        try{
            $UdpObject = New-Object System.Net.Sockets.UdpClient($Port)
        }
        catch{
            Write-Warning $_.exception.message
        }

        # Return the UDP datagram that was sent by the remote host
        try{
            $ReceiveBytes = $UdpObject.Receive([ref]$RemoteComputer)
            # Close UDP connection
            $UdpObject.Close()
        }
        catch{
            Write-Warning $_.exception.message
        }

        # Convert received UDP datagram from Bytes to String
        $ASCIIEncoding = New-Object System.Text.ASCIIEncoding
        [string]$ReturnString = $ASCIIEncoding.GetString($ReceiveBytes)

        # Output information
        [PSCustomObject]@{
            LocalDateTime = $(Get-Date -UFormat "%Y-%m-%d %T")
            SourceIP      = $RemoteComputer.address.ToString()
            SourcePort    = $RemoteComputer.Port.ToString()
            Payload       = $ReturnString
        }
    } while (1)
}
