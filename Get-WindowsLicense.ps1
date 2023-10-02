function Get-WindowsLicense {
    [cmdletbinding()]
    Param()
        
    $Slmgr = cscript.exe C:\Windows\system32\slmgr.vbs /dlv

    $obj = $Slmgr -match ':' -replace '(?<=^[\s\w]+?):','=' -join "`n" | ConvertFrom-StringData
    
    [pscustomobject]$obj
}
