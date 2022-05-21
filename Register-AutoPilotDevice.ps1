Clear-Host

Write-Host @'

      * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
      *                                                                                             *
      *              Autopilot Device Registration - Software Consulting Services, LLC              *
      *                                                                                             *
      * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
   
'@ -ForeGroundColor Cyan

Write-Host Initializing... -ForeGroundColor Green
Write-Host Setting execution policy -ForeGroundColor Green
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned

Function ChoicePrompt {
    Param(
        $Type,
        $Choices = [System.Management.Automation.Host.ChoiceDescription[]] @("&Yes", "&No"),
        $Default = 1
    )
    $Title = "$Type assignment"
    $Prompt = "Do you want to assign a {0}?" -f $type

    [bool]($host.UI.PromptForChoice($Title, $Prompt, $Choices, $Default) -xor 1)
}

$params = @{
    Online     = $true
    AddToGroup = "CloudConfiguration"
    Assign     = $true
}

if(ChoicePrompt User){
    $email = Read-Host -Prompt "Enter the user email address"
    if($email){
        $params['AssignedUser'] = $email
    }
}

if(ChoicePrompt 'Device Name'){
    $device = Read-Host -Prompt "Enter the device name"
    if($device){
        $params['AssignedComputerName'] = $device
    }
}

$nuget = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue |
             Sort-Object -Property {[version]$_.version} | Select-Object -Last 1

if(-not $nuget -or [version]$nuget.version -lt [version]2.8.5.201){
    Write-Host "Installing NuGet 2.8.5.201" -ForeGroundColor Green
    $null = Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
}

Write-Host "Installing Intune powershell module" -ForeGroundColor Green
Install-Script -name Get-WindowsAutopilotInfo -Force -Scope CurrentUser
#Install-Module WindowsAutoPilotIntune -Scope CurrentUser -Force

try{
    Get-WindowsAutoPilotInfo @params
    Write-Host "Device has been added to AutoPilot.`nPlease close the console window and continue with sign in/enrollment." -ForeGroundColor Green
    Pause
    Exit 0
}
catch{
    Write-Warning $_.Exception.Message
    Exit 1
}
