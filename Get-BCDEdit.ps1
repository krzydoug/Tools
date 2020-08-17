bcdedit /V | where {$_ -match "^[^-]"}| 
    foreach -Begin {$props = $null} -Process {
        $a,$b = $_.Split(' ',2).trim()
        if($a -eq 'Windows')
        {
            if($props.keys.Count -gt 0)
            {
                [pscustomobject]$props
            }
            $props = [ordered]@{}
            $props.Add("BCD Entry",$b)
        }
        else
        {
            $props.Add($a,$b)
        }
    } -End {[pscustomobject]$props} -OutVariable bcd
