function Test-ADCredential {
           
    [CmdletBinding()]
    [OutputType([boolean])] 
       
    Param ( 
        [Parameter( 
            Mandatory = $false, 
            ValueFromPipeLine = $true, 
            ValueFromPipelineByPropertyName = $true
        )] 
        [Alias( 
            'PSCredential'
        )] 
        [ValidateNotNull()] 
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()] 
        $Credential
    )
    
    begin{

    }
    
    process{
        If($Credential -eq $null){
            Try{
                $Credential = Get-Credential "domain\$env:username" -ErrorAction Stop
            }
            Catch{
                $ErrorMsg = $_.Exception.Message
                Write-Warning "Failed to validate credential: $ErrorMsg "
                Break
            }
        }
      
        # Checking module
        Try{
            # Split username and password
            $Username = $credential.username
            $Password = $credential.GetNetworkCredential().password
  
            # Get Domain
            $Root = "LDAP://" + ([ADSI]'').distinguishedName
	
	    if($Root -match '://$'){
            Write-Warning "Unable to find domain. Is this system in a workgroup?"
	        continue
	    }

            $Domain = New-Object System.DirectoryServices.DirectoryEntry($Root,$UserName,$Password)
        }
        Catch{
            Write-Warning $_.Exception.Message
            Continue
        }
  
        If(!$domain){
            Write-Warning "Something went wrong"
	        $false
        }
        Else{
            If ($domain.name -ne $null){
                $true
            }
            Else{
                $false
            }
        }
    }
}
