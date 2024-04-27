function Get-RemoteCertificate {
    <#
    .SYNOPSIS
        Retrieve SSL certificate
    .DESCRIPTION
        Retrieve SSL certificate from HTTPS site
    .EXAMPLE
        PS C:\> Get-RemoteCertificate -HostName www.microsoft.com | Select-Object -Property *

        DnsNameList          : {wwwqa.microsoft.com, www.microsoft.com, staticview.microsoft.com, i.s-microsoft.com...}
        EnhancedKeyUsageList : {Client Authentication (1.3.6.1.5.5.7.3.2), Server Authentication (1.3.6.1.5.5.7.3.1)}
        Url                  : www.microsoft.com
        Protocollist         : tls12
        DaysRemaining        : 234
        Archived             : False
        Extensions           : {System.Security.Cryptography.Oid, System.Security.Cryptography.Oid, System.Security.Cryptography.Oid, System.Security.Cryptography.Oid...}
        FriendlyName         : 
        IssuerName           : System.Security.Cryptography.X509Certificates.X500DistinguishedName
        NotAfter             : 9/8/2024 12:24:20 PM
        NotBefore            : 9/14/2023 12:24:20 PM
        HasPrivateKey        : False
        PrivateKey           : 
        PublicKey            : System.Security.Cryptography.X509Certificates.PublicKey
        RawData              : {48, 130, 8, 229...}
        SerialNumber         : 330003E2CD1066AD8DB81C060800000003E2CD
        SubjectName          : System.Security.Cryptography.X509Certificates.X500DistinguishedName
        SignatureAlgorithm   : System.Security.Cryptography.Oid
        Thumbprint           : E1579BA55125CEC3A78E39F55CF81DA8BFA94F88
        Version              : 3
        Handle               : 2814278731296
        Issuer               : CN=Microsoft Azure RSA TLS Issuing CA 07, O=Microsoft Corporation, C=US
        Subject              : CN=www.microsoft.com, O=Microsoft Corporation, L=Redmond, S=WA, C=US
    .EXAMPLE
        PS C:\> Get-RemoteCertificate bing.com,powershell.org,amazon.com
        
        Url            Subject                                                         NotAfter             Issuer                                                             
        ---            -------                                                         --------             ------                                                             
        bing.com       CN=www.bing.com, O=Microsoft Corporation, L=Redmond, S=WA, C=US 6/27/2024 6:59:59 PM CN=Microsoft Azure TLS Issuing CA 01, O=Microsoft Corporation, C=US
        powershell.org CN=powershell.org                                               6/29/2024 9:19:16 AM CN=GTS CA 1P5, O=Google Trust Services LLC, C=US                   
        amazon.com     CN=*.peg.a2z.com                                                1/7/2025 5:59:59 PM  CN=DigiCert Global CA G2, O=DigiCert Inc, C=US 
    .EXAMPLE
        PS C:\> 'amazon.com' | Get-RemoteCertificate | Format-List *
        
        DnsNameList          : {amazon.co.uk, uedata.amazon.co.uk, www.amazon.co.uk, origin-www.amazon.co.uk...}
        EnhancedKeyUsageList : {Server Authentication (1.3.6.1.5.5.7.3.1), Client Authentication (1.3.6.1.5.5.7.3.2)}
        Url                  : amazon.com
        Protocollist         : {tls, tls11, tls12}
        DaysRemaining        : 234
        Archived             : False
        Extensions           : {System.Security.Cryptography.Oid, System.Security.Cryptography.Oid, System.Security.Cryptography.Oid, System.Security.Cryptography.Oid...}
        FriendlyName         : 
        IssuerName           : System.Security.Cryptography.X509Certificates.X500DistinguishedName
        NotAfter             : 1/7/2025 5:59:59 PM
        NotBefore            : 2/1/2024 6:00:00 PM
        HasPrivateKey        : False
        PrivateKey           : 
        PublicKey            : System.Security.Cryptography.X509Certificates.PublicKey
        RawData              : {48, 130, 10, 61...}
        SerialNumber         : 0EDB97391CB586451865E838F9F52971
        SubjectName          : System.Security.Cryptography.X509Certificates.X500DistinguishedName
        SignatureAlgorithm   : System.Security.Cryptography.Oid
        Thumbprint           : E60BE059BC69086866C764508627B11FB186BA62
        Version              : 3
        Handle               : 2813966604912
        Issuer               : CN=DigiCert Global CA G2, O=DigiCert Inc, C=US
        Subject              : CN=*.peg.a2z.com
    .EXAMPLE
        PS C:\> $cert = 'godaddy.com' | Get-RemoteCertificate
        PS C:\> $cert.DnsNameList

        Punycode        Unicode
        --------        -------
        godaddy.com     godaddy.com
        www.godaddy.com www.godaddy.com 
    .EXAMPLE
        PS C:\> 'cnn.com' | Get-RemoteCertificate | Get-Member -Static

           TypeName: System.Security.Cryptography.X509Certificates.X509Certificate2+CustomFormat
        
        Name                 MemberType Definition
        ----                 ---------- ----------
        CreateFromCertFile   Method     static X509Certificate CreateFromCertFile(string filename)
        CreateFromSignedFile Method     static X509Certificate CreateFromSignedFile(string filename)
        Equals               Method     static bool Equals(System.Object objA, System.Object objB)
        GetCertContentType   Method     static System.Security.Cryptography.X509Certificates.X509ContentType GetCertContentType(byte[] rawData), static System.Security.Cryptography.X509Certificates.X509ContentType GetCertContentType(...
        new                  Method     System.Security.Cryptography.X509Certificates.X509Certificate2 new(), System.Security.Cryptography.X509Certificates.X509Certificate2 new(byte[] rawData), System.Security.Cryptography.X509Certif...
        ReferenceEquals      Method     static bool ReferenceEquals(System.Object objA, System.Object objB)
    .INPUTS
        String
        Uri
    .OUTPUTS
        System.Security.Cryptography.X509Certificates.X509Certificate2
    .NOTES
        Used for monitoring certificates to prevent expiration
    #>

    [CmdletBinding()]
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2])]
    param (
        [Parameter(Mandatory,ValueFromPipelineByPropertyName,ValueFromPipeline)]
        [ValidateNotNull()]
        [Alias('Uri','Site','Url','Host')]
        [String[]]$HostName,
        [Parameter(ValueFromPipelineByPropertyName)]
        [UInt16]$Port = 443
    )

    begin{
        $TypeName = 'System.Security.Cryptography.X509Certificates.X509Certificate2+CustomFormat'
        $defaultDisplaySet = 'Url', 'Subject', 'NotAfter', 'Issuer'
        Update-TypeData -TypeName $TypeName -DefaultDisplayPropertySet $defaultDisplaySet -Force
    }

    process {
        $ErrorActionPreference = 'Stop'
        
        foreach($site in $HostName){
            try {
                $output = "ssl2", "ssl3", "tls", "tls11", "tls12" | %{
                    $TcpClient = New-Object Net.Sockets.TcpClient
                    $TcpClient.Connect($site, $Port)
                    $SslStream = New-Object Net.Security.SslStream $TcpClient.GetStream(),
                        $true,
                        ([System.Net.Security.RemoteCertificateValidationCallback]{ $true })
                    $SslStream.ReadTimeout = 15000
                    $SslStream.WriteTimeout = 15000
                    try {
                        $SslStream = [System.Net.Security.SslStream]::new(
                            $TcpClient.GetStream(),
                            $True,
                            [System.Net.Security.RemoteCertificateValidationCallback]{$true}
                        )
                        $SslStream.AuthenticateAsClient($site,$null,$_,$false)
                        $cert = New-Object system.security.cryptography.x509certificates.x509certificate2($sslStream.RemoteCertificate)
                        $cert.psobject.TypeNames.Insert(0,$TypeName)
                        $null = $cert.psobject.TypeNames.Remove('System.Security.Cryptography.X509Certificates.X509Certificate2')
                        $cert | Add-Member -MemberType ScriptProperty -Name DnsNameList -Value {(new-object Microsoft.Powershell.Commands.DnsNameProperty -argumentlist $this).DnsNameList} -Force
                        $cert | Add-Member -MemberType ScriptProperty -Name EnhancedKeyUsageList -Value {(new-object Microsoft.Powershell.Commands.EnhancedKeyUsageProperty -argumentlist $this).EnhancedKeyUsageList} -Force
                        $cert | Add-Member -NotePropertyName Url -NotePropertyValue $site -Force
                        $cert | Add-Member -NotePropertyName Protocollist -NotePropertyValue $_ -Force
                        $cert | Add-Member -NotePropertyName DaysRemaining -NotePropertyValue $certExpiresIn -PassThru -Force
    
                    }
                    catch {}
                }

                $output | Group-Object | ForEach-Object {
                    $obj = $_.Group[0]
                    $obj.protocollist = $_.Group.protocollist
                    $obj
                }

                if($SslStream){
                    $SslStream.Dispose()
                }
            }
            catch {
                Write-Warning $_.exception.message
            }
            finally {
                if($TcpClient){
                    $TcpClient.Dispose()
                }
            }
        }
    }
}
