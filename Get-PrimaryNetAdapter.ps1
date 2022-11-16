Function Get-PrimaryNetAdapter {
    [cmdletbinding()]
    Param(
        [switch]$IPv6
    )

    $index = Get-NetRoute -DestinationPrefix '0.0.0.0/0' |
                Sort-Object -Property {$_.InterfaceMetric + $_.RouteMetric} |
                    Select-Object -First 1 -ExpandProperty ifindex

    $adapter = Get-NetAdapter -InterfaceIndex $index
    
    $filter = if($IPv6){
        'IPv4', 'IPv6'
    }
    else{
        'IPv4'
    }

    $amparams = @{
         NotePropertyName = 'IPAddress'
         NotePropertyValue = $adapter | Get-NetIPAddress |
                                Where-Object addressfamily -in $filter |
                                    Select-Object -ExpandProperty IPAddress
    }

    $adapter | Add-Member @amparams

}
