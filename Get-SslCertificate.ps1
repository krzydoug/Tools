function Get-SslCertificate {
    <#
    .SYNOPSIS
        Retrieve SSL certificate
    .DESCRIPTION
        Retrieve SSL cert from HTTPS site
    .EXAMPLE
        PS C:\> Get-SslCertificate -Url https://www.microsoft.com | Select-Object -Property *
        
        Url                : https://www.microsoft.com
        DaysRemaining      : 324
        Archived           : False
        Extensions         : {System.Security.Cryptography.Oid, System.Security.Cryptography.Oid, System.Security.Cryptography.Oid, System.Security.Cryptography.Oid...}
        FriendlyName       : 
        IssuerName         : System.Security.Cryptography.X509Certificates.X500DistinguishedName
        NotAfter           : 9/29/2023 6:23:11 PM
        NotBefore          : 10/4/2022 6:23:11 PM
        HasPrivateKey      : False
        PrivateKey         : 
        PublicKey          : System.Security.Cryptography.X509Certificates.PublicKey
        RawData            : {48, 130, 8, 214...}
        SerialNumber       : 330059F8B6DA8689706FFA1BD900000059F8B6
        SubjectName        : System.Security.Cryptography.X509Certificates.X500DistinguishedName
        SignatureAlgorithm : System.Security.Cryptography.Oid
        Thumbprint         : 2D6E2AE5B36F22076A197D50009DEE66396AA99C
        Version            : 3
        Handle             : 2160281246848
        Issuer             : CN=Microsoft Azure TLS Issuing CA 06, O=Microsoft Corporation, C=US
        Subject            : CN=www.microsoft.com, O=Microsoft Corporation, L=Redmond, S=WA, C=US
    .EXAMPLE
        PS C:\> Get-SslCertificate bing.com,powershell.org,amazon.com
        
        Url                    Subject                                                         NotAfter             Issuer                                       
        ---                    -------                                                         --------             ------                                       
        https://bing.com       CN=www.bing.com                                                 3/2/2023 7:06:28 PM  CN=Microsoft RSA TLS CA 02, O=Microsoft Co...
        https://powershell.org CN=sni.cloudflaressl.com, O="Cloudflare, Inc.", L=San Francisco 7/10/2023 6:59:59 PM CN=Cloudflare Inc ECC CA-3, O="Cloudflare,...
        https://amazon.com     CN=*.peg.a2z.com                                                10/18/2023 6:59:5... CN=DigiCert Global CA G2, O=DigiCert Inc, ...
    .EXAMPLE
        PS C:\> 'msn.com','google.com' | Get-SslCertificate
        
        WARNING: The https://google.com certificate expires in 68 days

        Url                Subject                                                      NotAfter              Issuer                                                             
        ---                -------                                                      --------              ------                                                             
        https://msn.com    CN=*.msn.com, O=Microsoft Corporation, L=Redmond, S=WA, C=US 9/9/2023 12:17:40 PM  CN=Microsoft Azure TLS Issuing CA 01, O=Microsoft Corporation, C=US
        https://google.com CN=*.google.com                                              1/17/2023 12:13:28 PM CN=GTS CA 1C3, O=Google Trust Services LLC, C=US                                                                        10/18/2023 6:59:5... CN=DigiCert Global CA G2, O=DigiCert Inc, ...
    .EXAMPLE
        PS C:\> $cert = 'godaddy.com' | Get-SslCertificate
        PS C:\> $cert.DnsNameList

        Punycode      Unicode      
        --------      -------      
        *.godaddy.com *.godaddy.com
        godaddy.com   godaddy.com  
    .EXAMPLE
        PS C:\> 'cnn.com' | Get-SslCertificate | Get-Member -Static

           TypeName: System.Security.Cryptography.X509Certificates.X509Certificate2

        Name                 MemberType Definition                                                                                                                                   
        ----                 ---------- ----------                                                                                                                                   
        CreateFromCertFile   Method     static X509Certificate CreateFromCertFile(string filename)                                                                                   
        CreateFromSignedFile Method     static X509Certificate CreateFromSignedFile(string filename)                                                                                 
        Equals               Method     static bool Equals(System.Object objA, System.Object objB)                                                                                   
        GetCertContentType   Method     static System.Security.Cryptography.X509Certificates.X509ContentType GetCertContentType(byte[] rawData), static System.Security.Cryptograp...
        new                  Method     System.Security.Cryptography.X509Certificates.X509Certificate2 new(), System.Security.Cryptography.X509Certificates.X509Certificate2 new(b...
        ReferenceEquals      Method     static bool ReferenceEquals(System.Object objA, System.Object objB)   
    .INPUTS
        String
    .OUTPUTS
        System.Security.Cryptography.X509Certificates.X509Certificate2+CustomFormat
    .NOTES
        Used for monitoring certificates to prevent expiration
    #>

    [CmdletBinding()]
    param (
        [parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName,Position=0)]
        [Alias('Site','Website','Host','FQDN')]
        [string[]]$Url,
        
        [parameter(Position=1,HelpMessage='The time in milliseconds before the attempt times out')]
        [int]$Timeout = 10000
    )
    
    begin {
        $TypeName = 'System.Security.Cryptography.X509Certificates.X509Certificate2+CustomFormat'
        $defaultDisplaySet = 'Url', 'Subject', 'NotAfter', 'Issuer'
        Update-TypeData -TypeName $TypeName -DefaultDisplayPropertySet $defaultDisplaySet -Force
        
        $script = {
            Param($site,$timeout)

            # Disable certificate validation
            [Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

            $minCertAge = 90

            if($site -notmatch '^https://'){
                $site = "https://$site"
            }

            Write-Verbose "Retrieving certificate from $site"

            try{
                $req = [Net.HttpWebRequest]::Create($site)
                $req.Headers["UserAgent"] = [Microsoft.PowerShell.Commands.PSUserAgent]::Chrome
                $req.AllowAutoRedirect = $false
            }
            catch{
                Write-Warning $_.Exception.Message
                continue
            }

            $req.Timeout = $timeout

            try {
                $null = $req.GetResponse()
            }
            catch{
                Write-Warning "URL check error $($site): $($_.exception.message)"
                continue
            }

            [int]$certExpiresIn = ([datetime]$req.ServicePoint.Certificate.GetExpirationDateString() - (get-date)).Days
        
            if ($certExpiresIn -lt $minCertAge){
                Write-Warning "The $site certificate expires in $certExpiresIn days"
            }

            $obj = New-Object system.security.cryptography.x509certificates.x509certificate2($req.ServicePoint.Certificate)
            $obj.psobject.TypeNames.Insert(0,$TypeName)
            $null = $obj.psobject.TypeNames.Remove('System.Security.Cryptography.X509Certificates.X509Certificate2')
            $obj | Add-Member -MemberType ScriptProperty -Name DnsNameList -Value {(new-object Microsoft.Powershell.Commands.DnsNameProperty -argumentlist $this).DnsNameList}
            $obj | Add-Member -MemberType ScriptProperty -Name EnhancedKeyUsageList -Value {(new-object Microsoft.Powershell.Commands.EnhancedKeyUsageProperty -argumentlist $this).EnhancedKeyUsageList}
            $obj | Add-Member -NotePropertyName Url -NotePropertyValue $site
            $obj | Add-Member -NotePropertyName DaysRemaining -NotePropertyValue $certExpiresIn -PassThru
        }
    }
    
    process {
        foreach ($site in $Url){
            if($PSVersionTable.PSEdition -eq 'Core'){
                powershell.exe -nologo -noprofile -executionpolicy bypass -command $script -args $site,$timeout
            }
            else{
                . $script $site 10000
            }
        }
    }
    
}
