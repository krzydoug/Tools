function Get-TaskbarPinnedItem {
    [cmdletbinding()]
    Param()
    
    $Shell = New-Object -ComObject WScript.Shell

    [Array]$itm = Get-ItemPropertyValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband\' -Name 'FavoritesResolve'
    $result = -join $(foreach($asciiChar in $itm){[Char]$asciiChar| Where-Object{$_}})

    $pattern = [regex]::Escape($env:USERPROFILE) + '.+?\.\w{2,3}'
    $matches = [regex]::Matches($result, $pattern)

    $matches.Value | ForEach-Object {
        $Shell.CreateShortcut($_)
    }

    $shell = $null
}
