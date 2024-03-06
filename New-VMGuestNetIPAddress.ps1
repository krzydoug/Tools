Function New-VMGuestNetIPAddress{
    <#
    .Synopsis
       Set VMWare guest vm IP address
    .DESCRIPTION
       This function utilizes Invoke-VMScript to lookup a NIC by MAC address and then set the DNS, Gateway, and Static IP. 
       This is particularly useful when configuring a new static IP on a VM you don't have network access to. 
    .EXAMPLE
       $creds = Get-Credential

       $Params = @{
           VM              = 'prod-w16-app'
           MAC             = '08-00-50-FE-00-11'
           NewIP           = '192.168.1.111'
           DNSServers      = '192.168.1.20','192.168.1.21'
           Gateway         = '192.168.1.1'
           Maskbits        = '24'
           GuestCredential = $creds
       }

       New-VMGuestNetIPAddress @Params
    .INPUTS
       None
    .OUTPUTS
       [PSCustomObject]
    .NOTES
       
    #>

    [cmdletbinding()]
    Param(
        [Parameter(Mandatory,Position=0)]
        [String]$VM,
        
        [Parameter(Mandatory)]
        [string]$Mac,
        
        [Parameter(Mandatory)]
        [string]$NewIP,

        [string]$Maskbits = 24,

        [string[]]$DnsServers,
        
        [string]$Gateway,

        [Parameter(Mandatory)]
        [string]$Server,

        [Parameter(Mandatory)]
        [PSCredential]$GuestCredential
    )

    $script = @"
        `$Mac        = '$Mac'
        `$NewIP      = '$NewIP'
        `$Maskbits   = $Maskbits
        `$Gateway    = '$Gateway'
        `$DnsServers = '$($dns -join ',')'
        
        `$DnsServers = `$DNSServers -split ','

        `$nic = Get-NetAdapter | Where-Object macaddress -eq `$Mac

        if(!`$nic){
            Write-Warning "Unable to find NIC with MAC Address `$Mac"
            break
        }

        `$nicparams = @{
            IPAddress      = `$NewIP
            InterfaceIndex = `$nic.ifIndex
            PrefixLength   = `$Maskbits
            DefaultGateway = `$Gateway
        }
        
        if(`$DnsServers){
            `$dnsparams = @{
                InterfaceIndex  = `$nic.ifIndex
                ServerAddresses = `$DnsServers
            }
            try{
                Set-DnsClientServerAddress @dnsparams
            }
            catch{
            }
        }

        try{
            New-NetIPAddress @nicparams | ConvertTo-Csv
        }
        catch{
        }
"@

    Invoke-VMScript -VM $VM -Server $Server -GuestCredential $GuestCredential -ScriptText $script |
        Select-Object -ExpandProperty scriptoutput | ConvertFrom-Csv
}
