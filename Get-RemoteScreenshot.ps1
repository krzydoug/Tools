function Get-RemoteScreenshot {
<#

.SYNOPSIS
	This script contains the required functions/task template to create screenshot of the remote PC

.DESCRIPTION
	The script should be called directly or dot sourced to load the Get-RemoteScreenshot function into the function PS drive.
	
.PARAMETER ComputerName
	Specifies the remote computer to try and capture screenshot from. This parameter is required.

.PARAMETER Path
	Optional parameter specifying the path to save the collected screenshots in. $env:temp is default.

.NOTES
	This script has been tested on windows 7 and windows 10. It has not been tested against Terminal Server.
	It creates scheduled task targeting "users" group, tries to run it, then tries to delete it.
	Finally, it will attempt to move the screenshot from the remote C:\temp to the local path.
	Naturally, the script works best with a logged in user. From my testing it will work on RDP session as long as it's not minimized.
	

.EXAMPLE
'PC1','PC2','PC3' | Get-RemoteScreenshot -Path c:\temp -verbose
Description
-----------
This command will attempt to retrieve screenshot from PC1, PC2, and PC3 and save them in calling host c:\temp directory.

.EXAMPLE
get-adcomputer -filter "name -like '*wks*' | select -name | Get-RemoteScreenshot
Description
-----------
This command will query AD for any computer named *wks*, attempt to retrieve screenshots from them, and save them in calling host $env:temp directory.

.LINK
	https://github.com/krzydoug/Tools/blob/master/Get-RemoteScreenshot.ps1
#>


    #Requires -RunAsAdministrator

    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$true)]
        [Alias("PC","Name","CN","Hostname")]
        [string[]] $ComputerName,

        [Parameter()]             
        [ValidateScript({Test-Path -Path $_ })]
        [string] $Path
    )

    begin
    {

        $ErrorActionPreference = 'stop'

        Write-Verbose -Message "Defining functions"

        Function Take-SShot {
            Param($pc)

            $ErrorActionPreference = 'stop'

            # -------------------------------  Optional - modify this for your environment  -------------------------------

            # temporary location on remote PC for script
            $localscript = "c:\Temp\Take-Screenshot.ps1"

            # -------------------------------  Don't modify anything past this line  -------------------------------

            $remotescript = @'
                Function Take-Screenshot {
                [CmdletBinding()] Param(
           
                        [ValidateScript({Test-Path -Path $_ })]
                        [string] $Path
  
                        )
    
                    #Define helper function that generates and saves screenshot
                    Function GenScreenshot {
                       $ScreenBounds = [Windows.Forms.SystemInformation]::VirtualScreen
                       $ScreenshotObject = New-Object Drawing.Bitmap $ScreenBounds.Width, $ScreenBounds.Height
                       $DrawingGraphics = [Drawing.Graphics]::FromImage($ScreenshotObject)
                       $DrawingGraphics.CopyFromScreen( $ScreenBounds.Location, [Drawing.Point]::Empty, $ScreenBounds.Size)
                       $DrawingGraphics.Dispose()
                       $ScreenshotObject.Save($FilePath)
                       $ScreenshotObject.Dispose()
                    }

                    Try {
            
                        #load required assembly
                        Add-Type -Assembly System.Windows.Forms            

                            #get the current time and build the filename from it
                            $Time = (Get-Date)
                
                            [string]$FileName = "$($env:computername)-$($env:username)-$($Time.Month)"
                            $FileName += '-'
                            $FileName += "$($Time.Day)" 
                            $FileName += '-'
                            $FileName += "$($Time.Year)"
                            $FileName += '-'
                            $FileName += "$($Time.Hour)"
                            $FileName += '-'
                            $FileName += "$($Time.Minute)"
                            $FileName += '-'
                            $FileName += "$($Time.Second)"
                            $FileName += '.png'

                            #use join-path to add path to filename
                            [string] $FilePath = (Join-Path $path $FileName)

                            #run screenshot function
                            GenScreenshot
                
                            Write-Verbose "Saved screenshot to $FilePath. Sleeping for $Interval seconds"
		
                    }

                   Catch {Write-Warning "$Error[0].ToString() + $Error[0].InvocationInfo.PositionMessage"}

            }

            Take-Screenshot -path C:\Temp
'@
            
            # scheduled task template
            $task = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
    <RegistrationInfo>
    <Date>2020-06-15T11:47:39.2496369</Date>
    <URI>\Remote SShot</URI>
    <SecurityDescriptor></SecurityDescriptor>
    </RegistrationInfo>
    <Triggers />
    <Principals>
    <Principal id="Author">
        <GroupId>S-1-5-32-545</GroupId>
        <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
    </Principals>
    <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
        <Duration>PT10M</Duration>
        <WaitTimeout>PT1H</WaitTimeout>
        <StopOnIdleEnd>true</StopOnIdleEnd>
        <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>true</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>7</Priority>
    </Settings>
    <Actions>
    <Exec>
        <Command>C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe</Command>
        <Arguments>-NoProfile -windowstyle hidden $localscript</Arguments>
    </Exec>
    </Actions>
</Task>
"@

            Write-Verbose -Message "Gathering environment variables"
            $taskfile = Join-Path $env:TEMP -ChildPath "SShot-Task.xml"
            
            if(!$path){$path = $env:TEMP}
            $rpath = "\\$pc\c$\Temp\"
            
            if( -not ( test-path $rpath ) )
            {
                New-Item -Path $rpath -ItemType Directory | Out-Null
            }

            # script on the remote host from calling hosts context
            $rscript = Join-Path $rpath -ChildPath "Take-Screenshot.ps1"
            
            # Search pattern for screenshot filename
            $Time = (Get-Date)
            [string] $FileName = "$pc-"
            $FileName += '*'
            $FileName += "-$($Time.Month)"
            $FileName += '-'
            $FileName += "$($Time.Day)" 
            $FileName += '-'
            $FileName += "$($Time.Year)"
            $FileName += '-'
            $FileName += "$($Time.Hour)"
            $FileName += '-'

            try
            {
                Write-Verbose -Message "Creating remote files on $pc"

                # Create the ps1 and the task template on the remote PC
                $remotescript | Set-Content -Path $rscript -Encoding Ascii -Force
                $task | Set-Content -Path $taskfile -Encoding Ascii
                
                # Attempt to create, run, and then delete scheduled task
                Write-Verbose -Message "Creating scheduled task on $pc"
                schtasks /create /xml $taskfile /tn "\Remote SShot" /S $pc /F | Out-Null
                Start-Sleep -Milliseconds 500

                Write-Verbose -Message "Running scheduled task on $pc"
                schtasks /run /tn "\Remote SShot" /S $pc | out-null
                Start-Sleep -Seconds 1

                Write-Verbose -Message "Deleting scheduled task on $pc"
                schtasks /delete /tn "\Remote SShot" /S $pc /F | Out-Null
                
                # Searching remote PC c:\temp directory for screenshot file
                Write-Verbose -Message "Moving screenshot from $pc to the local pc"
                $rfile = Get-ChildItem -Path $rpath -Filter "*$filename*" -File | select -last 1 -ExpandProperty name

                if($rfile.count -gt 0)
                {
                    # Screenshot found, move it and finally open it
                    $lfile = Join-Path $path -ChildPath $rfile
                    $frpath = Join-Path $rpath -ChildPath $rfile
                    $lfile = move-Item -Path $frpath -Destination $path -Force -PassThru
                    Start-Sleep -Seconds 1
                }
                else
                {
                    write-warning "No screenshot name matching $filename was found in \\$pc\C$\temp"
                }

            }
            Finally
            {
                Write-Verbose -Message "Deleting temporary files"
                Remove-Item $remotescript,$taskfile -Force -ErrorAction SilentlyContinue
                if($lfile){$lfile | Invoke-Item}
                
            }
        }

    }

    process
    {
        foreach($comp in $computername)
        {
            Take-SShot -pc $comp
        }
    }

    end
    {
    
    }

}
