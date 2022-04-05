Function Get-Monitor {
    Param(
        [Parameter(ValueFromPipeline)]
        [Alias("CN","Server","Computer","PC")]
        [String[]]$ComputerName
    )

    process{

        if(!$ComputerName)
        {
            $ComputerName = $env:COMPUTERNAME
            $filter = '^cim|^PSComp'
        }

        Foreach($computer in $ComputerName)
        {
            $CimParams = @{
                Namespace = 'root\wmi'
                ClassName = 'wmimonitorid'
            }
            
            if($computer -notmatch $env:COMPUTERNAME)
            {
                $CimParams.Add('ComputerName',$computer)
                $filter = '^cim'
            }

            Get-CimInstance @CimParams | ForEach {
                $_.psobject.Properties | where name -notmatch $filter | ForEach -Begin {$ht = [ordered]@{}} -Process {
                    $value = if($_.value -is [System.Array]){[System.Text.Encoding]::ASCII.GetString($_.value)}else{$_.value}
                    $ht.add($_.name,$value)
                } -End {[PSCustomObject]$ht}
            }
        }
    }
}
