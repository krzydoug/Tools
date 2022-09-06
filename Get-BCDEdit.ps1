function Get-BCDEdit {
    [cmdletbinding()]
    Param(
        [parameter()]
        [ValidateSet('Enum','V')]
        [string]$Output = 'Enum',

        [parameter()]
        [switch]$Current
    )

    $ErrorActionPreference = 'Stop'

    try{
        $result = bcdedit /$Output | where {$_ -match "^[^-|^ ]"}
    
        if(!$?){
            Write-Warning "BCD command failed. Are you running as admin?"
            break
        }

        $null = $result | ForEach-Object -Begin {$props = $null} -Process {
            $key,$value = $_.Split(' ',2).trim()
            if($key -eq 'Windows')
            {
                if($props.keys.Count -gt 0){
                    [pscustomobject]$props
                }
                $props = [ordered]@{
                    "BCD Entry" = $value
                }
            }
            else{
                $props.Add($key,$value)
            }
        } -End {[pscustomobject]$props} -OutVariable bcd

        if($Current){
            if($Output -eq 'v'){
                $bcd | Where-Object recoverysequence -eq (Get-BCDEdit -Output Enum | Where-Object identifier -match 'current').recoverysequence
            }
            else{
                $bcd | Where-Object identifier -match 'current'
            }
        }
        else{
            $bcd
        }
    }
    catch{
        Write-Warning "Error getting BCD info: $($result)"
    }
}
