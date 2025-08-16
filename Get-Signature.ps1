Function Get-Signature {
<#
    .SYNOPSIS
    Function to retrieve signing details of a file, including the certificates used to sign.
    .NOTES
    Has external dependency on sysinternals sigcheck.exe
    .EXAMPLE
    Get-Signature C:\Windows\Boot\EFI\bootmgfw.efi

    File            : C:\Windows\Boot\EFI\bootmgfw.efi
    Verified        : Signed
    Link date       : 4:04 AM 9/25/1990
    Signing date    : 10:44 PM 4/12/2024
    Catalog         : c:\windows\boot\efi\bootmgfw.efi
    Signers         : {@{Name=Microsoft Windows; Cert Status=Valid; Valid Usage=NT5 Crypto, Code Signing; Cert Issuer=Microsoft Windows Production PCA 2011;
                      Serial Number=33 00 00 04 5F F3 C9 6C 1A 7F F7 DA 1D 00 00 00 00 04 5F; Thumbprint=71F53A26BB1625E466727183409A30D03D7923DF; Algorithm=sha256RSA;
                      Valid from=2:20 PM 11/16/2023; Valid to=2:20 PM 11/14/2024}, @{Name=Microsoft Windows Production PCA 2011; Cert Status=Valid; Valid Usage=All;
                      Cert Issuer=Microsoft Root Certificate Authority 2010; Serial Number=61 07 76 56 00 00 00 00 00 08;
                      Thumbprint=580A6F4CC4E4B669B9EBDC1B2B3E087B80D0678D; Algorithm=sha256RSA; Valid from=1:41 PM 10/19/2011; Valid to=1:51 PM 10/19/2026},
                      @{Name=Microsoft Root Certificate Authority 2010; Cert Status=Valid; Valid Usage=All; Cert Issuer=Microsoft Root Certificate Authority 2010;
                      Serial Number=28 CC 3A 25 BF BA 44 AC 44 9A 9B 58 6B 43 39 AA; Thumbprint=3B1EFD3A66EA28B16697394703A72CA340A05BD5; Algorithm=sha256RSA;
                      Valid from=4:57 PM 6/23/2010; Valid to=5:04 PM 6/23/2035}}
    Counter Signers : {@{Name=Microsoft Time-Stamp Service; Cert Status=Valid; Valid Usage=Timestamp Signing; Cert Issuer=Microsoft Time-Stamp PCA 2010;
                      Serial Number=33 00 00 01 E2 99 99 95 F1 DC E3 20 EB 00 01 00 00 01 E2; Thumbprint=169B9969FA746E7A4974885F881D5DF294E8866F; Algorithm=sha256RSA;
                      Valid from=2:07 PM 10/12/2023; Valid to=2:07 PM 1/10/2025}, @{Name=Microsoft Time-Stamp PCA 2010; Cert Status=Valid;
                      Valid Usage=Timestamp Signing; Cert Issuer=Microsoft Root Certificate Authority 2010;
                      Serial Number=33 00 00 00 15 C5 E7 6B 9E 02 9B 49 99 00 00 00 00 00 15; Thumbprint=36056A5662DCADECF82CC14C8B80EC5E0BCC59A6; Algorithm=sha256RSA;
                      Valid from=1:22 PM 9/30/2021; Valid to=1:32 PM 9/30/2030}, @{Name=Microsoft Root Certificate Authority 2010; Cert Status=Valid;
                      Valid Usage=All; Cert Issuer=Microsoft Root Certificate Authority 2010; Serial Number=28 CC 3A 25 BF BA 44 AC 44 9A 9B 58 6B 43 39 AA; 
                      Thumbprint=3B1EFD3A66EA28B16697394703A72CA340A05BD5; Algorithm=sha256RSA; Valid from=4:57 PM 6/23/2010; Valid to=5:04 PM 6/23/2035}}
    Company         : Microsoft Corporation
    Description     : Boot Manager
    Product         : Microsoft® Windows® Operating System
    Prod version    : 10.0.19041.4355
    File version    : 10.0.19041.4355 (WinBuild.160101.0800)
    MachineType     : 64-bit
    .EXAMPLE
    $signing = Get-Item C:\Windows\Boot\EFI\bootmgfw.efi | Get-Signature

    $signing.Signers

    Name          : Microsoft Windows
    Cert Status   : Valid
    Valid Usage   : NT5 Crypto, Code Signing
    Cert Issuer   : Microsoft Windows Production PCA 2011
    Serial Number : 33 00 00 04 5F F3 C9 6C 1A 7F F7 DA 1D 00 00 00 00 04 5F
    Thumbprint    : 71F53A26BB1625E466727183409A30D03D7923DF
    Algorithm     : sha256RSA
    Valid from    : 2:20 PM 11/16/2023
    Valid to      : 2:20 PM 11/14/2024

    Name          : Microsoft Windows Production PCA 2011
    Cert Status   : Valid
    Valid Usage   : All
    Cert Issuer   : Microsoft Root Certificate Authority 2010
    Serial Number : 61 07 76 56 00 00 00 00 00 08
    Thumbprint    : 580A6F4CC4E4B669B9EBDC1B2B3E087B80D0678D
    Algorithm     : sha256RSA
    Valid from    : 1:41 PM 10/19/2011
    Valid to      : 1:51 PM 10/19/2026

    Name          : Microsoft Root Certificate Authority 2010
    Cert Status   : Valid
    Valid Usage   : All
    Cert Issuer   : Microsoft Root Certificate Authority 2010
    Serial Number : 28 CC 3A 25 BF BA 44 AC 44 9A 9B 58 6B 43 39 AA
    Thumbprint    : 3B1EFD3A66EA28B16697394703A72CA340A05BD5
    Algorithm     : sha256RSA
    Valid from    : 4:57 PM 6/23/2010
    Valid to      : 5:04 PM 6/23/2035
    .EXAMPLE
    Get-ChildItem c:\windows\boot\efi -Recurse *.efi | Get-Signature | Format-Table File, Verified, 'Signing Date', Catalog

    File                                       Verified Signing date       Catalog                                   
    ----                                       -------- ------------       -------                                   
    C:\windows\boot\efi\bootmgfw.efi           Signed   10:44 PM 4/12/2024 c:\windows\boot\efi\bootmgfw.efi          
    C:\windows\boot\efi\bootmgr.efi            Signed   10:43 PM 4/12/2024 c:\windows\boot\efi\bootmgr.efi           
    C:\windows\boot\efi\memtest.efi            Signed   12:53 AM 4/5/2024  c:\windows\boot\efi\memtest.efi           
    C:\windows\boot\efi\SecureBootRecovery.efi Signed   2:50 AM 3/22/2024  c:\windows\boot\efi\SecureBootRecovery.efi

#>

    [cmdletbinding()]
    Param(
        [parameter(Mandatory,ValueFromPipeline)]
        [System.IO.FileInfo[]]$Path
    )

    begin{
        $ErrorActionPreference = 'Stop'

        $sigcheck = (Get-Command sigcheck.exe -ErrorAction SilentlyContinue).Path

        if(-not $sigcheck){
            $sigcheck = Join-Path $env:TEMP sigcheck.exe
        }

        if(-not (Test-Path $sigcheck)){
            try{
                Invoke-RestMethod -Uri https://live.sysinternals.com/tools/sigcheck.exe -OutFile $sigcheck -UseBasicParsing -ErrorAction Stop
            }
            catch{
                Write-Warning "Error downloading sigcheck.exe: $($_.exception.message)"
                break    
            }
        }
    }
    process{
        foreach($file in $Path){
            try{
                $output = & $sigcheck -nobanner -accepteula -i $file.FullName
            }
            catch{
                Write-Warning "Error running sigcheck.exe: $($_.exception.message)"
                break
            }

            Remove-Variable -Name ht, prop, values -ErrorAction SilentlyContinue

            $ht = [ordered]@{
                File = $file.FullName
            }

            switch -Regex ($output){
                '^\t(?<Property>\S.+?):\s+?(?<Value>.+?)$' {
                    if($values.Keys.Count -gt 7){
                        $ht[$prop].Add([pscustomobject]$values)
                        $values = $null
                    }
                    $ht[$matches.property] = $matches.value
                }
                '^\t(?<Property>\w.+?):$' {
                    if($values.Keys.Count -gt 7){
                        $ht[$prop].Add([pscustomobject]$values)
                        $values = $null
                    }
                    $prop = $matches.Property
                    $ht[$prop] = [System.Collections.Generic.List[object]]::new()
                    $values = [ordered]@{}
                }
                '^\t\s+(?<Value>\w[^:]+?)$' {
                    if($values.Keys.Count -gt 7){
                        $ht[$prop].Add([pscustomobject]$values)
                        $values = [ordered]@{}
                    }
                    $values['Name'] = $matches.value
                }
                '^\t\s+(?<Property>\S.+?):\s+?(?<Value>.+?)$'  {
                    $values[$matches.property] = $matches.value
                }
            }

            [PSCustomObject]$ht
        }
    }
}
