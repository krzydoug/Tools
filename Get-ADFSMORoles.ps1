Function Get-ADFSMORoles {
    $forest = Get-ADForest
    $domain = Get-ADDomain

    [PSCustomObject]@{
        PDCEmulator          = $domain.PDCEmulator
        RIDMaster            = $domain.Ridmaster
        SchemaMaster         = $forest.schemamaster
        DomainNamingMaster   = $forest.domainnamingmaster
        InfrastructureMaster = $domain.InfrastructureMaster
    }
}
