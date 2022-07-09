function Get-WindowsLicense {
    [cmdletbinding()]
    Param()
        
    $ht = [ordered]@{}

    $Slmgr = cscript.exe C:\Windows\system32\slmgr.vbs /dlv

    $Slmgr -match ':' -replace '(?<=^[\s\w]+?):','=' | ForEach-Object {
        $ht += $_ | ConvertFrom-StringData
    }

    [pscustomobject]$ht
}
