Function Get-LoggedInUser {
    [cmdletbinding()]
    Param(
        [parameter(Position=0,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string[]]
        $ComputerName,

        [parameter(Position=1)]
        [pscredential]
        $Credential
    )

    begin {
        $scriptblock = {
            $params = @{
                Path        = 'Registry::HKEY_USERS\'
                ErrorAction = 'SilentlyContinue'
                Exclude     = ".default"
            }

            $userlist = Get-Childitem @params |
                ForEach-Object { Get-ChildItem Registry::$_ } |
                    Where-Object Name -like "*Volatile Environment"

            $userlist | ForEach-Object {
                $ht = [ordered]@{
                    ComputerName = $env:COMPUTERNAME
                }

                foreach($prop in $_.property){
                    $ht.$prop = $_.GetValue($prop)
                }

                $ht.USERSID = $_.psparentpath -replace '.+\\'
                $ht.REGPATH = $_.psparentpath

                [PSCUstomObject]$ht
            }
        }

        $params = @{
            Scriptblock   = $scriptblock
            ErrorAction   = 'SilentlyContinue'
            ErrorVariable = '+errs'
        }

        if($Credential){
            $params.Credential = $Credential
        }
    }

    process{
        if($ComputerName){
            $params.computername = $ComputerName
        }

        Invoke-Command @params | Select-Object * -ExcludeProperty PScomputername,runspaceid
    }
}
