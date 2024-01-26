Function Send-WakeOnLan {
    [cmdletbinding(DefaultParameterSetName="MAC")]
    Param(
        [parameter(ParameterSetName="MAC",Mandatory,Position=0)]
        $MAC,
        [parameter(ParameterSetName="Name",Mandatory,Position=0)]
        $ComputerName,
        [parameter(ParameterSetName="IP",Mandatory,Position=0)]
        $IP
    )
    
    begin {
        Function Get-MacFromIP {
            [cmdletbinding()]
            Param($IP)
            
            Write-Verbose "Resolving IP to MAC address"

            switch -Regex (arp -a){
                "^\s+$([regex]::Escape($IP))" {
                    (-split $_)[1]
                }
            }

        }

        Function Get-IpFromHostName {
            [cmdletbinding()]
            Param($HostName)
            
            Write-Verbose "Resolving Hostname to IP address"

            try{
                [system.net.dns]::GetHostEntry($HostName).addresslist.ipaddresstostring.where{$_ -notmatch ':'}
            }
            catch{}
        }
    }

    process {
        if($ComputerName){
            $IP = Get-IpFromHostName -HostName $ComputerName

            if(!$IP){
                Write-Warning "Unable to resolve $ComputerName to an IP"
                continue
            }
        }

        if($IP){
            $MAC = Get-MacFromIP -IP $IP

            if(!$MAC){
                Write-Warning "No entry for $IP found in ARP table"
                continue
            }
        }

        $MacByteArray = $MAC -split "[:-]" | ForEach-Object { [Byte] "0x$_"}
        [Byte[]] $MagicPacket = (,0xFF * 6) + ($MacByteArray  * 16)

        try{
            Write-Verbose "Sending WOL packet to MAC $MAC"
            $UdpClient = New-Object System.Net.Sockets.UdpClient
            $UdpClient.Connect(([System.Net.IPAddress]::Broadcast),7)
            $null = $UdpClient.Send($MagicPacket,$MagicPacket.Length)
            $UdpClient.Close()
        }
        catch{
            Write-Warning "Error sending WOL packet"
        }

    }

}
