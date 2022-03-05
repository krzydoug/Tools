function Invoke-PowershellAsSystem {
    [CmdletBinding()]
    param (
        [parameter(position=0)]
        [Validateset('Desktop','Core')]
        [validatescript({if($_ -eq 'core' -and -not (Get-ChildItem HKLM:\Software\Microsoft\PowerShellCore\InstalledVersions |Where-Object{(Get-ItemProperty $_.pspath) -match '(6|7)\.\d+\.\d+'})){throw "Powershell core is not detected"}else{$true}})]
        $Edition = 'Desktop'
    )
 
    $psexec = 'C:\Temp\Psexec.exe'

    $exe = @{
        Desktop = 'Powershell.exe'
        Core    = 'Pwsh.exe'
    }

    if(-not (Test-Path c:\temp)){
        $null = New-Item c:\Temp -ItemType Directory
    }

    if(-not (Test-Path $psexec)){
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest https://live.sysinternals.com/tools/psexec.exe -OutFile c:\temp\psexec.exe
    }

    Start-Process -FilePath $psexec -ArgumentList "/s /i $($exe[$Edition]) /accepteula"

}
