function Get-SslCertificate {
    <#
    .SYNOPSIS
        Retrieve SSL certificate
    .DESCRIPTION
        Retrieve SSL cert from HTTPS site
    .EXAMPLE
        PS C:\> Get-SslCertificate -Url https://www.microsoft.com | Select-Object -Property *
        
        URL            : https://www.microsoft.com
        Name           : C=US, S=WA, L=Redmond, O=Microsoft Corporation, CN=www.microsoft.com
        Subject        : CN=www.microsoft.com, O=Microsoft Corporation, L=Redmond, S=WA, C=US
        Issuer         : C=US, O=Microsoft Corporation, CN=Microsoft RSA TLS CA 01
        ValidFrom      : 7/8/2022 1:22:47 PM
        Expiration     : 7/8/2023 1:22:47 PM
        DaysRemaining  : 308
        Thumbprint     : 7625E4F156DB2797A134EC418359F6D9FEDDB925
        RawCertificate : System.Security.Cryptography.X509Certificates.X509Certificate
    .EXAMPLE
        PS C:\> 'msn.com','google.com' | Get-SslCertificate
        
        WARNING: The https://google.com certificate expires in 65 days
        
        Url                Subject         Expiration            Issuer
        ---                -------         ----------            ------
        https://msn.com    CN=*.msn.com    9/28/2022 12:11:31 AM C=US, O=Microsoft Corporation, CN=Microsoft RSA TLS CA 02
        https://google.com CN=*.google.com 11/7/2022 2:17:54 AM  C=US, O=Google Trust Services LLC, CN=GTS CA 1C3
    .EXAMPLE
        PS C:\> Get-SslCertificate bing.com,powershell.org,amazon.com | Select-Object -ExpandProperty RawCertificate
        
               Handle Issuer                                                    Subject                                                                            
               ------ ------                                                    -------                                                                            
        1765019620096 CN=Microsoft RSA TLS CA 01, O=Microsoft Corporation, C=US CN=www.bing.com                                                                    
        1765019619200 CN=Cloudflare Inc ECC CA-3, O="Cloudflare, Inc.", C=US    CN=sni.cloudflaressl.com, O="Cloudflare, Inc.", L=San Francisco, S=California, C=US
        1765019624704 CN=DigiCert Global CA G2, O=DigiCert Inc, C=US            CN=*.peg.a2z.com 
    .INPUTS
        String
    .OUTPUTS
        PSCustomObject
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
        $TypeName = 'SCS.Certificate'
        $defaultDisplaySet = 'Url', 'Subject', 'Expiration', 'Issuer'
        $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet',[string[]]$defaultDisplaySet)
        $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
        
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
        
            $certThumbprint = $req.ServicePoint.Certificate.GetCertHashString()
        
            $effectiveDate = $req.ServicePoint.Certificate.GetEffectiveDateString()

            $certEffectiveDate = [datetime]::ParseExact(($effectiveDate -replace ' (PM|AM)'), "M/d/yyyy H:mm:ss", $null)
        
            if($effectiveDate -match 'PM$'){
                $certEffectiveDate = $certEffectiveDate.AddHours(12)
            }
        
            $expDate = $req.ServicePoint.Certificate.GetExpirationDateString()

            $certExpDate = [datetime]::ParseExact(($expDate -replace ' (PM|AM)'), "M/d/yyyy H:mm:ss", $null)
        
            if($expDate -match 'PM$'){
                $certExpDate = $certExpDate.AddHours(12)
            }
        
            [int]$certExpiresIn = ($certExpDate - (get-date)).Days
        
            if ($certExpiresIn -lt $minCertAge){
                Write-Warning "The $site certificate expires in $certExpiresIn days"
            }

            [PSCustomObject]@{
                URL            = $site
                Name           = $req.ServicePoint.Certificate.GetName()
                Subject        = $req.ServicePoint.Certificate.subject
                Issuer         = $req.ServicePoint.Certificate.GetIssuerName()
                ValidFrom      = $certEffectiveDate
                Expiration     = $certExpDate
                DaysRemaining  = $certExpiresIn
                Thumbprint     = $certThumbprint
                RawCertificate = $req.ServicePoint.Certificate
            } | Add-Member MemberSet PSStandardMembers $PSStandardMembers -PassThru

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
    
    end {
        
    }
}
