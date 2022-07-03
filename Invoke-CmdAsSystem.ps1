Function Invoke-CmdAsSystem {
    [CmdletBinding()]
    param (
        [parameter(position=0)]
        [Validateset('Desktop','Core')]
        [validatescript({if($_ -eq 'core' -and -not (Get-ChildItem HKLM:\Software\Microsoft\PowerShellCore\InstalledVersions |Where-Object{(Get-ItemProperty $_.pspath) -match '(6|7)\.\d+\.\d+'})){throw "Powershell core is not detected"}else{$true}})]
        $Edition = 'Desktop'
    )

    Write-Verbose "Verifying process is elevated"
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $iselevated = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if($iselevated -ne $true){
        Write-Warning "Invoke-CmdAsSystem must be ran as administrator"
        return
    }

    $psexec = Join-Path $env:TEMP 'Psexec.exe'
    
    if(-not (Test-Path $psexec)){
        Write-Verbose "Downloading psexec.exe from live.sysinternals.com"
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest https://live.sysinternals.com/tools/psexec.exe -OutFile $psexec -UseBasicParsing
    }

    Start-Process $psexec -ArgumentList '/s','/i','cmd.exe','/accepteula','/nobanner' -WindowStyle Hidden 2>&1

}
