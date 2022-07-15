Function Get-VeeamVolumeGuid {
    [cmdletbinding()]
    Param()

    Push-Location C:\ProgramData\Veeam\Backup

    $latestlog = Get-ChildItem . -Filter VeeamGuest*.log | Sort-Object lastwritetime -Descending | Select-Object -First 1

    $pattern = '(?<=\[)(\\.+?\\)(?=].+?Mount)'

    $text = Get-Content $latestlog -Raw

    if($text -match "(?s)The following volumes should be added to the snapshot set.+?{(?<Volumes>.+?)\s{5,}}"){
        [regex]::Matches($matches.Volumes,$pattern).value
    }

    Pop-Location

}
