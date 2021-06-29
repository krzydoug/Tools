Function Get-NetworkDevice {

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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

    $exclude = ('239','234','224' | ForEach-Object {"^$_"}) -join '|'

    $maccache = New-Object System.Collections.Generic.List[PSCustomobject]

    $mactable = (Invoke-RestMethod https://gitlab.com/wireshark/wireshark/-/raw/master/manuf) -replace '\t','|' |
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
