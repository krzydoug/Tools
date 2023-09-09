Function Get-UAC {
    [cmdletbinding()]
    Param()
    
    $ErrorActionPreference = 'Stop'

    $levelList = @{
        '511' = "Default"
        '211' = "Always Notify"
        '501' = "Sometimes Notify"
        '000' = "Never Notify"
    }

    try{
        $values = "ConsentPromptBehaviorAdmin", "PromptOnSecureDesktop", "EnableLUA" | ForEach-Object {
            Write-Verbose "Reading registry value HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\$_"
            (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name $_).$_
        }

        $levelList[-join $values]
    }
    catch{
        Write-Warning $_.exception.message
    }
}
