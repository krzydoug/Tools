function Expand-ZipFile {
    <#
    .SYNOPSIS
    Expand-ZipFile is a function which extracts the contents of a zip file.

    .DESCRIPTION
    Expand-ZipFile is a function which extracts the contents of a zip file specified via the -File parameter to the
    location specified via the -Destination parameter. This function first checks to see if the .NET Framework 4.5 or higher 
    is installed and uses it for the unzipping process, otherwise COM is used.

    .PARAMETER File
    The complete path and name of the zip file in this format: C:\zipfiles\myzipfile.zip

    .PARAMETER Destination
    The destination folder to extract the contents of the zip file to. If a path is no specified,
    a directory named as the zip basename in the same directory of the zip is used/created.

    .PARAMETER ForceCOM
    Switch parameter to force the use of COM for the extraction even if the .NET Framework 4.5+ is present.

    .EXAMPLE
    Expand-ZipFile -File C:\zipfiles\AdventureWorks2012_Database.zip -Destination C:\databases\

    .EXAMPLE
    Expand-ZipFile -File C:\zipfiles\AdventureWorks2012_Database.zip -Destination C:\databases\ -ForceCOM

    .EXAMPLE
    'C:\zipfiles\AdventureWorks2012_Database.zip' | Expand-ZipFile

    .EXAMPLE
    Get-ChildItem -Path C:\zipfiles | ForEach-Object {$_.fullname | Expand-ZipFile}

    Each zipfile will have a folder named after the zip created if one doesn't already exist.

    .INPUTS
    String

    .OUTPUTS
    None

    .NOTES
    Modified: Doug Maurer
    Author:  Mike F Robbins
    Website: http://mikefrobbins.com
    Twitter: @mikefrobbins
    https://mikefrobbins.com/2013/08/15/powershell-function-to-Expand-ZipFiles-using-the-net-framework-4-5-with-fallback-to-com/
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [ValidateScript({
          If ((Test-Path -Path $_ -PathType Leaf) -and ($_ -like "*.zip")) {
              $true
          }
          else {
              Throw "$_ is not a valid zip file. Enter in 'c:\folder\file.zip' format"
          }
        })]
        [string]$File,

        [ValidateNotNullOrEmpty()]
        [string]$Destination,

        [switch]$ForceCOM
    )

    if(-not $Destination){
        $Destination = $file -replace '\..+?$'
    }
    
    If (-not $ForceCOM -and ($PSVersionTable.PSVersion.Major -ge 3) -and
       ([version](Get-ItemProperty -Path "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction SilentlyContinue).Version -gt [version]"4.5" -or
        [version](Get-ItemProperty -Path "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v4\Client" -ErrorAction SilentlyContinue).Version -gt [version]"4.5")) {

        Write-Verbose -Message "Attempting to Unzip $File to location $Destination using .NET"

        try {
            [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
            [System.IO.Compression.ZipFile]::ExtractToDirectory($File, $Destination)
        }
        catch [System.IO.IOException]{
            if($_.exception -match 'already exists'){
                Expand-ZipFile -File $file -Destination $Destination -ForceCOM -Verbose:$($PSBoundParameters.ContainsKey('Verbose'))
            }
        }
        catch {
            Write-Warning -Message $_.Exception.Message
        }
    }
    else {
        if(-not (Test-Path -LiteralPath $Destination)){
            $null = New-Item -Path $Destination -ItemType Directory
        }

        Write-Verbose -Message "Attempting to Unzip $File to location $Destination using COM"

        try {
            $shell = New-Object -ComObject Shell.Application
            $shell.Namespace($Destination).copyhere(($shell.NameSpace($file)).items(),1540)
        }
        catch {
            Write-Warning -Message $_.Exception.Message
        }
    }
}
