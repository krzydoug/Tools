Function Get-NetUser {
    Param($UserName)

    if(!$script:userlist){
        $script:userlist = ((net user /domain) -notmatch '--|\\\\|\.$|^$') -split '\s{2,}' | Where-Object {$_}
    }

    foreach($user in $UserName){
        if($user -match '\*'){
            if($user -eq '*'){
                $script:userlist.ForEach{Get-NetUser -UserName $_}
                break 
            }
            
            $script:userlist |
                Where-Object {$_ -like $user} |
                    ForEach-Object {Get-NetUser -UserName $_}
            continue
        }
        
        if(!$user -or $user -eq ' '){continue}
        
        $ht = [ordered]@{}

        switch -Regex (net user $user /domain){
            
            ' - ' {
                if($_ -match '^\s+(\w.+ - \d.+$)'){
                    $ht[$currentproperty] += $matches[1]
                }
                elseif($_ -match '^([^-]+?)\s{2,}(\w.+)$'){
                    $currentproperty = $matches[1]

                    $ht[$currentproperty] = ,$matches[2]
                }
                continue
            }

            '\*' {
                if($_ -match '^([^\*]+?)\s{2,}(\s?.+)$'){
                    if($matches[1] -eq ' '){
                        $ht[$currentproperty] += [regex]::Matches($matches[2],'(?<=\*)(.+?(?=\s?\*|$))').value.trim()
                    }
                    else{
                        $currentproperty = $matches[1]

                        $ht[$currentproperty] = [regex]::Matches($matches[2],'(?<=\*)(.+?(?=\s?\*|$))').value.trim()
                    }
                }
            }

            '^([^\*]+?)\s{2,}([^\*]+)$' {
                $ht.Add($matches[1],$matches[2])
            }

        }

        [PSCustomObject]$ht

    }

}
