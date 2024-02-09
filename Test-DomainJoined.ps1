Function Test-DomainJoined {

    $ErrorActionPreference = 'Stop'

    try{
        # still have to support older powershell.. sadly
        $roleid = (Get-WmiObject win32_Computersystem).domainrole
        if($roleid -in 0,2){$false}else{$true}
    }
    catch{
        Write-Warning $_.exception.message
    }
}
