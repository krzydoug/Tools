PowerShell.exe -ExecutionPolicy Bypass
$nuget = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue | Sort-Object -Property {[version]$_.version} | Select-Object -Last 1
if(-not $nuget -or [version]$nuget.version -lt [version]2.8.5.201){
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
}
Install-Script -name Get-WindowsAutopilotInfo -Force
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
Get-WindowsAutoPilotInfo -Online
