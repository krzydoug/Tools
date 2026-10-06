# Self-elevate the script if required
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
        $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
        Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
        Exit
    }
}

function Get-LatestODT {
    [cmdletbinding()]
    Param()
    $odtdownloadpage = 'https://www.microsoft.com/en-us/download/details.aspx?id=49117'
    $fallback = 'https://download.microsoft.com/download/6c1eeb25-cf8b-41d9-8d0d-cc1dbc032140/officedeploymenttool_20326-20112.exe'

    Write-Verbose "Querying ODT download page for latest version"
    $content = Invoke-RestMethod -Uri $odtdownloadpage

    if($content -match 'downloadfile.+?\[{(?<Details>.+?officedeploymenttool_.+?)}\]'){
        $latestodt = [PSCustomObject]($matches.Details -replace ':(?=")','=' -replace ",","`n" -replace '"' | ConvertFrom-StringData)
    }

    if($latestodt.url){
        Write-Verbose "Located ODT version $($latestodt.version) filename $($latestodt.name)"
        $latestodt.url
    }
    else{
        Write-Verbose "Using fallback URL"
        $fallback
    }
}

$odt = Get-LatestODT

<#
.SYNOPSIS
    Uninstall all office 365 apps
.DESCRIPTION
    Ideal for new OEM systems preloaded with various Office installations
.EXAMPLE
    PS C:\> Uninstall-Office365

    Uninstalls all version of office 365
.NOTES
    General notes
#>

function Uninstall-Office365 {
    [CmdletBinding()]
    param (
        [switch]
        $Cleanup
    )
    
    begin {
        Push-Location $env:temp

        $odtdir = New-Item -Name ODT -ItemType Directory -Force

        Push-Location $odtdir

        @"
<Configuration>

    <!--Uninstall complete Office 365-->

    <Display Level="None" AcceptEULA="TRUE" />

    <Logging Level="Standard" Path="%temp%" />

    <Remove All="TRUE" />

</Configuration>
"@ | Set-Content remove-office365.xml -Encoding UTF8
    }
    
    process {

        $ErrorActionPreference = 'Stop'

        Write-Host Removing Office 365 junkware -ForegroundColor Cyan -NoNewline

        try{
            Invoke-WebRequest -Uri $odt -UseBasicParsing -OutFile odt.exe
        
            .\odt.exe /extract:$($odtdir.fullname) /quiet

            $params = "/configure","remove-office365.xml"
            
            $setup = Start-Process .\setup.exe -ArgumentList $params -Wait -NoNewWindow -PassThru

            While(Get-Process -Id $setup.id -ErrorAction SilentlyContinue){
                Write-Host . -ForegroundColor Cyan -NoNewline
                Start-Sleep -Seconds 1
            }

            Write-Host "Completed removing Office 365 junkware" -ForegroundColor Green
        }
        catch{
            Write-Host Error occurred: $_.exception.message -ForegroundColor Red
        }
    }
    
    end {

        if($Cleanup.IsPresent){
            Write-Host Cleaning up temporary files -ForegroundColor Cyan
            Remove-Item $odtdir -Recurse -Force -Confirm:$false
        }
    }
}

Uninstall-Office365 -Cleanup -Verbose
