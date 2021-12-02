Function Get-LastLogon (){
    [cmdletbinding()]

    Param(
        [alias("UserName","User","SamAccountName","Name","DistinguishedName","UserPrincipalName","DN","UPN")]
        [parameter(ValueFromPipeline,Position=0,Mandatory)]
        [string[]]$Identity
    )

    begin{
        $DCList = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().DomainControllers.name
    }

    process{

        foreach($currentuser in $Identity)
        {
            $filter = switch -Regex ($currentuser){
                '=' {'DistinguishedName';break}
                '@' {'UserPrincipalName';break}
                ' ' {'Name';break}
                default {'SamAccountName'}
            }

            Write-Verbose "Checking lastlogon for user: $currentuser"

            foreach($DC in $DCList)
            {
                Write-Verbose "Current domain controller: $DC"
                
                $ad = [ADSI]"LDAP://$dc"

                $searcher = [DirectoryServices.DirectorySearcher]::new($ad,"($filter=$currentuser)")
                $account = $searcher.findone()
                
                if(!$account)
                {
                    Write-Verbose "No user found with search term '$filter=$currentuser'"
                    continue
                }

                $logon     = $($account.Properties.lastlogon)
                $logontimestamp = $($account.Properties.lastlogontimestamp)

                Write-Verbose "LastLogon          : $([datetime]::FromFileTime($logon))"
                Write-Verbose "LastLogonTimeStamp : $([datetime]::FromFileTime($logontimestamp))"
                
                $logontime = $($logon,$lastlogontimestamp |
                    Sort-Object -Descending | Select-Object -First 1)
            
                if($logontime -gt $newest)
                {
                    $newest = $logontime
                }
            }

            if($account)
            {
                switch ([datetime]::FromFileTime($newest)){
                    {$_.year -eq '1600'}{
                        "Never"
                    }
                    default{$_}
                }
            }

            Remove-Variable newest,account,lastlogon,logon,logontime,lastlogontimestamp -ErrorAction SilentlyContinue
        }
    }

    end{
        Remove-Variable dclist -ErrorAction SilentlyContinue
    }
}
