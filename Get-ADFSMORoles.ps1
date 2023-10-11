Function Get-ADFSMORoles {
    try{
        $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain()
        $forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
    }
    catch [System.DirectoryServices.ActiveDirectory.ActiveDirectoryObjectNotFoundException]{
        Write-Warning $_.exception.message
        return
    }
    catch{
        throw $_
    }

    [PSCustomObject]@{
        PDCEmulator          = $domain.PDCRoleOwner
        RIDMaster            = $domain.RidRoleOwner
        SchemaMaster         = $forest.SchemaRoleOwner
        DomainNamingMaster   = $forest.NamingRoleOwner
        InfrastructureMaster = $domain.InfrastructureRoleOwner
    }
}
