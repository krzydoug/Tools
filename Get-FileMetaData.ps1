Function Get-FileMetaData {
    [cmdletbinding()]
    Param
    (
        [parameter(valuefrompipeline,ValueFromPipelineByPropertyName,Position=0,Mandatory)]
        [alias('Name','Path')]
        [string[]]$FullName
    )

    begin
    {
        $shell = New-Object -ComObject Shell.Application

        $script:counter = 0

        function Get-MetaData {
            [cmdletbinding()]
            Param(
                [parameter(Position=0,Mandatory)]
                $currentfolder,

                [parameter(valuefrompipeline,Position=1,Mandatory)]
                $item
            )

            process{
                0..320 | ForEach-Object -Begin {$ht = [ordered]@{}}{
                    try
                    {
                        if($value = $currentfolder.GetDetailsOf($item,$_))
                        {
                            if($_ -gt $script:counter){$script:counter = $_}
                            $property = $currentfolder.GetDetailsOf($currentfolder.items,$_)
                            if(!$property){$property = '--Missing--'}
                            $ht.Add($property,$value)
                        }
                    }
                    catch
                    {
                        Write-Warning "Error while processing item $($item.path) : $($_.execption.message)"
                    }
                } -End {[PSCustomObject]$ht}
            }
        }

    }
    
    process
    {
        foreach($singlepath in Get-Item -LiteralPath "$fullname")
        {
            If($singlepath -is [System.IO.FileInfo])
            {
                Write-Verbose "Processing file $($singlepath.fullname)"
                $currentfolder = $shell.NameSpace($singlepath.Directory.FullName)
                $item = $currentfolder.Items()|Where-Object {$_.path -eq $singlepath.FullName}
                Get-MetaData $currentfolder $item
            }
            else
            {
                Write-Verbose "Processing folder $($singlepath.fullname)"
                $currentfolder = $shell.namespace($singlepath.fullname)

                foreach($item in $currentfolder.items())
                {
                    Get-MetaData $currentfolder $item
                }
            }

        }
    }

    end
    {
        $shell = $null
        Write-Verbose "Highest property index $($script:counter)"
    }
}
