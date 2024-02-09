Function Get-DomainRole {

    $ErrorActionPreference = 'Stop'

    $roletable = @{
        '0' = 'Standalone Workstation'
        '1' = 'Member Workstation'
        '2' = 'Standalone Server'
        '3' = 'Member Server'
        '4' = 'Backup Domain Controller'
        '5' = 'Primary Domain Controller'
    }

    try{
        # still have to support older powershell.. sadly
        $roleid = (Get-WmiObject win32_Computersystem).domainrole
        $roletable["$roleid"]
    }
    catch{
        Write-Warning $_.exception.message
    }
}
