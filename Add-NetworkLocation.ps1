function Add-NetworkLocation
<#
    Author: 
        Tom White, 2015.
        
    Link: 
        https://gallery.technet.microsoft.com/scriptcenter/Add-NetworkLocation-734ab70a # dead now

    Description:
        Creates a network location shortcut using the specified path, name and target.
        Replicates the behaviour of the 'Add Network Location' wizard, creating a special folder as opposed to a simple shortcut.

        Returns $true on success and $false on failure.

        Use -Verbose for extended output.

    Example:

        Add-NetworkLocation -networkLocationPath "$env:APPDATA\Microsoft\Windows\Network Shortcuts" -networkLocationName "Network Location" -networkLocationTarget "\\server\share" -Verbose
#>
{
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory=$true)][string]$networkLocationPath,
        [Parameter(Mandatory=$true)][string]$networkLocationName ,
        [Parameter(Mandatory=$true)][string]$networkLocationTarget
    )
    Begin
    {
        Write-Verbose -Message "Network location path: `"$networkLocationPath`"."
        Write-Verbose -Message "Network location name: `"$networkLocationName`"."
        Write-Verbose -Message "Network location target: `"$networkLocationTarget`"."
        Set-Variable -Name desktopIniContent -Option ReadOnly -value ([string]"[.ShellClassInfo]`r`nCLSID2={0AFACED1-E828-11D1-9187-B532F1E9575D}`r`nFlags=2")
    }
    Process
    {
        Write-Verbose -Message "Checking that `"$networkLocationPath`" is a valid directory..."
        if(Test-Path -Path $networkLocationPath -PathType Container)
        {
            try
            {
                Write-Verbose -Message "Creating `"$networkLocationPath\$networkLocationName`"."
                [void]$(New-Item -Path "$networkLocationPath\$networkLocationName" -ItemType Directory -ErrorAction Stop)
                Write-Verbose -Message "Setting system attribute on `"$networkLocationPath\$networkLocationName`"."
                Set-ItemProperty -Path "$networkLocationPath\$networkLocationName" -Name Attributes -Value ([System.IO.FileAttributes]::System) -ErrorAction Stop
            }
            catch [Exception]
            {
                Write-Error -Message "Cannot create or set attributes on `"$networkLocationPath\$networkLocationName`". Check your access and/or permissions."
                return $false
            }
        }
        else
        {
            Write-Error -Message "`"$networkLocationPath`" is not a valid directory path."
            return $false
        }
        try
        {
            Write-Verbose -Message "Creating `"$networkLocationPath\$networkLocationName\desktop.ini`"."
            [object]$desktopIni = New-Item -Path "$networkLocationPath\$networkLocationName\desktop.ini" -ItemType File
            Write-Verbose -Message "Writing to `"$($desktopIni.FullName)`"."
            Add-Content -Path $desktopIni.FullName -Value $desktopIniContent
        }
        catch [Exception]
        {
            Write-Error -Message "Error while creating or writing to `"$networkLocationPath\$networkLocationName\desktop.ini`". Check your access and/or permissions."
            return $false
        }
        try
        {
            $WshShell = New-Object -ComObject WScript.Shell
            Write-Verbose -Message "Creating shortcut to `"$networkLocationTarget`" at `"$networkLocationPath\$networkLocationName\target.lnk`"."
            $Shortcut = $WshShell.CreateShortcut("$networkLocationPath\$networkLocationName\target.lnk")
            $Shortcut.TargetPath = $networkLocationTarget
            $Shortcut.Description = "Created $(Get-Date -Format s) by $($MyInvocation.MyCommand)."
            $Shortcut.Save()
        }
        catch [Exception]
        {
            Write-Error -Message "Error while creating shortcut @ `"$networkLocationPath\$networkLocationName\target.lnk`". Check your access and permissions."
            return $false
        }
        return $true
    }
}
