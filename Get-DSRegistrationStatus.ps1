Function Get-DSRegistrationStatus {
    [cmdletbinding()]
    Param(
        [validateset('Json','PSCustomObject','List')]
        $OutputType = 'PSCustomObject'
    )

    begin {
        $text = dsregcmd /status | Out-String
        $ht = [ordered]@{}
    }

    process {
        $text -split '(?s)\r?\n[\s]+\+-+\+\r?\n\|' | ForEach-Object {
            if($_  -match '(?s)\s?([\w\s]+?)(?=\s{2,})(.+)'){
                $prop = $matches.1
                $ht.$prop = [ordered]@{}
                switch -Regex ($matches.2 -split '\r?\n'){
                    ':' {$ht.$prop += $_ -replace ':','=' -replace '\\','\\' | ConvertFrom-StringData}
                }
                $ht.$prop = [PSCustomObject]$ht.$prop
            }
        }

        $obj = [pscustomobject]$ht

        switch($OutputType){
            json {$obj | ConvertTo-Json -Depth 4}
            pscustomobject {$obj}
            list {
                Write-Host `n -NoNewline
                $props = $obj.psobject.properties.name
                $propline = @{
                    Object = "------------------ $prop ------------------"
                }
                if($PSVersionTable.PSVersion.Major -le 5){
                    $propline.Add('NoNewLine',$true)
                }
                foreach($prop in $props){
                    Write-Host @propline
                    $obj.$prop | Format-List
                }
            }
        }
    }
}
