        <#
        .Synopsis
           List all ObjectClass attributes for ADUser
        .DESCRIPTION
           List all ObjectClass attributes for ADUser
        .EXAMPLE
           Get-ObjectClass "Username"
        .EXAMPLE
           Get-ObjectClass CN=Username,OU=Users,DC=Domain,DC=LOCAL
        .INPUTS
           [String[]] (SamAccountName, SID, Distinguished Name
        .OUTPUTS
           [string[]]
        .NOTES
           Powershell cmdlets get-adobject and get-aduser only return the objectclass of which the user is an instance. It does not include auxillary classes.
        #>
function Get-ObjectClass
{
    [CmdletBinding()]
    [Alias("goc")]
    [OutputType([String[]])]
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
        
    Begin
    {
        $ErrorActionPreference = 'Stop'
    }

    Process
    {
        foreach($id in $Identity)
        {
            try
            {
                $user = get-aduser $Id
            }
            catch{
                Write-Warning "Unable to find ADUser $Id"
                break
            }
            (dsquery * $user.distinguishedname -scope base -attr objectclass |
                select -Skip 1).trim() -split ';' | where {$_ -ne ''}
        }
    }

    End
    {
    }
}
