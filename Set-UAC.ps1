Function Set-UAC {
    [cmdletbinding()]
    Param(
        [ValidateSet('Never Notify','Always Notify','Sometimes Notify','Default')]
        [parameter(HelpMessage='UAC Level: Never Notify, Always Notify, Sometimes Notify, Default')]
        $Level = 'Never Notify'
    )
    
    $ErrorActionPreference = 'Stop'

    $levelList = @{
        Default = @{
            ConsentPromptBehaviorAdmin = 5
            PromptOnSecureDesktop = 1
            EnableLUA = 1
        }

        'Never Notify' = @{
            ConsentPromptBehaviorAdmin = 0
            PromptOnSecureDesktop = 0
            EnableLUA = 0
        }
        
        'Always Notify' = @{
            ConsentPromptBehaviorAdmin = 2
            PromptOnSecureDesktop = 1
            EnableLUA = 1
        }
        
        'Sometimes Notify' = @{
            ConsentPromptBehaviorAdmin = 5
            PromptOnSecureDesktop = 0
            EnableLUA = 1
        }
    }

    Write-Verbose "Setting UAC to $level"

    try{
        "EnableLUA", "ConsentPromptBehaviorAdmin", "PromptOnSecureDesktop" | ForEach-Object {
            Write-Verbose "Setting HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\$_ to $($levelList[$level].$_)"

            $params = @{
                 Path  = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
                 Name  = $_
                 Type  = 'DWord'
                 Value = $levelList[$level].$_
                 Force = $true
            }

	        Set-ItemProperty @params
        }
    }
    catch{
        Write-Warning $_.exception.message
    }
}
