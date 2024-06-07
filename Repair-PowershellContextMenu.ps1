function Enable-Privilege {
    param(
        ## The privilege to adjust. This set is taken from
        ## http://msdn.microsoft.com/en-us/library/bb530716(VS.85).aspx
        [ValidateSet(
        "SeAssignPrimaryTokenPrivilege", "SeAuditPrivilege", "SeBackupPrivilege",
        "SeChangeNotifyPrivilege", "SeCreateGlobalPrivilege", "SeCreatePagefilePrivilege",
        "SeCreatePermanentPrivilege", "SeCreateSymbolicLinkPrivilege", "SeCreateTokenPrivilege",
        "SeDebugPrivilege", "SeEnableDelegationPrivilege", "SeImpersonatePrivilege", "SeIncreaseBasePriorityPrivilege",
        "SeIncreaseQuotaPrivilege", "SeIncreaseWorkingSetPrivilege", "SeLoadDriverPrivilege",
        "SeLockMemoryPrivilege", "SeMachineAccountPrivilege", "SeManageVolumePrivilege",
        "SeProfileSingleProcessPrivilege", "SeRelabelPrivilege", "SeRemoteShutdownPrivilege",
        "SeRestorePrivilege", "SeSecurityPrivilege", "SeShutdownPrivilege", "SeSyncAgentPrivilege",
        "SeSystemEnvironmentPrivilege", "SeSystemProfilePrivilege", "SeSystemtimePrivilege",
        "SeTakeOwnershipPrivilege", "SeTcbPrivilege", "SeTimeZonePrivilege", "SeTrustedCredManAccessPrivilege",
        "SeUndockPrivilege", "SeUnsolicitedInputPrivilege")]
        $Privilege,

        ## The process on which to adjust the privilege. Defaults to the current process.
        $ProcessId = $pid,

        ## Switch to disable the privilege, rather than enable it.
        [Switch] $Disable
    )

 ## Taken from P/Invoke.NET with minor adjustments.
 $definition = @'
    using System;
    using System.Runtime.InteropServices;
  
    public class AdjPriv
    {
        [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
        internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall,
        ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);
  
        [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
        internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);
        [DllImport("advapi32.dll", SetLastError = true)]
        internal static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);
        [StructLayout(LayoutKind.Sequential, Pack = 1)]

        internal struct TokPriv1Luid
        {
            public int Count;
            public long Luid;
            public int Attr;
        }
  
        internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
        internal const int SE_PRIVILEGE_DISABLED = 0x00000000;
        internal const int TOKEN_QUERY = 0x00000008;
        internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;

        public static bool EnablePrivilege(long processHandle, string privilege, bool disable)
        {
            bool retVal;
            TokPriv1Luid tp;
            IntPtr hproc = new IntPtr(processHandle);
            IntPtr htok = IntPtr.Zero;
            retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
            tp.Count = 1;
            tp.Luid = 0;

            if(disable)
            {
                tp.Attr = SE_PRIVILEGE_DISABLED;
            }
            else
            {
                tp.Attr = SE_PRIVILEGE_ENABLED;
            }
            retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
            retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
            return retVal;
        }
    }
'@

    $processHandle = (Get-Process -id $ProcessId).Handle

    $typeloaded = try{
        [adjpriv].GetType()
    }
    catch{}

    if(-not $typeloaded){
        $type = Add-Type $definition -PassThru -ErrorAction SilentlyContinue
    }

    [adjpriv]::EnablePrivilege($processHandle, $Privilege, $Disable)
}

Function Set-RegistryOwner {
    param (
        [ValidateSet('HKCR','HKLM','HKU', 'HKCC', 'HKCU')]
        [string]$Root = 'HKLM',

        [string]$Path,

        [string]$UserName = "$env:USERDOMAIN\$env:USERNAME"
    )
    
    $rootstore = switch($Root){
        'HKLM' {'LocalMachine'}
        'HKCR' {'ClassesRoot'}
        'HKU'  {'Users'}
        'HKCC' {'CurrentConfig'}
        'HKCU' {'CurrentUser'}
    }
    
    if($false -eq (Enable-Privilege "SeTakeOwnershipPrivilege")){
        Write-Warning "Error enabling takeownership privilege"
        return
    }
    
    $key = [Microsoft.Win32.Registry]::$rootstore.OpenSubKey($Path, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::TakeOwnership)
    if ($key -eq $null) {
        Write-Host "Error opening registry key '$($root):\$Path'" -ForegroundColor Red
        pause
        return
    }

    $acl = $key.GetAccessControl()
    $owner = [System.Security.Principal.NTAccount]$UserName

    try{
        $acl.SetOwner($owner)
        $key.SetAccessControl($acl)
        Write-Host "Ownership of registry key '$($root):\$Path' has been set to $UserName" -ForegroundColor Green
    }
    catch{
        Write-Warning "Error setting ownership: $($_.exception.message)"
    }
}

Set-RegistryOwner -Root HKCR -Path Directory\Background\shell\Powershell\command -UserName 'Administrators'

try{
    $regKey = [Microsoft.Win32.Registry]::ClassesRoot.OpenSubKey("Directory\Background\shell\Powershell\command",[Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[System.Security.AccessControl.RegistryRights]::ChangePermissions)
    $regACL = $regKey.GetAccessControl()
    $regRule = New-Object System.Security.AccessControl.RegistryAccessRule ("Administrators","FullControl","ContainerInherit","None","Allow")
    $regACL.SetAccessRule($regRule)
    $regKey.SetAccessControl($regACL)
    Write-Host "Successfully set FullControl permissions for Administrators" -ForegroundColor Green
}
catch{
    Write-Warning "Error setting FullControl permissions for Administrators"
    pause
    return
}

Write-Host "Applying context menu fix for 'Open powershell here'" -ForegroundColor Cyan

$output = reg add HKEY_CLASSES_ROOT\Directory\Background\shell\Powershell\command /d 'powershell.exe -noexit -command Set-Location -literalPath """"""""%V""""""""' /f 2>&1

if($output -match 'operation completed successfully'){
    Write-Host "Set commandline context menu handler successfully" -ForegroundColor Green
}

Write-Host "Setting permissions and owner back to original values" -ForegroundColor Cyan

try{
    Write-Host "Setting ReadKey rights for Administrators" -ForegroundColor Cyan
    $regACL = $regKey.GetAccessControl()
    $regRule = New-Object System.Security.AccessControl.RegistryAccessRule ("Administrators","Readkey","ContainerInherit","None","Allow")
    $regACL.SetAccessRule($regRule)
    $regKey.SetAccessControl($regACL)
    Write-Host "Successfully set ReadKey permissions for Administrators" -ForegroundColor Green
}
catch{
    Write-Warning "Error setting ReadKey permissions for Administrators"
}

if(Enable-Privilege SeRestorePrivilege){
    Write-Host "Setting owner back to TrustedInstaller" -ForegroundColor Cyan

    try{
        $acl = $regKey.GetAccessControl('owner')
        $acl.SetOwner([System.Security.Principal.NTAccount]'NT Service\TrustedInstaller')
        $regKey.SetAccessControl($acl)
        Write-Host "Successfully set owner as TrustedInstaller" -ForegroundColor Green
    }
    catch{
        Write-Warning "Error setting ReadKey permissions for Administrators"
    }
}
else{
    Write-Warning "Error setting SeRestorePrivilege rights"
}

pause
