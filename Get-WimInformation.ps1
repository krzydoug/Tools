Function Get-WimInformation {
    <#
    .SYNOPSIS
        Extract image information from Wim files
    .DESCRIPTION
        Extract image information from Wim files and outputs easy to use objects
    .EXAMPLE
        PS C:\> Get-WimInformation -Path E:\Mount\RepairSource.wim
    .EXAMPLE
        PS C:\> 'E:\Mount\RepairSource.wim' | Get-WimInformation
    .EXAMPLE
        PS C:\> Get-ChildItem E:\Mount -Filter *.wim | Get-WimInformation
    .INPUTS
        string, fileinfo
    .NOTES
        https://forums.powershell.org/t/using-select-object-correctly/18715
        https://github.com/krzydoug/Tools/blob/master/Get-WimInformation.ps1
    #>

    [cmdletbinding()]
    Param(
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName,Position=0,HelpMessage="Enter the full path to the wim file")]
        [Alias("FullName","WimFile")]
        [string]$Path
    )

    begin{
        $dism = Get-ChildItem C:\Windows\System32 -Filter dism.exe | Select-Object -ExpandProperty FullName
    }

    process{
        switch -Regex (&$dism /Get-WimInfo /WimFile:$Path){
            
            '^Details for image : (.+$)' {
                $obj = [PSCustomObject]@{
                    WimFile     = $Matches.1
                    Index       = ''
                    Name        = ''
                    Description = ''
                    Size        = ''
                }
            }

            '^(Index|Name|Description) : (.+$)' {
                $obj.($Matches.1) = $Matches.2
            }

            'Size : (.+) bytes$' {
                $obj.Size = "{0:N2} GB" -f ([decimal]$Matches.1 / 1GB)
                [PSCustomObject]$obj
                'Index','Name','Description','Size' | ForEach-Object {$obj.$_ = ''}
            }
        }
    }
}
