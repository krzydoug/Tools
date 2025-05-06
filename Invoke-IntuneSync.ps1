Function Invoke-IntuneSync {
    [cmdletbinding(DefaultParameterSetName='All')]
    Param(
        [parameter(ParameterSetName='ScriptsandApps')]
        [switch]$ScriptsandApps,
        
        [parameter(ParameterSetName='Policies')]
        [switch]$Policies,

        [parameter(ParameterSetName='All')]
        [switch]$All = $true
    )

    $ErrorActionPreference = 'Stop'

    $result = "No Error"

    Write-Verbose "Invoke-IntuneSync initializing" -Verbose

    $scriptsscript = {
        try{
            $imelogdir = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
            $imelog = Join-Path $imelogdir 'IntuneManagementExtension.log'

            Write-Verbose "Initializing Intune Sync App" -Verbose

            $usererrorpattern = 'failed to get aad token|requested resource requires user auth|user check is failed'

            $lastline = Get-Content $imelog -Tail 1

            $Shell = New-Object -ComObject Shell.Application
            $Shell.open("intunemanagementextension://syncapp")
        }
        catch{
            Write-Warning $_.exception.message
            $result = 'Error'
            return
        }

        $isnew = $false

        Start-Sleep -Seconds 3

        # switch -file complained the file was in use where Get-Content worked
        $logoutput = switch (Get-Content $imelog){
            default {
                if($isnew -eq $true){
                    $_
                }
                if($_ -eq $lastline){
                    $isnew = $true
                }
            }
        }

        if($user = $logoutput -match 'After impersonation: (?<UserName>.+?)]' | Select-Object -Last 1){
            $user = $user -replace '^.+ion: |].+$'
        }

        if($usererror = $logoutput -match $usererrorpattern | Select-Object -First 1){
            Write-Warning "Error getting AAD user token for '$user'"
        }

        $proxyurl = if($proxy = $logoutput -match 'current proxy is' | Select-Object -First 1){
            $proxyurl = $proxy -replace '^.+current proxy is |\].+$'
            " to $proxyurl"
        }

        Write-Verbose "Scripts/Apps sync request sent$proxyurl" -Verbose

        if($success = $logoutput -match 'sendwebrequest.+? Succeeded' | Select-Object -First 1){
            Write-Verbose "Scripts/Apps sync request sent successfully" -Verbose
            $true
        }
        else{
            $false
        }
    }

    $policiesscript = {
        Param(
            $timeout = 30
        )

        Write-Verbose "Initializing Intune policies sync session" -Verbose 

        $state = ''
        try{
            $null = [Windows.Management.MdmSessionManager,Windows.Management,ContentType=WindowsRuntime]

            $session = [Windows.Management.MdmSessionManager]::TryCreateSession()

            $null = $session.StartAsync()
        }
        catch{
            Write-Warning $_.exception.message
            $result = 'Error'
            return
        }

        $timer = 0

        do{
            if($state -ne $session.State){
                $state = $session.State
                Write-Verbose "Sync session state: $($state)" -Verbose
            }

            Start-Sleep -Seconds 1
            $timer++
        }until($state -eq 'Completed' -or $timer -eq $timeout)

        if($session.ExtendedError){
            $false
        }
        else{
            Write-Verbose "Intune policies sync was successful" -Verbose
            $true
        }

    }

    switch ($PSCmdlet.ParameterSetName){
        'All' {
            $scriptssyncresult = . $scriptsscript
            $policysyncresult = . $policiesscript
            $scriptsync = $policysync = $true
        }
        'ScriptsandApps' {
            $scriptssyncresult = . $scriptsscript
            $scriptsync = $true
        }
        'Policies' {
            $policysyncresult = . $policiesscript
            $policysync = $true
        }
    }

   if($scriptssync -eq $false -or $policysync -eq $false){
         $result = 'Error'
    }

    [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        UserName     = $user
        ScriptSync   = $scriptsync
        PolicySync   = $policysync
        Result       = $result
    }
}
