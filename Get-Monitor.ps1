Function Get-Monitor {
    Param(
        [Parameter(ValueFromPipeline)]
        [Alias("CN","Server","Computer","PC")]
        [String[]]$ComputerName = $env:COMPUTERNAME
    )

    begin {
        $CimParams = @{
            Namespace = 'root\wmi'
            ClassName = 'wmimonitorid'
        }

        $foreach = @{
            Begin = {
                $ht = [ordered]@{}
            }
            Process = {
                $value = if($_.value -is [System.Array]){[System.Text.Encoding]::ASCII.GetString($_.value)}else{$_.value}
                $ht.add($_.name,$value)
            }
            End = {
                [PSCustomObject]$ht
            }
        }

        $foreachparams = @{
            Process = {
                $_.psobject.Properties | Where-Object Name -NotMatch '^cim' | ForEach-Object @foreach
            }.GetNewClosure()
        }
    }

    process {
        foreach($computer in $ComputerName){
            $CimParams.ComputerName = $computer

            Get-CimInstance @CimParams | ForEach-Object @foreachparams
        }
    }
}
