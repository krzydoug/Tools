Function Get-ADFSMORoles {
    $forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
    $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()

    [PSCustomObject]@{
        PDCEmulator          = $domain.PDCRoleOwner
        RIDMaster            = $domain.RidRoleOwner
        SchemaMaster         = $forest.SchemaRoleOwner
        DomainNamingMaster   = $forest.NamingRoleOwner
        InfrastructureMaster = $domain.InfrastructureRoleOwner
    }
}
