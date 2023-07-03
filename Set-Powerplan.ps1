function Set-PowerPlan{
    [cmdletbinding()]
    Param(
        [parameter(Mandatory=$true,ParameterSetName='Guid')]
        [ValidateSet("381b4222-f694-41f0-9685-ff5bb260df2e","8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c","a1841308-3541-4fab-bc81-f71556f20b4a")]
        [System.Guid]$Guid,
 
        [parameter(Mandatory=$true,ParameterSetName='Name',HelpMessage="You must enter a plan name. Possible values are High Performance, Balanced, or Power Saver")]
        [ValidateSet("Balanced","High Performance","Power Saver")]
        [System.String]$Name
 
    )
 
    begin{}
    process{
        powercfg /s "$(if($guid){$Guid}elseif($name){get-powerplan $name | select -ExpandProperty Guid})"
    }
    end{}
}
