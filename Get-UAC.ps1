Function Get-UAC {
    [cmdletbinding()]
    Param()
    
    $ErrorActionPreference = 'Stop'

    $levelList = @{
        '51' = "Default"
        '21' = "Always Notify"
        '50' = "Sometimes Notify"
        '00' = "Never Notify"
    }

    try{
        $values = "ConsentPromptBehaviorAdmin", "PromptOnSecureDesktop", "EnableLUA" | ForEach-Object {
            $current = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name $_).$_
            Write-Verbose "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\$_  -  $current"
            $current
        }

        $levelList[-join $values[0,1]]
    }
    catch{
        Write-Warning $_.exception.message
    }
}
