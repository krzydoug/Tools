
<#PSScriptInfo

.VERSION 1.0.0.2

.GUID 2f9fcfa3-9024-4304-a84f-2448e1d434aa

.AUTHOR Doug Maurer

.COMPANYNAME Doug Maurer

.COPYRIGHT 2020

.TAGS 

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES


#>

<# 

.SYNOPSIS
	Get session details for all local and RDP logged on users.

.DESCRIPTION
	Get session details for all local and RDP logged on users using Win32 APIs. Get the following session details:
	 NTAccount, UserName, DomainName, SessionId, SessionName, ConnectState, IsCurrentSession, IsConsoleSession, IsUserSession,
	 LogonTime, IdleTime, DisconnectTime, ClientName, ClientProtocolType, ClientDirectory, ClientBuildNumber

.EXAMPLE
	Get-LoggedOnUser



#> 

Function Get-LoggedOnUser {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$false,ValueFromPipeline,ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string[]]$ComputerName = 'Localhost'
	)
	
	Begin {
        try{
		    ## Get the name of this function and write header
		    [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		
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
