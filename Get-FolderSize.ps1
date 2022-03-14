Function Get-FolderSize {
    [cmdletbinding()]
    [OutputType([PSCustomObject])]
    Param(
        [Parameter(Mandatory,Position=0,ValueFromPipelineByPropertyName)]
        [ValidateScript({
            if(Test-Path -LiteralPath $_){
                $true
            }
            else{
                Throw "Invalid path: $_"
            }
            if((Get-Item -LiteralPath $_).PSIsContainer){
                $true
            }
            else{
                Throw "$_ is not a directory."
            }
        })]
        [String]$FullName
    )

    begin{
        # Get the total directory number and file counts
        # the '/L' [for List] tells robocopy to not do anything, just list what it _would_ do
        #    /E :: copy subdirectories, including Empty ones.
        #    /L :: List only - don't copy, timestamp or delete any files.
        #    /NFL :: No File List - don't log file names.
        #    /NDL :: No Directory List - don't log directory names.
        #    /NP :: No Progress - don't display percentage copied.
        
        Function Get-FriendlySize {
            [cmdletbinding()]
            Param($bytes)

            switch($bytes){
                {$_ -gt 1PB}{"{0:N2} PB" -f ($_ / 1PB);break}
                {$_ -gt 1TB}{"{0:N2} TB" -f ($_ / 1TB);break}
                {$_ -gt 1GB}{"{0:N2} GB" -f ($_ / 1GB);break}
                {$_ -gt 1MB}{"{0:N2} MB" -f ($_ / 1MB);break}
                {$_ -gt 1KB}{"{0:N2} KB" -f ($_ / 1KB);break}
                default {"{0:N2} Bytes" -f $_}
            }
        }
    }

    process {
        
        $RC_Results = robocopy $FullName.TrimEnd('\') 'NULL' /L /E /NP /NFL /NDL
   
        $dirs,$files,$size = switch -Regex ($RC_Results | Select-Object -Last 6){
            '(Ended|Times)\s:\s(.+)' {break}
            ':' {
                (-split ($_  -replace '(?<=\d)\s(?=[bkmg])|(?<=\s):(?=\s)'))[1]
            }
        }
        
        [PSCustomObject] @{
            DirCount  = "{0}" -f $dirs
            FileCount = "{0}" -f $files
            TotalSize = Get-FriendlySize $($(if($size -match '\D$'){
                $size -replace '\D$',"$($matches.0)B" | Invoke-Expression
            }
            else{
                $size
            }) -as [decimal])
            DirPath   = $FullName
        }
    }
}
