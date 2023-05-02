Function Reset-VssWriter {
    [cmdletbinding(SupportsShouldProcess,ConfirmImpact='High')]
    Param(
        [parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [validateset('FRS Writer', 'Registry Writer', 'OSearch VSS Writer', 'SqlServerWriter',
                     'OSearch14 VSS Writer', 'FSRM writer', 'Shadow Copy Optimization Writer',
                     'IIS Config Writer', 'DFS Replication service writer', 'WMI Writer',
                     'Microsoft Hyper-V VSS Writer', 'DHCP Jet Writer', 'Microsoft Exchange Writer',
                     'SPSearch VSS Writer', 'COM+ REGDB Writer', 'NTDS', 'WINS Jet Writer',
                     'IIS Metabase Writer', 'System Writer', 'TermServLicensing',
                     'SPSearch4 VSS Writer', 'BITS Writer', 'ASR Writer')]
        [string[]]$Name
    )

    begin{
        Write-Verbose "Building VSS Writer lookup table"

        $writerdata = '[
            {
                "WriterName":  "System Writer",
                "ServiceName":  "CryptSvc",
                "ServiceDisplayName":  "Cryptographic Services"
            },
            {
                "WriterName":  "ASR Writer",
                "ServiceName":  "VSS",
                "ServiceDisplayName":  "Volume Shadow Copy"
            },
            {
                "WriterName":  "BITS Writer",
                "ServiceName":  "BITS",
                "ServiceDisplayName":  "Background Intelligent Transfer Service"
            },
            {
                "WriterName":  "COM+ REGDB Writer",
                "ServiceName":  "VSS",
                "ServiceDisplayName":  "Volume Shadow Copy"
            },
            {
                "WriterName":  "DFS Replication service writer",
                "ServiceName":  "DFSR",
                "ServiceDisplayName":  "DFS Replication"
            },
            {
                "WriterName":  "DHCP Jet Writer",
                "ServiceName":  "DHCPServer",
                "ServiceDisplayName":  "DHCP Server"
            },
            {
                "WriterName":  "FRS Writer",
                "ServiceName":  "NtFrs",
                "ServiceDisplayName":  "File Replication"
            },
            {
                "WriterName":  "FSRM writer",
                "ServiceName":  "srmsvc",
                "ServiceDisplayName":  "File Server Resource Manager"
            },
            {
                "WriterName":  "IIS Config Writer",
                "ServiceName":  "AppHostSvc",
                "ServiceDisplayName":  "Application Host Helper Service"
            },
            {
                "WriterName":  "IIS Metabase Writer",
                "ServiceName":  "IISADMIN",
                "ServiceDisplayName":  "IIS Admin Service"
            },
            {
                "WriterName":  "Microsoft Exchange Writer",
                "ServiceName":  "MSExchangeIS",
                "ServiceDisplayName":  "Microsoft Exchange Information Store"
            },
            {
                "WriterName":  "Microsoft Hyper-V VSS Writer",
                "ServiceName":  "vmms",
                "ServiceDisplayName":  "Hyper-V Virtual Machine Management"
            },
            {
                "WriterName":  "NTDS",
                "ServiceName":  "NTDS",
                "ServiceDisplayName":  "Active Directory Domain Services"
            },
            {
                "WriterName":  "OSearch VSS Writer",
                "ServiceName":  "OSearch",
                "ServiceDisplayName":  "Office SharePoint Server Search"
            },
            {
                "WriterName":  "OSearch14 VSS Writer",
                "ServiceName":  "OSearch14",
                "ServiceDisplayName":  "SharePoint Server Search 14"
            },
            {
                "WriterName":  "Registry Writer",
                "ServiceName":  "VSS",
                "ServiceDisplayName":  "Volume Shadow Copy"
            },
            {
                "WriterName":  "Shadow Copy Optimization Writer",
                "ServiceName":  "VSS",
                "ServiceDisplayName":  "Volume Shadow Copy"
            },
            {
                "WriterName":  "SPSearch VSS Writer",
                "ServiceName":  "SPSearch",
                "ServiceDisplayName":  "Windows SharePoint Services Search"
            },
            {
                "WriterName":  "SPSearch4 VSS Writer",
                "ServiceName":  "SPSearch4",
                "ServiceDisplayName":  "SharePoint Foundation Search V4"
            },
            {
                "WriterName":  "SqlServerWriter",
                "ServiceName":  "SQLWriter",
                "ServiceDisplayName":  "SQL Server VSS Writer"
            },
            {
                "WriterName":  "System Writer",
                "ServiceName":  "CryptSvc",
                "ServiceDisplayName":  "Cryptographic Services"
            },
            {
                "WriterName":  "TermServLicensing",
                "ServiceName":  "TermServLicensing",
                "ServiceDisplayName":  "Remote Desktop Licensing"
            },
            {
                "WriterName":  "WINS Jet Writer",
                "ServiceName":  "WINS",
                "ServiceDisplayName":  "Windows Internet Name Service (WINS)"
            },
            {
                "WriterName":  "WMI Writer",
                "ServiceName":  "Winmgmt",
                "ServiceDisplayName":  "Windows Management Instrumentation"
            }
        ]' | ConvertFrom-Json
        $writertable = $writerdata | Group-Object -Property WriterName -AsHashTable -AsString
    }
 
    process{
        $lookup = ($Name | ForEach-Object {[regex]::Escape($_)}) -join '|'

        $found = $writerdata | Where-Object WriterName -Match $lookup | Get-Unique
    
        if($found){
            foreach($writer in $found){
                $service = $writertable[$writer.WriterName]
                $message = "Restart writer '$($writer.WriterName)' service '$($service.ServiceDisplayName) ($($service.ServiceName))'"

                if($PSCmdlet.ShouldProcess($message,$message,'Restart Service?')){
                    Restart-Service -Name $service.ServiceName -Confirm:$false -Verbose:$($PSBoundParameters.ContainsKey('Verbose')) -Force
                }
            }
        }
    }
}
