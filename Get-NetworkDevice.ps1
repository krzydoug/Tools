Function Get-NetworkDevice {
    [cmdletbinding()]
    Param()
    
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    'Get-PingableHost', 'Get-PrimaryNetAdapter', 'Get-Subnet' | ForEach-Object {
        if(-not (Test-Path Function:\$_)){
            Write-Verbose "Retrieving function: $_"
            Invoke-RestMethod "https://raw.githubusercontent.com/krzydoug/Tools/master/$_.ps1" | Invoke-Expression
        }
    }
    
    Function Resolve-Vendor {
        [cmdletbinding()]
        Param($MAC)

        $prefix = $MAC -replace '-\w{2}-\w{2}-\w{2}$' -replace '-',':'

        if($vendor = $maccache | Where-Object mac -match $prefix | Select-Object -ExpandProperty vendor)
        {
            Write-Verbose "MAC/vendor found in cache"
            $vendor
        }
        elseif($line = $mactable | Where-Object mac -match $prefix)
        {
            if(!$line.vendor){
                Write-Verbose "vendor is null so replacing with vendorcode"
                $line.vendor = $line.vendorcode
                }
            Write-Verbose "adding $($line.mac)/$($line.vendor) to cache"
            $maccache.Add($line)
            $line.vendor
        }
        else
        {
            "Unknown"
        }
    }

    try{
        $subnet = Get-PrimaryNetAdapter | Get-NetIPAddress | Get-Subnet
        try{
            $null = $subnet.HostAddresses | Get-PingableHost
        }
        catch{
            Write-Warning "Error pinging address range $($subnet.Range)"
        }
    }
    catch{
        Write-Warning "Unable to retrieve subnet host addresses"
    }
    
    $exclude = ('239','234','224' | ForEach-Object {"^$_"}) -join '|'

    $maccache = New-Object System.Collections.Generic.List[PSCustomobject]

    $mactable = (Invoke-RestMethod https://www.wireshark.org/download/automated/data/manuf) -replace '\t','|' |
        ConvertFrom-Csv -Delimiter '|' -Header MAC,'VendorCode','Vendor' | Where-Object mac -notmatch '^[#]'
    
    $arpcache = switch -Regex (arp -a){
        '^\s{1,}\d' {
            , -split $_ | ForEach-Object {
                [PSCustomObject]@{
                    IP   = $_[0]
                    MAC  = $_[1]
                    Type = $_[2]
                }
            }
        }
    }

    $arpcache | Where-Object ip -notmatch $exclude |
        Where-Object MAC -ne 'ff-ff-ff-ff-ff-ff' -OutVariable devices |
            Select-Object *,@{n='Vendor';e={Resolve-Vendor $_.MAC}}
            
}
