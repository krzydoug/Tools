Function Get-WindowsBuild {

    $properties = 'CurrentMajorVersionNumber','CurrentMinorVersionNumber','CurrentBuild','UBR'

    "{0}.{1}.{2}.{3}" -f ($properties | ForEach-Object {
        Get-ItemPropertyValue -Path 'Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion' -Name $_
    })

}
