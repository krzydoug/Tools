Function Convert-PFXtoBase64 {

    <#
    .Synopsis
        Converts PKCS12 (.p12/.pfx) certificate to base64 encoded string
    .Description
        Converts PKCS12 (.p12/.pfx) certificate to base64 encoded string.
    .Parameter Path
        Mandatory path to the certificate file
    .Parameter Out-File
        Optional file to output the result to
    .Example
        Convert-PFXtoBase64 -Path .\SSL_Cert.pfx -OutFile .\SSL_base64.txt
    .Example
        Get-ChildItem .\SSL_Cert.pfx | Convert-PFXtoBase64
    #>

    [cmdletbinding()]
    Param(
        [parameter(Position=0,Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName,HelpMessage="Enter the full path to the certificate")]
        [string]
        $Path,

        [parameter(Position=1,HelpMessage="Enter the full path to the desired output file")]
        [string]
        $OutFile
    )

    begin{
        $template = @'
-----BEGIN PKCS12-----
{0}
-----END PKCS12-----
'@
    }

    process{
        try{
            $bytearray = Get-Content -LiteralPath $Path -Encoding Byte -Raw
            $encodedstring = $template -f ([System.Convert]::ToBase64String($bytearray) -split '(.{64})' -ne '' -join "`r`n")
        }
        catch{
            Write-Warning $_.exception.message
        }

        if($OutFile){
            $encodedstring | Set-Content -LiteralPath $OutFile -Encoding UTF8
        }
        else{
            $encodedstring
        }
    }
}
