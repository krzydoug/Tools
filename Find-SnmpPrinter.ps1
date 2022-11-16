Function Find-SnmpPrinter {
    [cmdletbinding()]
    Param(
        [parameter(ValueFromPipeline)]
        [string[]]$IP,

        $ThrottleLimit = 300
    )

    begin {
        $ErrorActionPreference = 'Stop'

        $snmpwalk = Join-Path $env:TEMP 'SNMPWalk\snmpwalk.exe'

        if(-not (Test-Path $snmpwalk)){
            Write-Verbose "Downloading snmpwalk.zip"

            $zipfile = Join-Path $env:TEMP SNMPWalk.zip
            $destination = New-Item (Split-Path $snmpwalk -Parent) -Force -ItemType Directory

            Invoke-WebRequest -UseBasicParsing 'https://dl.ezfive.com/snmpsoft-tools/SnmpWalk.zip?_gl=1*19n1cvv*_ga*MjAzNzczMjA0NS4xNjY3OTc4ODUx*_ga_BEFD2E3R5Z*MTY2Nzk3ODg1MC4xLjEuMTY2Nzk3ODg4My4yNy4wLjA.' -OutFile $zipfile

            if(-not (Test-Path $zipfile)){
                Write-Warning "Error downloading snmpwalk.zip"
                break
            }

            Write-Verbose "Extracting snmpwalk.exe to $destination"

            $shell = New-Object -ComObject Shell.Application
            $shell.Namespace($destination.FullName).copyhere(($shell.NameSpace($zipfile)).items(),1540)
        }
        
        $functions = 'PrinterMacAddress', 'SnmpPrinter' | ForEach-Object {
            Invoke-RestMethod -Uri https://raw.githubusercontent.com/krzydoug/Tools/master/Get-$_.ps1 -UseBasicParsing
        }

        if($PSEdition -eq 'Desktop'){
            $scriptblock = {
                Param($IP,$functions,$Verbose)

                . $([scriptblock]::Create($functions))

                Get-SnmpPrinter $IP -Verbose:$Verbose
            }
            
            $pool = [runspacefactory]::CreateRunspacePool(1, $ThrottleLimit, $Host)
            $pool.ApartmentState = "MTA"
            $pool.Open()
            
            $runspacelist = New-Object System.Collections.Generic.List[hashtable]
        }
    }

    process {
        if(-not $IP){
            Write-Verbose "No IP(s) provided, retrieving local subnet(s)"

            foreach($function in 'Get-Subnet','Get-PrimaryNetAdapter'){
                if(-not (Test-Path Function:\$function)){
                    try{
                        Invoke-RestMethod https://raw.githubusercontent.com/krzydoug/Tools/master/$function.ps1 -UseBasicParsing | Invoke-Expression
                    }
                    catch{
                        Write-Warning "Error downloading $function.ps1"
                        break
                    }
                }
            }

            $primaryip = Get-PrimaryNetAdapter

            if(-not $primaryip){
                Write-Warning "Unable to determine primary IP address"
                break
            }

            $IP = (Get-Subnet -IP $primaryip.ipaddress -MaskBits $primaryip.prefixlength).hostaddresses
        }

        if($PSEdition -eq 'Core'){
            $IP | ForEach-Object -Parallel {

                . $([scriptblock]::Create($using:functions))

                Get-SnmpPrinter $_
            } -ThrottleLimit $ThrottleLimit
        }
        else{
            $IP | Foreach-Object {
                $runspace = [PowerShell]::Create()
                $null = $runspace.AddScript($scriptblock).AddArgument($_).AddArgument($functions).AddArgument($PSBoundParameters.ContainsKey('Verbose'))
                $runspace.RunspacePool = $pool
                $runspacelist.Add(@{Pipe = $runspace; Status = $runspace.BeginInvoke()})
            }

            if($runspacelist[0].Status.IsCompleted){
                $runspacelist[0].Pipe.EndInvoke($runspacelist[0].Status)
                $runspacelist[0].Pipe.Dispose()
                $runspacelist.RemoveAt(0)
            }
        }
    }

    end {
        while($runspacelist){
            if($runspacelist[0].Status.IsCompleted){
                $runspacelist[0].Pipe.EndInvoke($runspacelist[0].Status)
                $runspacelist[0].Pipe.Dispose()
                $runspacelist.RemoveAt(0)
            }
            else{
                Start-Sleep -Milliseconds 200
            }
        }
    }
}
