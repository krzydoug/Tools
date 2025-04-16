Function Invoke-AsLocalUser {
    [cmdletbinding()]
    Param(
        [string[]]$ComputerName,
        
        [scriptblock]$ScriptBlock,

        [switch]$Elevated
    )

    $script = {
        Param($ScriptBlock,$Elevated)

        $ErrorActionPreference = 'Stop'

        Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned

        $nuget = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue |
                     Sort-Object -Property {[version]$_.version} | Select-Object -Last 1

        if(-not $nuget -or [version]$nuget.version -lt [version]2.8.5.208){
            Write-Verbose "[$env:computername] Installing NuGet 2.8.5.208"

            try{
                $null = Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.208 -Force
            }
            catch{
                Write-Warning "[$env:computername] $($_.exception.message)"
            }
        }

        if([version](Get-Module -ListAvailable -Name runasuser | Sort-Object -Property Version -Descending | Select-Object -First 1).Version -lt [version]'2.3.1'){
            Write-Verbose "[$env:computername] Installing RunAsUser module"

            try{
                Install-Module runasuser -force
            }
            catch{
                Write-Warning "[$env:computername] $($_.exception.message)"
            }
        }

        $sc = [scriptblock]::create($ScriptBlock)

        $params = @{
            Scriptblock = $sc
            CaptureOutput = $true
        }

        if($Elevated -eq $false){
            $params.Add('NonElevatedSession',$true)
        }

        $output = Invoke-AsCurrentUser @params
        
        [PSCustomObject]@{
            ComputerName = $env:computername
            Output       = $output
        }
    }

    $nuget = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue |
                    Sort-Object -Property {[version]$_.version} | Select-Object -Last 1

    if(-not $nuget -or [version]$nuget.version -lt [version]2.8.5.208){
        Write-Verbose "[$env:computername] Installing NuGet 2.8.5.208"

        try{
            $null = Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.208 -Force
        }
        catch{
            Write-Warning "[$env:computername] $($_.exception.message)"
        }
    }

    if(-not (Get-Module -ListAvailable -Name Invoke-CommandAs)){
        Write-Verbose "[$env:computername] Installing Invoke-CommandAs module"

        try{
            Install-Module -Name Invoke-CommandAs -Force
        }
        catch{
            Write-Warning "[$env:computername] $($_.exception.message)"
        }
    }

    $params = @{
        ComputerName = $ComputerName
        Scriptblock  = $script
        AsSystem     = $true
        ArgumentList = $ScriptBlock,($elevated -eq $true)
        ErrorAction  = 'SilentlyContinue'
        ErrorVariable = 'errs'
        ThrottleLimit = $ComputerName.count
    }

    Invoke-CommandAs @params

}
