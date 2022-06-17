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
        [AllowEmptyString()]
        [AllowNull()]
        $Domain,

        [parameter(ParameterSetName='Machine',ValueFromPipelineByPropertyName)]
        [Alias('CN','HostName','ServerName')] 
        [string]
        $ComputerName
    )
    
    begin{
        Add-Type -AssemblyName System.DirectoryServices.AccountManagement

        switch ($PSCmdlet.ParameterSetName){
            'Domain' {
                try{
                    $server = [system.net.dns]::GetHostEntry($Domain).addresslist.ipaddresstostring | Select-Object -First 1
                
                    if(-not $server){
                        Write-Warning "Unable to look up a DC for $Domain"
                        break
                    }
                }
                catch{
                    Write-Warning $_.exception.message
                    break
                }

                $script = {
                    Param($cred,$server)
                    
                    try{
                        $obj = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('Domain',$server,$cred.username, $cred.GetNetworkCredential().password)

                        if($obj.ConnectedServer){
                            $true
                        }
                        else{
                            $false
                        }
                    }
                    catch{
                        Write-Warning $_.exception.message
                        $false
                    }
                }
            }

            'Machine' {
                
                if(-not $ComputerName){
                    $ComputerName = $env:computername
                }

                $script = {
                    Param($cred)

                    try{
                        $obj = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('machine',$ComputerName)

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
            . $script $Credential $server
        }
        Catch{}
    }
}
