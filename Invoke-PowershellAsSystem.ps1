function Invoke-PowershellAsSystem {
    [CmdletBinding()]
    param (
        [parameter(position=0)]
        [Validateset('Desktop','Core')]
        [validatescript({if($_ -eq 'core' -and -not (Get-ChildItem HKLM:\Software\Microsoft\PowerShellCore\InstalledVersions |Where-Object{(Get-ItemProperty $_.pspath) -match '(6|7)\.\d+\.\d+'})){throw "Powershell core is not detected"}else{$true}})]
        $Edition = 'Desktop'
    )

    $psexec = Join-Path $env:TEMP 'Psexec.exe'

    $exe = @{
        Desktop = 'Powershell.exe'
        Core    = 'Pwsh.exe'
    }

    if(-not (Test-Path $psexec)){
        Write-Verbose "Downloading psexec.exe from live.sysinternals.com"
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest https://live.sysinternals.com/tools/psexec.exe -OutFile $psexec -UseBasicParsing
    }

    Start-Process $psexec -ArgumentList '/s','/i',$exe[$Edition],'/accepteula','/nobanner' -WindowStyle -Verb runas Hidden 2>&1

}
