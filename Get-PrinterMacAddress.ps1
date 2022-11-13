Function Get-PrinterMacAddress {
    [cmdletbinding()]
    Param(
        [parameter(ValueFromPipeline)]
        $IP,
        $Community = 'Public',
        $Port = 161,
        $Timeout = 5
    )

    begin {
        $oidlist = '1.3.6.1.2.1.2.2.1.6','.1.3.6.1.2.1.55.1.5.1.8'
        $snmpwalk = Join-Path $env:TEMP 'SNMPWalk\snmpwalk.exe'

        if(-not (Test-Path $snmpwalk)){
            $zipfile = Join-Path $env:TEMP SNMPWalk.zip
            Write-Verbose "Downloading snmpwalk.zip"
            $destination = New-Item (Split-Path $snmpwalk -Parent) -Force -ItemType Directory
            Invoke-WebRequest -UseBasicParsing 'https://dl.ezfive.com/snmpsoft-tools/SnmpWalk.zip?_gl=1*19n1cvv*_ga*MjAzNzczMjA0NS4xNjY3OTc4ODUx*_ga_BEFD2E3R5Z*MTY2Nzk3ODg1MC4xLjEuMTY2Nzk3ODg4My4yNy4wLjA.' -OutFile $zipfile
            Write-Verbose "Extracting snmpwalk.exe to $destination"
            $shell = New-Object -ComObject Shell.Application
            $shell.Namespace($destination.FullName).copyhere(($shell.NameSpace($zipfile)).items(),1540)
        }
    }

    process {
        foreach($printer in $IP){
            foreach($oid in $oidlist){
                $output = & $snmpwalk -r:$Printer -os:"$oid.0" -op:"$oid.2" -p:$Port -t:$Timeout -csv
                
                Write-Verbose "[$printer] $output"
                
                if($output -match 'timeout'){
                    return
                }

                $results = $output |
                    ConvertFrom-Csv -Header OID, Type, Value, Value1 |
                        Where-Object Value -match '^(\w\w\s){6}\s+?$'
        
                if(!$results){
                    continue
                }

                $mac = $results.Value.Trim() -replace '\s',':'

                if($mac){
                    [PSCustomObject]@{
                        IP  = $printer
                        MAC = $mac
                    }
                    break
                }
            }
        }
    }
}
