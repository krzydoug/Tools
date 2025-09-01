Function Get-WindowsVersion {
    $currentversion = Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion'

    $properties = 'CurrentMajorVersionNumber','CurrentMinorVersionNumber','CurrentBuild','UBR'

    [PSCustomObject]@{
        Version = $currentversion.ProductName
        Type    = $currentversion.InstallationType
        Edition = $currentversion.EditionId
        Build   = "{0}.{1}.{2}.{3}" -f ($properties | ForEach-Object {
            $currentversion.$_
        })
    }
}
