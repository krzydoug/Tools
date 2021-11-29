Function Get-FolderSize {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory,Position=0)]
        [ValidateScript({
            if(Test-Path $_){
                $true
            }
            else{
                Throw "Invalid path: $_"
            }
            if((Get-Item $_).PSIsContainer){
                $true
            }
            else{
                Throw "$_ is not a directory."
            }
        })]
        [String]$Path
    )

    # Get the total directory number and file counts
    # the '/L' [for List] tells robocopy to not do anything, just list what it _would_ do
    #    /E :: copy subdirectories, including Empty ones.
    #    /L :: List only - don't copy, timestamp or delete any files.
    #    /NFL :: No File List - don't log file names.
    #    /NDL :: No Directory List - don't log directory names.
    #    /NP :: No Progress - don't display percentage copied.

    $RC_Results = robocopy $Path 'NULL' /L /E /NP /NFL /NDL
   
    $dirs,$files,$size = switch -Regex ($RC_Results | Select-Object -Last 6){
        '(Ended|Times)\s:\s(.+)' {break}
        ':' {
            (-split ($_  -replace '(?<=\d)\s(?=[bkmg])|(?<=\s):(?=\s)'))[1]
        }
    }
   
    [PSCustomObject] @{
        DirPath   = $Path
        DirCount  = "{0}" -f $dirs
        FileCount = "{0}" -f $files
        TotalSize = "{0}" -f $(if($size -match '\w$'){
            $size -replace '\w$',"$(($matches.0).toupper())B"
        })
    }
}
