Function Invoke-CmdAsSystem {

    if(-not (Test-Path c:\temp)){
        $null = New-Item c:\Temp -ItemType Directory
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    Invoke-WebRequest https://live.sysinternals.com/tools/psexec.exe -OutFile c:\temp\psexec.exe

    C:\temp\psexec.exe /s /i cmd.exe /accepteula

}
