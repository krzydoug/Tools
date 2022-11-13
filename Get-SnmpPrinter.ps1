Function Get-SnmpPrinter {
    [cmdletbinding()]
    Param(
        [parameter(ValueFromPipeline,Mandatory,HelpMessage='Enter the printer IP',Position=0)]
        [string[]]$IP
    )

    begin {
        $TypeName = 'Snmp.Printer'
        $defaultDisplaySet = 'IP', 'Hostname', 'Model', 'SerialNumber'
        Update-TypeData -TypeName $TypeName -DefaultDisplayPropertySet $defaultDisplaySet -Force

        $snmpwalk = Join-Path $env:TEMP 'SNMPWalk\snmpwalk.exe'

        if(-not (Test-Path $snmpwalk)){
            Write-Verbose "Downloading snmpwalk.zip"
            $zipfile = Join-Path $env:TEMP SNMPWalk.zip
            $destination = New-Item (Split-Path $snmpwalk -Parent) -Force -ItemType Directory
            Invoke-WebRequest -UseBasicParsing 'https://dl.ezfive.com/snmpsoft-tools/SnmpWalk.zip?_gl=1*19n1cvv*_ga*MjAzNzczMjA0NS4xNjY3OTc4ODUx*_ga_BEFD2E3R5Z*MTY2Nzk3ODg1MC4xLjEuMTY2Nzk3ODg4My4yNy4wLjA.' -OutFile $zipfile
            Write-Verbose "Extracting snmpwalk.exe to $destination"
            $shell = New-Object -ComObject Shell.Application
            $shell.Namespace($destination.FullName).copyhere(($shell.NameSpace($zipfile)).items(),1540)
        }

        $data = @'
            Property,start,end
            Serial,.1.3.6.1.2.1.43.5.1.1.17,.1.3.6.1.2.1.43.5.1.1.17.1
            Name,.1.3.6.1.2.1.1.5,.1.3.6.1.2.1.1.5.2
            Model,.1.3.6.1.2.1.25.3.2.1.3,.1.3.6.1.2.1.25.3.2.1.3.1
            IPP,.1.3.6.1.2.1.43.14.1.1.9.1.0,.1.3.6.1.2.1.43.14.1.1.9.1.1
            IPPS,.1.3.6.1.2.1.43.14.1.1.9.1.1,.1.3.6.1.2.1.43.14.1.1.9.1.2
            bonjourname,.1.3.6.1.4.1.11.2.4.3.5.44,.1.3.6.1.4.1.11.2.4.3.5.44.0
            bonjourdomain,.1.3.6.1.4.1.11.2.4.3.5.46,.1.3.6.1.4.1.11.2.4.3.5.46.0
            trays,.1.3.6.1.2.1.43.8.2.1.13.1.0,.1.3.6.1.2.1.43.8.2.1.13.1.2
            ports,.1.3.6.1.2.1.6.13.1.3.0.0.0.0.1,.1.3.6.1.2.1.6.13.1.3.0.0.0.1
'@ | ConvertFrom-Csv

        Invoke-RestMethod -Uri https://raw.githubusercontent.com/krzydoug/Tools/master/Get-PrinterMacAddress.ps1 -UseBasicParsing | Invoke-Expression

    }

    process {
        foreach($printer in $IP){
            Write-Verbose "Querying IP $IP"

            $obj = Get-PrinterMacAddress -IP $printer

            if(-not $obj){
                continue
            }

            foreach($line in $data){
                $value = & $snmpwalk -r:$printer -os:$line.start -op:$line.end -csv |
                    ConvertFrom-Csv -Header OID, Type, Value, Value1 | Select-Object -ExpandProperty value
                New-Variable -Name $line.Property -Value $value
            }

            if($null -eq $name){
                $result = (& $snmpwalk -r:$printer -os:.1.3.6.1.4.1.11.2.4.3.1.12.1.2.36 -op:.1.3.6.1.4.1.11.2.4.3.1.12.1.2.48) -match 'host'

                $name = if([string]$result -match 'host\s?name:?\s+(\S+)'){
                    $Matches.1
                }
            }

            $uptime = & $snmpwalk -r:$printer -os:.1.3.6.1.2.1.1.3 -op:.1.3.6.1.2.1.1.3.1 -csv |
                          ConvertFrom-Csv -Header OID, Type, Value, Value1 | Select-Object value, value1

            $uptime = "{0} {1}" -f $uptime.value,$uptime.value1

            $obj = $obj | Select-Object -Property *,@{n='HostName';e={$name}},
                                                    @{n='SerialNumber';e={$serial}},
                                                    @{n='Model';e={$model}},
                                                    @{n='UpTime';e={$uptime}},
                                                    @{n='InternetPrintPort';e={$ipp -replace '^.+='}},
                                                    @{n='Https InternetPrintPort';e={$ipps -replace '^.+='}},
                                                    @{n='BonjourServiceName';e={$bonjourname}},
                                                    @{n='BonjourDomainName';e={$bonjourdomain}},
                                                    @{n='Trays';e={$trays -join "`n"}},
                                                    @{n='OpenPorts';e={if($ports = $ports | Get-Unique){$ports -join ", "}else{"N/A"}}}

            $obj.psobject.TypeNames.Insert(0,$TypeName)
            $obj

            Remove-Variable -Name name,value,model,bonjourname,bonjourdomain,serial,ipp,ipps,trays,ports,uptime -ErrorAction SilentlyContinue
        }
    }
}
