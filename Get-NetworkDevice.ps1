Function Get-NetworkDevice {

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

    $exclude = '239.255.255.250','234.0.168.192','224.0.0.252','224.0.0.22'

    $maccache = [System.Collections.Generic.List[PSCustomobject]]::new()

    $mactable = (Invoke-RestMethod https://gitlab.com/wireshark/wireshark/-/raw/master/manuf) -replace '\t','|' |
        ConvertFrom-Csv -Delimiter '|' -Header MAC,'VendorCode','Vendor' | where mac -notmatch '^[#]'

    arp -a | ConvertFrom-String -TemplateContent $template |
        where ip -notin $exclude | Where-Object MAC -ne 'ff-ff-ff-ff-ff-ff' -OutVariable devices |
            select *,@{n='Vendor';e={Resolve-Vendor $_.MAC}}
            
}
