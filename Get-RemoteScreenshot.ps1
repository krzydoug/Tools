function Get-RemoteScreenshot
{
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

    [cmdletbinding(DefaultParameterSetName='Single')]
    Param(
        [Parameter(
            Mandatory=$True,
            Position=0,
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$True
        )]
        [Alias(
            "PC",
            "Name",
            "CN",
            "Hostname"
        )]
        [string[]]$ComputerName,

        [Parameter(
            ParameterSetName='Single',
            Position=1
        )]
        [Alias(
            "User",
            "Login",
            "LoginName"
        )]
        [string]$UserName,

        [Parameter(
            ParameterSetName='All'
        )]
        [switch]$AllUsers,

        [Parameter()]             
        [ValidateScript({
            Test-Path -Path $_ 
        })]
        [string]$Path,

        [Parameter()]
        [switch]$NoCleanup,

        [Parameter()]
        [int]$Timeout = 5
    )

    begin
    {
        $ErrorActionPreference = 'stop'

        $PSDefaultParameterValues.'*-Content:Verbose' = $VerbosePreference
        $PSDefaultParameterValues.'*-Item:Verbose' = $VerbosePreference
        $PSDefaultParameterValues.'*-Sleep:Verbose' = $VerbosePreference
        $PSDefaultParameterValues.'*-Childitem:Verbose' = $VerbosePreference

        Write-Verbose -Message "Defining functions"



    Function Get-LoggedOnUser {
        [CmdletBinding()]
        Param (
            [Parameter(Mandatory=$false,ValueFromPipeline,ValueFromPipelineByPropertyName)]
            [ValidateNotNullOrEmpty()]
            [string[]]$ComputerName = 'Localhost'
        )
        
        Begin{
            try{

                $QueryUserSessionSource = @'
                using System;
                using System.Collections.Generic;
                using System.Text;
                using System.Runtime.InteropServices;
                using System.ComponentModel;
                using FILETIME=System.Runtime.InteropServices.ComTypes.FILETIME;
                namespace QueryUser
                {
                    public class Session
                    {
                        [DllImport("wtsapi32.dll", CharSet = CharSet.Auto, SetLastError = false)]
                        public static extern IntPtr WTSOpenServer(string pServerName);
                        [DllImport("wtsapi32.dll", CharSet = CharSet.Auto, SetLastError = false)]
                        public static extern void WTSCloseServer(IntPtr hServer);
                        [DllImport("wtsapi32.dll", CharSet = CharSet.Ansi, SetLastError = false)]
                        public static extern bool WTSQuerySessionInformation(IntPtr hServer, int sessionId, WTS_INFO_CLASS wtsInfoClass, out IntPtr pBuffer, out int pBytesReturned);
                        [DllImport("wtsapi32.dll", CharSet = CharSet.Ansi, SetLastError = false)]
                        public static extern int WTSEnumerateSessions(IntPtr hServer, int Reserved, int Version, out IntPtr pSessionInfo, out int pCount);
                        [DllImport("wtsapi32.dll", CharSet = CharSet.Auto, SetLastError = false)]
                        public static extern void WTSFreeMemory(IntPtr pMemory);
                        [DllImport("winsta.dll", CharSet = CharSet.Auto, SetLastError = false)]
                        public static extern int WinStationQueryInformation(IntPtr hServer, int sessionId, int information, ref WINSTATIONINFORMATIONW pBuffer, int bufferLength, ref int returnedLength);
                        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = false)]
                        public static extern int GetCurrentProcessId();
                        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = false)]
                        public static extern bool ProcessIdToSessionId(int processId, ref int pSessionId);

                        [StructLayout(LayoutKind.Sequential)]
                        private struct WTS_SESSION_INFO
                        {
                            public Int32 SessionId; [MarshalAs(UnmanagedType.LPStr)] public string SessionName; public WTS_CONNECTSTATE_CLASS State;
                        }

                        [StructLayout(LayoutKind.Sequential)]
                        public struct WINSTATIONINFORMATIONW
                        {
                            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 70)] private byte[] Reserved1;
                            public int SessionId;
                            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 4)] private byte[] Reserved2;
                            public FILETIME ConnectTime;
                            public FILETIME DisconnectTime;
                            public FILETIME LastInputTime;
                            public FILETIME LoginTime;
                            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 1096)] private byte[] Reserved3;
                            public FILETIME CurrentTime;
                        }

                        public enum WINSTATIONINFOCLASS { WinStationInformation = 8 }
                        public enum WTS_CONNECTSTATE_CLASS { Active, Connected, ConnectQuery, Shadow, Disconnected, Idle, Listen, Reset, Down, Init }
                        public enum WTS_INFO_CLASS { SessionId=4, UserName, SessionName, DomainName, ConnectState, ClientBuildNumber, ClientName, ClientDirectory, ClientProtocolType=16 }

                        private static IntPtr OpenServer(string Name) { IntPtr server = WTSOpenServer(Name); return server; }
                        private static void CloseServer(IntPtr ServerHandle) { WTSCloseServer(ServerHandle); }
                    
                        private static IList<T> PtrToStructureList<T>(IntPtr ppList, int count) where T : struct
                        {
                            List<T> result = new List<T>(); long pointer = ppList.ToInt64(); int sizeOf = Marshal.SizeOf(typeof(T));
                            for (int index = 0; index < count; index++)
                            {
                                T item = (T) Marshal.PtrToStructure(new IntPtr(pointer), typeof(T)); result.Add(item); pointer += sizeOf;
                            }
                            return result;
                        }

                        public static DateTime? FileTimeToDateTime(FILETIME ft)
                        {
                            if (ft.dwHighDateTime == 0 && ft.dwLowDateTime == 0) { return null; }
                            long hFT = (((long) ft.dwHighDateTime) << 32) + ft.dwLowDateTime;
                            return DateTime.FromFileTime(hFT);
                        }

                        public static WINSTATIONINFORMATIONW GetWinStationInformation(IntPtr server, int sessionId)
                        {
                            int retLen = 0;
                            WINSTATIONINFORMATIONW wsInfo = new WINSTATIONINFORMATIONW();
                            WinStationQueryInformation(server, sessionId, (int) WINSTATIONINFOCLASS.WinStationInformation, ref wsInfo, Marshal.SizeOf(typeof(WINSTATIONINFORMATIONW)), ref retLen);
                            return wsInfo;
                        }
                    
                        public static TerminalSessionData[] ListSessions(string ServerName)
                        {
                            IntPtr server = IntPtr.Zero;
                            if (ServerName != "localhost" && ServerName != String.Empty) {server = OpenServer(ServerName);}
                            List<TerminalSessionData> results = new List<TerminalSessionData>();
                            try
                            {
                                IntPtr ppSessionInfo = IntPtr.Zero; int count; bool _isUserSession = false; IList<WTS_SESSION_INFO> sessionsInfo;
                            
                                if (WTSEnumerateSessions(server, 0, 1, out ppSessionInfo, out count) == 0) { throw new Win32Exception(); }
                                try { sessionsInfo = PtrToStructureList<WTS_SESSION_INFO>(ppSessionInfo, count); }
                                finally { WTSFreeMemory(ppSessionInfo); }
                            
                                foreach (WTS_SESSION_INFO sessionInfo in sessionsInfo)
                                {
                                    if (sessionInfo.SessionName != "Services" && sessionInfo.SessionName != "RDP-Tcp") { _isUserSession = true; }
                                    results.Add(new TerminalSessionData(sessionInfo.SessionId, sessionInfo.State, sessionInfo.SessionName, _isUserSession));
                                    _isUserSession = false;
                                }
                            }
                            finally { CloseServer(server); }
                            TerminalSessionData[] returnData = results.ToArray();
                            return returnData;
                        }
                    
                        public static TerminalSessionInfo GetSessionInfo(string ServerName, int SessionId)
                        {
                            IntPtr server = IntPtr.Zero;
                            IntPtr buffer = IntPtr.Zero;
                            int bytesReturned;
                            TerminalSessionInfo data = new TerminalSessionInfo();
                            bool _IsCurrentSessionId = false;
                            bool _IsConsoleSession = false;
                            bool _IsUserSession = false;
                            int currentSessionID = 0;
                            string _NTAccount = String.Empty;

                            if (ServerName != "localhost" && ServerName != String.Empty) { server = OpenServer(ServerName); }
                            if (ProcessIdToSessionId(GetCurrentProcessId(), ref currentSessionID) == false) { currentSessionID = -1; }
                            try
                            {
                                if (WTSQuerySessionInformation(server, SessionId, WTS_INFO_CLASS.ClientBuildNumber, out buffer, out bytesReturned) == false) { return data; }
                                int lData = Marshal.ReadInt32(buffer);
                                data.ClientBuildNumber = lData;

                                if (WTSQuerySessionInformation(server, SessionId, WTS_INFO_CLASS.ClientDirectory, out buffer, out bytesReturned) == false) { return data; }
                                string strData = Marshal.PtrToStringAnsi(buffer);
                                data.ClientDirectory = strData;

                                if (WTSQuerySessionInformation(server, SessionId, WTS_INFO_CLASS.ClientName, out buffer, out bytesReturned) == false) { return data; }
                                strData = Marshal.PtrToStringAnsi(buffer);
                                data.ClientName = strData;

                                if (WTSQuerySessionInformation(server, SessionId, WTS_INFO_CLASS.ClientProtocolType, out buffer, out bytesReturned) == false) { return data; }
                                Int16 intData = Marshal.ReadInt16(buffer);
                                if (intData == 2) {strData = "RDP";} else {strData = "";}
                                data.ClientProtocolType = strData;

                                if (WTSQuerySessionInformation(server, SessionId, WTS_INFO_CLASS.ConnectState, out buffer, out bytesReturned) == false) { return data; }
                                lData = Marshal.ReadInt32(buffer);
                                data.ConnectState = (WTS_CONNECTSTATE_CLASS)Enum.ToObject(typeof(WTS_CONNECTSTATE_CLASS), lData);

                                if (WTSQuerySessionInformation(server, SessionId, WTS_INFO_CLASS.SessionId, out buffer, out bytesReturned) == false) { return data; }
                                lData = Marshal.ReadInt32(buffer);
                                data.SessionId = lData;

                                if (WTSQuerySessionInformation(server, SessionId, WTS_INFO_CLASS.DomainName, out buffer, out bytesReturned) == false) { return data; }
                                strData = Marshal.PtrToStringAnsi(buffer);
                                data.DomainName = strData;
                                data.ComputerName = ServerName;
                                if (strData != String.Empty) {_NTAccount = strData;}

                                if (WTSQuerySessionInformation(server, SessionId, WTS_INFO_CLASS.UserName, out buffer, out bytesReturned) == false) { return data; }
                                strData = Marshal.PtrToStringAnsi(buffer);
                                data.UserName = strData;
                                if (strData != String.Empty) {data.NTAccount = _NTAccount + "\\" + strData;}

                                if (WTSQuerySessionInformation(server, SessionId, WTS_INFO_CLASS.SessionName, out buffer, out bytesReturned) == false) { return data; }
                                strData = Marshal.PtrToStringAnsi(buffer);
                                data.SessionName = strData;
                                if (strData != "Services" && strData != "RDP-Tcp") { _IsUserSession = true; }
                                data.IsUserSession = _IsUserSession;
                                if (strData == "Console") { _IsConsoleSession = true; }
                                data.IsConsoleSession = _IsConsoleSession;

                                WINSTATIONINFORMATIONW wsInfo = GetWinStationInformation(server, SessionId);
                                DateTime? _loginTime = FileTimeToDateTime(wsInfo.LoginTime);
                                DateTime? _lastInputTime = FileTimeToDateTime(wsInfo.LastInputTime);
                                DateTime? _disconnectTime = FileTimeToDateTime(wsInfo.DisconnectTime);
                                DateTime? _currentTime = FileTimeToDateTime(wsInfo.CurrentTime);
                                TimeSpan? _idleTime = (_currentTime != null && _lastInputTime != null) ? _currentTime.Value - _lastInputTime.Value : TimeSpan.Zero;
                                data.LogonTime = _loginTime;
                                data.IdleTime = _idleTime;
                                data.DisconnectTime = _disconnectTime;

                                if (currentSessionID == SessionId) { _IsCurrentSessionId = true; }
                                data.IsCurrentSession = _IsCurrentSessionId;
                            }
                            finally
                            {
                                WTSFreeMemory(buffer); buffer = IntPtr.Zero; CloseServer(server);
                            }
                            return data;
                        }
                    }

                    public class TerminalSessionData
                    {
                        public int SessionId; public Session.WTS_CONNECTSTATE_CLASS ConnectionState; public string SessionName; public bool IsUserSession;
                        public TerminalSessionData(int sessionId, Session.WTS_CONNECTSTATE_CLASS connState, string sessionName, bool isUserSession)
                        {
                            SessionId = sessionId; ConnectionState = connState; SessionName = sessionName; IsUserSession = isUserSession;
                        }
                    }

                    public class TerminalSessionInfo
                    {
                        public string ComputerName; public string NTAccount; public string UserName; public string DomainName; public int SessionId; public string SessionName;
                        public Session.WTS_CONNECTSTATE_CLASS ConnectState; public bool IsCurrentSession; public bool IsConsoleSession;
                        public bool IsUserSession; public DateTime? LogonTime; public TimeSpan? IdleTime; public DateTime? DisconnectTime;
                        public string ClientName; public string ClientProtocolType; public string ClientDirectory; public int ClientBuildNumber;
                    }


                }
'@
                If (-not ([System.Management.Automation.PSTypeName]'QueryUser.Session').Type)
                {
                    Add-Type -TypeDefinition $QueryUserSessionSource -Language CSharp -IgnoreWarnings -ErrorAction 'Stop'
                }
            }
            catch {
                
            }

        }

        Process {
            foreach($name in $computername)
            {
                Try
                {
                    [psobject[]]$TerminalSessions = [QueryUser.Session]::ListSessions($name)
                    ForEach ($TerminalSession in $TerminalSessions)
                    {
                        If (($TerminalSession.IsUserSession))
                        {
                            [psobject]$SessionInfo = [QueryUser.Session]::GetSessionInfo($name, $TerminalSession.SessionId)
                            If ($SessionInfo.UserName)
                            {
                                Write-Output $SessionInfo
                            }
                        }
                    }
                }
                Catch
                {}
            }
        }

        End
        {}
    }

        Function Take-SShot
        {
            Param($pc,$UserName)
            
            $PSDefaultParameterValues.'*-Content:Verbose' = $VerbosePreference
            $PSDefaultParameterValues.'*-Item:Verbose' = $VerbosePreference
            $PSDefaultParameterValues.'*-Sleep:Verbose' = $VerbosePreference
            $PSDefaultParameterValues.'*-Childitem:Verbose' = $VerbosePreference

            $ErrorActionPreference = 'stop'

            # -------------------------------  Optional - modify this for your environment  -------------------------------

            # temporary location on remote PC for scripts
            $localpsscript = "c:\Temp\Take-Screenshot.ps1"
            $localvbscript = "c:\Temp\launch.vbs"

            # -------------------------------  Don't modify anything past this line  -------------------------------

            $psscript = @'
                Function Take-Screenshot
                {
                [CmdletBinding()]
                Param(
                    [ValidateScript({
                        Test-Path -Path $_
                    })]
                    [string]$Path
                )
    
                #Define helper function that generates and saves screenshot
                Function GenScreenshot
                {
                    $ScreenBounds = [Windows.Forms.SystemInformation]::VirtualScreen
                    $ScreenshotObject = New-Object Drawing.Bitmap $ScreenBounds.Width, $ScreenBounds.Height
                    $DrawingGraphics = [Drawing.Graphics]::FromImage($ScreenshotObject)
                    $DrawingGraphics.CopyFromScreen( $ScreenBounds.Location, [Drawing.Point]::Empty, $ScreenBounds.Size)
                    $DrawingGraphics.Dispose()
                    $ScreenshotObject.Save($FilePath)
                    $ScreenshotObject.Dispose()
                }

                Try
                {
            
                    #load required assembly
                    Add-Type -Assembly System.Windows.Forms            

                    # Build filename from PC, user, and the current date/time.
                    $FileName = "${env:computername}-${env:username}-{0}.png" -f (Get-Date).ToString("yyyyMMdd-HHmmss")

                    $FilePath = Join-Path $path $FileName

                    #run screenshot function
                    GenScreenshot
                
                    Write-Verbose "Saved screenshot to $FilePath."
		
                }
                Catch
                {
                    Write-Warning $Error[0]
                }

        }

        Take-Screenshot -path C:\Temp
'@
            
#region scheduled task template
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
        <UserId>$UserName</UserId>
        <LogonType>InteractiveToken</LogonType>
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
        <Command>wscript.exe</Command>
        <Arguments>$localvbscript /B</Arguments>
    </Exec>
    </Actions>
</Task>
"@
#endregion

# region VBScript template
            $VBscript = @"
    Dim objShell,objFSO,objFile

    Set objShell=CreateObject("WScript.Shell")
    Set objFSO=CreateObject("Scripting.FileSystemObject")

    'enter the path for your PowerShell Script
    strPath="$localpsscript"

    'verify file exists
    If objFSO.FileExists(strPath) Then
    'return short path name
        set objFile=objFSO.GetFile(strPath)
        strCMD="powershell -nologo -ex bypass -nop -Command " & Chr(34) & "&{" &_
            objFile.ShortPath & "}" & Chr(34)
        'Uncomment next line for debugging
        'WScript.Echo strCMD
   
        'use 0 to hide window
        objShell.Run strCMD,0

    Else

    'Display error message
        WScript.Echo "Failed to find " & strPath
        WScript.Quit
   
    End If
"@
#endregion
            
            Write-Verbose -Message "Gathering environment variables"
            $taskfile = Join-Path $env:TEMP -ChildPath "SShot-Task.xml"
            
            if( -not $path ){$path = $env:TEMP}
            $rpath = "\\$pc\c$\Temp\"
            
            if( -not ( test-path $rpath ) )
            {
                New-Item -Path $rpath -ItemType Directory | Out-Null
            }

            # script on the remote host from calling hosts context
            $psscriptfile = Join-Path $rpath -ChildPath "Take-Screenshot.ps1"
            
            $vbscriptfile = Join-Path $rpath -ChildPath "launch.vbs"

            if(Test-Path $vbscriptfile){
                $existinglaunch = Rename-Item -Path $vbscriptfile -NewName Launch.bak -PassThru
            }
            # Search pattern for screenshot filename
            $FileName = "$pc-*-{0}" -f (Get-Date).ToString("yyyyMMdd-HH")

            try
            {
                Write-Verbose -Message "Creating remote files on $pc"

                # Create the ps1, vbs, and the task template on the remote PC
                $psscript | Set-Content -Path $psscriptfile -Encoding Ascii -Force
                $task     | Set-Content -Path $taskfile -Encoding Ascii
                $VBscript | Set-Content -Path $vbscriptfile -Encoding Ascii
                
                # Attempt to create, run, and then delete scheduled task
                Write-Verbose -Message "Creating scheduled task on $pc"
                schtasks /create /xml $taskfile /tn "\Remote SShot" /S $pc /F | Out-Null
                Start-Sleep -Milliseconds 500

                Write-Verbose -Message "Running scheduled task on $pc"
                schtasks /run /tn "\Remote SShot" /S $pc | out-null

                do
                {
                    Start-Sleep -Seconds 1
                    $taskstatus = ((schtasks /query /tn "Remote SShot" /S $pc /FO list | Select-String -Pattern 'Status:') -split ':')[1].trim()
                }
                until ($taskstatus -ne 'running')
                
                $retries = 0
                do
                {
                    Write-Verbose "Loop $retries waiting for file creation on $pc"
                    Start-Sleep -Seconds 2
                    $rfile = Get-ChildItem -Path $rpath -Filter "$filename*" -File | select -last 1 -ExpandProperty name
                    $retries++
                }
                until ($rfile.count -gt 0 -or $retries -ge $Timeout)

                if($rfile.count -gt 0)
                {
                    # Screenshot found, move it and finally open it
                    Write-Verbose -Message "Moving screenshot from $pc to the local pc"
                    $lfile = Join-Path $path -ChildPath $rfile
                    $frpath = Join-Path $rpath -ChildPath $rfile
                    $lfile = move-Item -Path $frpath -Destination $path -Force -PassThru
                    Start-Sleep -Milliseconds 500
                }
                else
                {
                    Write-Warning "No screenshot found for $UserName on $pc. Session may be locked."
                }

            }
            Catch
            {
                Write-Warning $Error[0]
            }
            Finally
            {
                if(-not $NoCleanup){
                    Write-Verbose -Message "Deleting scheduled task on $pc"
                    schtasks /delete /tn "\Remote SShot" /S $pc /F | Out-Null
                
                    Write-Verbose -Message "Deleting temporary files"
                
                    try
                    {
                        Remove-Item $psscriptfile,$taskfile,$vbscriptfile -Force -ErrorAction SilentlyContinue
                        if($lfile){$lfile | Invoke-Item}
                    }
                    catch
                    {
                        Write-Warning $Error[0]
                    }
                }

                if($existinglaunch){
                    if($NoCleanup){
                        Write-Warning "Existing Launch.vbs file replacing this copy"
                        Remove-Item $vbscriptfile -Force -ErrorAction SilentlyContinue
                    }

                    Rename-Item $existinglaunch.FullName -NewName Launch.vbs
                }
            }
        }
    }

    process
    {
        foreach($comp in $computername)
        {
            if($PSCmdlet.ParameterSetName -eq 'Single'){
                $userlist = Get-LoggedOnUser -ComputerName $comp

                if($userlist.count -eq 0){
                    Write-Warning "No user sessions exist on $comp"
                    continue
                }

                if($UserName){
                    if($user = $userlist | Where-Object {$_.NTAccount -eq $UserName -or $_.username -eq $UserName}){
                        $UserName = $user.NTAccount
                    }
                    else{
                        Write-Warning "No session for $UserName exists on $ComputerName"
                        continue
                    }
                }
                else{
                    if($userlist.Count -gt 1){
                        Write-Warning "More than one user session exists on $comp"
                        continue
                    }
                    $UserName = $userlist[0].NTAccount
                }
            }
            elseif($PSCmdlet.ParameterSetName -eq 'All'){
                $userlist = Get-LoggedOnUser -ComputerName $comp

                if($userlist.Count -eq 0){
                    Write-Warning "No user sessions exist on $comp"
                }
                else{
                    Write-Verbose "Found $($userlist.Count) user sessions"
                    [array]$UserName = $userlist.NTAccount
                }
            }
            
            foreach($user in $UserName){
                Write-Verbose "Attempting to get screenshot for $user"
                Take-SShot -pc $comp -UserName $user
            }

            Remove-Variable Username,userlist,user -ErrorAction SilentlyContinue
        }
    }

    end
    {
        
    }

}
