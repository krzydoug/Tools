function Test-Credential {
           
    [CmdletBinding(DefaultParameterSetName='Machine')]
    [OutputType([boolean])] 
       
    Param ( 
        [Parameter(ValueFromPipeLine,ValueFromPipelineByPropertyName)] 
        [Alias('PSCredential')] 
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,

        [parameter(ParameterSetName='Domain')]
        [ValidatePattern('\w+\.\w+.+')]
        [string]
        $Domain,

        [parameter(ParameterSetName='Machine',ValueFromPipelineByPropertyName)]
        [Alias('CN','HostName','ServerName')] 
        [string]
        $ComputerName
    )
    
    begin{
        switch ($PSCmdlet.ParameterSetName){
            'Domain' {
                try{
                    Write-Verbose "Looking up information for domain $Domain"
                    $ldapFilter = "(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))"
                    $dn = ($Domain -split '\.'|ForEach-Object{"DC=$_"}) -join ','
                    $server = [system.net.dns]::GetHostEntry($Domain).addresslist.ipaddresstostring | Select-Object -First 1
                
                    if(-not $server){
                        Write-Warning "Unable to look up a DC for $Domain"
                        break
                    }

                    $obj = New-Object -ComObject "ADODB.Connection"
                    $obj.Provider = "ADSDSOObject"
                    $obj.Properties['Encrypt Password'] = $true
                }
                catch{
                    Write-Warning $_.exception.message
                    break
                }

                $script = {
                    Param($obj,$cred)

                    if($obj.state -eq 1){
                        $null = $obj.Close()
                    }

                    $obj.Properties['User ID'] = $cred.username
                    $obj.Properties['Password'] = $cred.GetNetworkCredential().password
                    $obj.Properties['Encrypt Password'] = $true
                    $obj.Open("ADSearch")  
                          
                    Try{
                        [bool]($obj.Execute("<LDAP://$server/$dn>;$ldapFilter;distinguishedName,dnsHostName"))
                    }
                    Catch{
                        if($_.exception.message -notmatch 'password is incorrect'){
                            Write-Warning $_.exception.message
                        }
                        $false
                    }

                    $null = $obj.Close()
                }
            }

            'Machine' {
                Add-Type -AssemblyName System.DirectoryServices.AccountManagement
                
                if(-not $ComputerName){
                    $ComputerName = $env:computername
                }

                $obj = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('machine',$ComputerName)

                $script = {
                    Param($obj,$cred)

                    try{
                        $obj.ValidateCredentials($cred.username, $cred.GetNetworkCredential().password)
                    }
                    catch{
                        Write-Warning $_.exception.message
                        $false
                    }
                }
            }
        }
    }
    
    process{
        If($null -eq $Credential){
            Write-Warning "No credential specified, default to '$env:USERDOMAIN\$env:username'"

            try{
                $Credential = Get-Credential "$env:USERDOMAIN\$env:username" -ErrorAction Stop
            }
            catch{
                Write-Warning $_.exception.message
                break
            }
        }
        
        Try{
            Write-Verbose "Checking credential $($Credential.UserName) against $($Domain)$ComputerName"
            . $script $obj $Credential
        }
        Catch{}
    }
}
