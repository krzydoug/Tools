Function Get-AuditPolicyConfiguration {
    [cmdletbinding()]
    Param(
        [parameter()]
        [ValidateSet('Text', 'Json', 'PSCustomObject')]
        $OutputMode = 'PSCustomObject'
    )

    $auditconfig = auditpol /get /category:* | Select-Object -Skip 3

    $ht = [ordered]@{}

    switch -Regex ($auditconfig) {
        '^(\w.+)' {
            $current = $Matches.1
            $ht.$current = [ordered]@{}
        }

        '^\s+(.+?)\s{2,}(.+)' {
            $ht."$($current)"."$($matches.1)" = $Matches.2
        }
    }

    switch ($OutputMode){
        Text {$auditconfig}
        Json {$ht | ConvertTo-Json}
        default {[PSCustomObject]$ht}
    }
}
