function Get-DNSRecord {
    <#
    .SYNOPSIS
    Get DNS record(s) for specified name/fqdn
    .DESCRIPTION
    Returns the DNS record(s) for the specified hostname/fqdn of the specified type.
    If no record type is specified, 'SOA', 'A', 'CNAME', 'MX', 'TXT', and 'NS' will be queried.
    .PARAMETER Name
    Hostname or FQDN to search records for
    .PARAMETER NameServer
    The DNS server to query. Uses the querying systems configured DNS servers if not specified.
    .PARAMETER QueryType
    The DNS record type for the query. Uses 'SOA', 'A', 'CNAME', 'MX', 'TXT', and 'NS' if none specified.
    .EXAMPLE
    Get-DNSRecord www.google.com -QueryType A
    Queries configured DNS server for www.google.com A record. 
    .EXAMPLE
    Get-DNSRecord microsoft.com 9.9.9.9
    Queries DNS server 9.9.9.9 for all supported microsoft.com records. 
    .EXAMPLE
    'microsoft.com','stackoverflow.com' | Get-DNSRecord 8.8.8.8 NS, A, TXT
    Queries DNS server 8.8.8.8 for NS, A, and TXT records for microsoft.com and stackoverflow.com. 
    .NOTES
    Requires the wonderful DnsClient-PS module (https://github.com/rmbolger/DnsClient-PS)
    .LINK
    https://github.com/krzydoug/Tools/blob/master/Get-DNSRecord.ps1
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        [String[]]$Name,

        [Parameter(Position=1)]
        [String]$NameServer,

        [Parameter(Position=2)]
        [ValidateSet('SOA', 'A', 'CNAME', 'MX', 'TXT', 'NS')]
        [String[]]$QueryType = ('SOA', 'A', 'CNAME', 'MX', 'TXT', 'NS')
    )

    Begin{
        $params = @{
            ErrorAction      = 'Stop'
            ErrorVariable    = 'err'
        }

        If ($NameServer) {
            $params += @{
                    NameServer = $NameServer
            }
        }

        if(-not (Get-Module -ListAvailable -Name DnsClient-PS)){
            Install-Module -Name DnsClient-PS -Force
        }
    }
    
    Process{
        foreach($nm in $name){
            $params.Query = $nm

            $QueryType | Foreach-Object {
                $params.QueryType = $_

                try{
                    foreach($result in Resolve-Dns @params){
                        $result | Select-Object NameServer -ExpandProperty Answers
                    }
                }
                catch{
                    write-warning $_.exception
                }
            } 
        }
    }
}
