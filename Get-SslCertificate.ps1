function Get-SslCertificate {
    <#
    .SYNOPSIS
        Retrieve SSL certificate
    .DESCRIPTION
        Retrieve SSL cert from HTTPS site
    .EXAMPLE
        PS C:\> Get-SslCertificate -Url https://www.microsoft.com

        Name       : C=US, S=WA, L=Redmond, O=Microsoft Corporation, OU=Microsoft Corporation, CN=www.microsoft.com
        Subject    : CN=www.microsoft.com, OU=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=WA, C=US
        Issuer     : C=US, O=Microsoft Corporation, CN=Microsoft RSA TLS CA 01
        ValidFrom  : 7/28/2021 4:22:06 PM
        Expiration : 7/28/2022 4:22:06 PM
        Thumbprint : B5BC7B1FD96BE16E49CB61354824CF4259A2BE75
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

            $certEffectiveDate = [datetime]::ParseExact(($effectiveDate -replace ' (PM|AM)'), “M/d/yyyy H:mm:ss”, $null)
        
            if($effectiveDate -match 'PM$'){
                $certEffectiveDate = $certEffectiveDate.AddHours(12)
            }
        
            $expDate = $req.ServicePoint.Certificate.GetExpirationDateString()

            $certExpDate = [datetime]::ParseExact(($expDate -replace ' (PM|AM)'), “M/d/yyyy H:mm:ss”, $null)
        
            if($expDate -match 'PM$'){
                $certExpDate = $certExpDate.AddHours(12)
            }
        
            [int]$certExpiresIn = ($certExpDate - (get-date)).Days
        
            if ($certExpiresIn -lt $minCertAge){
                if($certExpiresIn -lt 0){
                    Write-Host "EXPIRED: The certificate for $site expired $($certExpiresIn * -1) days ago" -ForegroundColor Red
                }
                else{
                    Write-Warning "The certificate for $site expires in $certExpiresIn days"
                }
            }
        
            [PSCustomObject]@{
                Url        = $site
                Name       = $req.ServicePoint.Certificate.GetName()
                Subject    = $req.ServicePoint.Certificate.subject
                Issuer     = $req.ServicePoint.Certificate.GetIssuerName()
                ValidFrom  = $certEffectiveDate
                Expiration = $certExpDate
                Thumbprint = $certThumbprint
            }
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
