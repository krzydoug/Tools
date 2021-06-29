Function Get-NetworkDevice {

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    Function Resolve-Vendor {
        [cmdletbinding()]
        Param($MAC)

        $prefix = $MAC -replace '-\w{2}-\w{2}-\w{2}$' -replace '-',':'

        if($vendor = $maccache | where mac -match $prefix | select -ExpandProperty vendor)
        {
            Write-Verbose "MAC/vendor found in cache"
            $vendor
        }
        elseif($line = $mactable | where mac -match $prefix)
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

    $template = @'
      {IP*:1.2.3.4}          {MAC:a4-bb-6d-42-04-7e}     {Type:dynamic} 
      {IP*:123.254.234.210}          {MAC:11-22-8e-c1-5b-96}     {Type:static}  
'@

    $exclude = ('239','234','224' | ForEach-Object {"^$_"}) -join '|'

    $maccache = New-Object System.Collections.Generic.List[PSCustomobject]

    $mactable = (Invoke-RestMethod https://gitlab.com/wireshark/wireshark/-/raw/master/manuf) -replace '\t','|' |
        ConvertFrom-Csv -Delimiter '|' -Header MAC,'VendorCode','Vendor' | where mac -notmatch '^[#]'
    
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
