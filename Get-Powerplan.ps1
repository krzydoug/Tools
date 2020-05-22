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
        $powerplans = Powercfg /l | select -skip 3 | foreach{
            $str = $_.trim().split(':')[1]
            $G = $str.Trim().split()[0]
            $str = $str.Replace($G,"").trim()
            $A = $str -match ' \*'
            if ($a){$str = $str.Replace(" *",'')}
            $properties = @{
                Name = $str
                Guid = $G
                Active = $A
            }
            New-Object -TypeName psobject -Property $properties
        }
    }
    process{
        if($name){
            $powerplans | where name -like "*$name*"
        }
        elseif($guid){
            $powerplans | where guid -like "*$Guid*"
        }
        elseif($active){
            $powerplans | where active -eq 'true'
        }
        else{
            write-output $powerplans
        }
    }
    end{}
 
}