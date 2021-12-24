function Get-PowerPlan{
    [cmdletbinding(DefaultParameterSetName='All')]
    Param(
        [parameter(Position=0,ParameterSetName='Guid')]
        [ValidateSet("381b4222-f694-41f0-9685-ff5bb260df2e","8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c","a1841308-3541-4fab-bc81-f71556f20b4a")]
        [System.Guid]$Guid,
 
        [parameter(position=0,ParameterSetName='Name')]
        [ValidateSet("Balanced","High Performance","Power Saver")]
        [System.String]$Name,

        [parameter(position=0,ParameterSetName='Active')]
        [switch]$Active
    )
   
    begin{
        $powerplans = switch -Regex (Powercfg /l){
            ':\s(\S+)\s+\((.+)\)\s?(\*?)' {
                [PSCustomObject]@{
                    Name   = $matches[2]
                    Guid   = $matches[1]
                    Active = [bool]$matches[3]
                }
            }
        }
    }

    process{
        if($match = $PSBoundParameters.Keys -match '(name|guid|active)'){
            Write-Verbose "$match -eq $($PSBoundParameters.$($match))"
            $powerplans | Where-Object $match[0] -eq $PSBoundParameters.$($match)
        }
        else{
            $powerplans
        }
    }

    end{}
 
}
