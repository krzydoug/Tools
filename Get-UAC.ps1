Function Get-UAC {
    [cmdletbinding()]
    Param()
    
    $ErrorActionPreference = 'Stop'

    $levelList = @{
        '511' = "Default"
        '211' = "Always Notify"
        '201' = "Always Notify"
        '501' = "Sometimes Notify"
        '000' = "Never Notify"
        '001' = "Never Notify"
        '010' = "Never Notify"
        '011' = "Never Notify"
        '500' = "Never Notify"
        '200' = "Never Notify"
        '210' = "Never Notify"
        '510' = "Never Notify"
    }

    try{
        $values = "ConsentPromptBehaviorAdmin", "PromptOnSecureDesktop", "EnableLUA" | ForEach-Object {
            $current = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name $_).$_
            Write-Verbose "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\$_  -  $current"
            $current
        }

        $levelList[-join $values]
    }
    catch{
        Write-Warning $_.exception.message
    }
}
