Function Get-IPConfig {
    (ipconfig /all| Out-String) -split '(?s)\r?\n(?=\w.+)' | Where-Object {$_} | ForEach-Object {

        $ht = $null

        switch -Regex ($_ -split '\r?\n') {

            '(^\w[^:]+)$' {
                $first = $true
                $ht = [ordered]@{}
            }

            '^(Wireless Lan Adapter|Ethernet Adapter)\s(\w[^:]+):$' {
                $ht = [ordered]@{
                    NicName = $matches.2
                    NicType = $matches.1
                }
            }

            '^\s{2,}(\w.+\. :.*)$' {,($matches.1 -split '[\.\s]+:\s*|\s$')| ForEach-Object {
                    if($ht[$_[0]]){
                        $ht[$_[0]] = $ht[$_[0]],$_[1] -join ', '
                    }
                    else{
                        $ht.add($_[0],$_[1])
                    }
                }
            }
        }

        if($first){
            $copy = $ht.keys | ForEach-Object {@{$_ = $ht.$_}}
            $first = $false
        }
        else{
            $copy.Keys | ForEach-Object {$ht.add($_,$copy.$_)}
            [PSCustomObject]$ht
        }
    }
}
