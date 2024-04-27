function Get-RemoteCertificate {
    <#
    .SYNOPSIS
        Retrieve SSL certificate
    .DESCRIPTION
        Retrieve SSL certificate from HTTPS site
    .EXAMPLE
        PS C:\> Get-RemoteCertificate -Url https://www.microsoft.com | Select-Object -Property *
        
        DnsNameList          : {wwwqa.microsoft.com, www.microsoft.com, staticview.microsoft.com, i.s-microsoft.com...}
        EnhancedKeyUsageList : {Client Authentication (1.3.6.1.5.5.7.3.2), Server Authentication (1.3.6.1.5.5.7.3.1)}
        Url                  : https://www.microsoft.com/
        DaysRemaining        :
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
        Handle               : 2448969317088
        Issuer               : CN=Microsoft Azure RSA TLS Issuing CA 07, O=Microsoft Corporation, C=US
        Subject              : CN=www.microsoft.com, O=Microsoft Corporation, L=Redmond, S=WA, C=US
    .EXAMPLE
        PS C:\> Get-RemoteCertificate bing.com,powershell.org,amazon.com
        
        Url                     Subject                                                         NotAfter             Issuer
        ---                     -------                                                         --------             ------
        https://bing.com/       CN=www.bing.com, O=Microsoft Corporation, L=Redmond, S=WA, C=US 1/22/2024 5:57:23 PM CN=Microsoft Azure TLS Issuing CA 05, O=Microsoft Corporation, C=US
        https://powershell.org/ CN=powershell.org                                               1/4/2024 4:29:24 AM  CN=GTS CA 1P5, O=Google Trust Services LLC, C=US
        https://amazon.com/     CN=*.peg.a2z.com                                                3/22/2024 6:59:59 PM CN=DigiCert Global CA G2, O=DigiCert Inc, C=US
    .EXAMPLE
        PS C:\> 'msn.com','google.com' | Get-RemoteCertificate
        
        Url                 Subject                                                      NotAfter               Issuer
        ---                 -------                                                      --------               ------
        https://msn.com/    CN=*.msn.com, O=Microsoft Corporation, L=Redmond, S=WA, C=US 6/27/2024 6:59:59 PM   CN=Microsoft Azure TLS Issuing CA 05, O=Microsoft Corporation, C=US
        https://google.com/ CN=*.google.com                                              12/20/2023 11:26:20 PM CN=GTS CA 1C3, O=Google Trust Services LLC, C=US
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
        [Parameter(Mandatory,ValueFromPipeline)]
        [ValidateNotNull()]
        [Alias('Url','Site')]
        [Uri[]]$Uri
    )

    begin{
        $TypeName = 'System.Security.Cryptography.X509Certificates.X509Certificate2+CustomFormat'
        $defaultDisplaySet = 'Url', 'Subject', 'NotAfter', 'Issuer'
        Update-TypeData -TypeName $TypeName -DefaultDisplayPropertySet $defaultDisplaySet -Force
    }

    process {
        $ErrorActionPreference = 'Stop'
        
        foreach($site in $Uri){
            try {
                if($site.OriginalString -notmatch '^https://'){[Uri]$site = "https://$site"}
    
                $TcpClient = [System.Net.Sockets.TcpClient]::new($site.Host, $site.Port)
    
                try {
                    $SslStream = [System.Net.Security.SslStream]::new(
                        $TcpClient.GetStream(),
                        $True,
                        [System.Net.Security.RemoteCertificateValidationCallback]{$true}
                    )
                    $SslStream.AuthenticateAsClient($site.Host)
                    $cert = New-Object system.security.cryptography.x509certificates.x509certificate2($sslStream.RemoteCertificate)
                    $cert.psobject.TypeNames.Insert(0,$TypeName)
                    $null = $cert.psobject.TypeNames.Remove('System.Security.Cryptography.X509Certificates.X509Certificate2')
                    $cert | Add-Member -MemberType ScriptProperty -Name DnsNameList -Value {(new-object Microsoft.Powershell.Commands.DnsNameProperty -argumentlist $this).DnsNameList} -Force
                    $cert | Add-Member -MemberType ScriptProperty -Name EnhancedKeyUsageList -Value {(new-object Microsoft.Powershell.Commands.EnhancedKeyUsageProperty -argumentlist $this).EnhancedKeyUsageList} -Force
                    $cert | Add-Member -NotePropertyName Url -NotePropertyValue $site -Force
                    $cert | Add-Member -NotePropertyName DaysRemaining -NotePropertyValue $certExpiresIn -PassThru -Force
    
                }
                catch {
                    Write-Warning $_.exception.message
                }
                finally {
                    if($SslStream){
                        $SslStream.Dispose()
                    }
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
