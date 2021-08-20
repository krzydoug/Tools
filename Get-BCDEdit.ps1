#requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

try{
    $result = bcdedit /V | where {$_ -match "^[^-|^ ]"}
    
    if(!$?){
        Write-Warning "BCD command failed. Are you running as admin?"
    }

    $result | ForEach-Object -Begin {$props = $null} -Process {
        $key,$value = $_.Split(' ',2).trim()
        if($key -eq 'Windows')
        {
            if($props.keys.Count -gt 0)
            {
                [pscustomobject]$props
            }
            $props = [ordered]@{}
            $props.Add("BCD Entry",$value)
        }
        else
        {
            $props.Add($key,$value)
        }
    } -End {[pscustomobject]$props} -OutVariable bcd
}
catch{
    Write-Warning "Error getting BCD info: $($result)"
}
