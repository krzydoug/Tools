Function Get-VssWriter {
    [cmdletbinding()]
    Param(
        [parameter()]
        [validateset('FRS Writer', 'Registry Writer', 'OSearch VSS Writer', 'SqlServerWriter',
                     'OSearch14 VSS Writer', 'FSRM writer', 'Shadow Copy Optimization Writer',
                     'IIS Config Writer', 'DFS Replication service writer', 'WMI Writer',
                     'Microsoft Hyper-V VSS Writer', 'DHCP Jet Writer', 'Microsoft Exchange Writer',
                     'SPSearch VSS Writer', 'COM+ REGDB Writer', 'NTDS', 'WINS Jet Writer',
                     'IIS Metabase Writer', 'System Writer', 'TermServLicensing',
                     'SPSearch4 VSS Writer', 'BITS Writer', 'ASR Writer')]
        [string[]]$Name
    )

    $output = vssadmin list writers | Out-String

    $defaultDisplaySet = 'Name','State','Error','ID'
    $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet(‘DefaultDisplayPropertySet’,[string[]]$defaultDisplaySet)
    $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)

    $pattern = "(?s)writer name: '(?<Name>.+?)'.+?Id: (?<ID>.+?)\r?\n.+?inst.+?id: (?<Instance>.+?)\r?\n.+?State: (?<State>.+?)\r?\n.+error: (?<Error>.+?)\r?\n"

    $writerlist = $output -split '(?=writer name:)'| ForEach-Object {
        if($_ -match $pattern){
            $Matches.Remove(0)
            $current = [PSCustomObject]$Matches
            $current.PSObject.TypeNames.Insert(0,'System.Net.NetworkInformation')
            $current | Add-Member MemberSet PSStandardMembers $PSStandardMembers -PassThru
        }
    }

    if($Name){
        $lookup = ($Name | ForEach-Object {[regex]::Escape($_)}) -join '|'
        $writerlist | Where-Object Name -Match $lookup
    }
    else{
        $writerlist
    }
}
