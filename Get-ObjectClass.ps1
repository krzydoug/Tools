function Get-ObjectClass{
    <#
    .Synopsis
        List all ObjectClass attributes for ADUser
    .DESCRIPTION
        List all ObjectClass attributes for ADUser
    .EXAMPLE
        Get-ObjectClass "Username"
    .EXAMPLE
        Get-ObjectClass CN=Username,OU=Users,DC=Domain,DC=LOCAL
    .EXAMPLE
        get-aduser -filter * | Get-ObjectClass
    .INPUTS
        [String[]] (Name, UserPrincipalName, SamAccountName, SID, DistinguishedName)
    .OUTPUTS
        [string[]]
    .NOTES
        Powershell cmdlets get-adobject and get-aduser only return the objectclass of which the user is an instance. It does not include auxillary classes.
    #>

    [CmdletBinding()]
    [Alias("goc")]
    [OutputType([PSCustomObject[]])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true,
                    HelpMessage="Please enter a username",
                    Position=0
                    )]
        [Alias("User")] 
        [string[]]$Identity
        
    )
        
    Begin{
        $ErrorActionPreference = 'Stop'
    }

    Process{

        foreach($id in $Identity){
            
            $filter = switch -Regex ($id){
                '=' {'DistinguishedName'}
                '@' {'UserPrincipalName'}
                ' ' {'Name'}
                'S-\d|-\d{5,}|\d{5,}-' {'SID'}
                default {'SamAccountName'}
            }
        
            $operator = if($id -match '(\*)'){
                if($filter -eq 'SID' -and $id -ne $matches.1){
                    Write-Warning "The '-like' operator for property 'SID' only seems to work with '*'."
                    '-eq'
                }
                else{
                    '-like'
                }
            }
            else{
                '-eq'
            }

            if($userlist = Get-ADUser -Filter "$filter $operator '$id'"){
                Write-Verbose "Property '$filter' $operator '$id'"
                
                foreach($user in $userlist){
                    Write-Verbose "Found AD user $($user.name)"
                    
                    try{
                        $objectclass = [regex]::Matches($(
                            dsquery * $user.distinguishedname -scope base -attr objectclass),
                            '(\w+)(?=;)'
                        ).Value
                        
                        if($objectclass){
                            [PSCustomObject]@{
                                ADUser = $user.samaccountname
                                Class  = $objectclass
                            }
                        }
                    }
                    catch{
                        Write-Warning "Error running dsquery: $($_.exception.message)"
                    }
                }
            }
            else{
                Write-Verbose "Unable to find AD user with property '$filter' that is $operator '$id'"
            }
        }
    }

    End{}
}
