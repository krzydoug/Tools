Function Get-SharePermission{
<#
.SYNOPSIS
Script to list shares and folder permissions on a remote system

.DESCRIPTION
This Script by default will list all shares and permissions on the specified servers. The default shares like Admin$ and c$ 
are excluded by default but can be added by providing parameter "IncludeDefaultShares"

This script require that CIM and SMB are open and that the account running the script has the correct permisions. 

.PARAMETER ComputerName
One or more computer names to query

.PARAMETER Identity
One or more username to include in the results

.PARAMETER Exact
Switch to make Identity argument match exactly

.PARAMETER IncludeDefaultShares
Switch to include default shares

.EXAMPLE
Get-SharePermission -ComputerName W16-DC01, W19-APP01
.EXAMPLE
W16-DC01, W19-APP01 | Get-SharePermission -IncludeDefaultShares
.EXAMPLE
Get-SharePermission -ComputerName W16-DC01, W19-APP01 -Identity Administrator -Exact
.EXAMPLE
W16-DC01, W19-APP01 | Get-SharePermission -Identity Administrator, admin
#>

## Setting script parameters
    [cmdletbinding()]
    Param(
        [parameter(ValueFromPipeline,ValueFromPipelineByPropertyName,Mandatory)]
        [String[]]$ComputerName,

        [parameter()]
        [String[]]$Identity,

        [parameter()]
        [switch]$Exact,

        [parameter()]
        [switch]$IncludeDefaultShares
    )

    begin{
        $ea = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'

        $CimParams = @{
            ClassName  = 'win32_share'
            CimSession = ''
        }

        if($Identity){
            $Identity = $Identity.ForEach({
                ('{0}','{0}$')[$Exact.IsPresent] -f [regex]::Escape($_)
            }) -join '|'
        }

        if(!$IncludeDefaultShares){
            $CimParams.Add('Filter',"Description != 'Remote Admin' and
                            Description != 'Default share' and
                            Description != 'Remote IPC' and
                            Description != 'Printer Drivers'")
        }
    }

    process{
        foreach ($Server in $ComputerName){
            Write-Host "Checking $($server)" -ForegroundColor Green

            $CimParams.CimSession = $Server

            $ShareList = Get-CimInstance @CimParams  | Select-Object -ExpandProperty Name

            foreach ($share in $ShareList) {
                $FolderPath =  "\\$Server\$share"

                Write-Verbose "Checking permissions on $($FolderPath)"

                $props = 'Name','FullName','LastWriteTime','Length'

                $FolderList = @(
                    try{
                        Get-Item -Path $FolderPath | Select-Object $props
                    }
                    catch{
                        Write-Warning $_.Exception.Message
                    }
                )

                foreach ($Folder in $FolderList){

                    $AclList = Get-Acl -Path $Folder.FullName -ErrorAction SilentlyContinue

                    foreach ($Acl in $AclList.Access) {
                        if($Identity -and $acl.identityreference -notmatch $Identity){
                            continue
                        }

                        [PSCustomObject]@{
                            ComputerName      = $Server
                            FolderName        = $Folder.Name
                            FolderPath        = $Folder.FullName
                            IdentityReference = $Acl.IdentityReference.ToString()
                            Permissions       = $Acl.FileSystemRights.ToString()
                            AccessControlType = $Acl.AccessControlType.ToString()
                            IsInherited       = $Acl.IsInherited
                        }
                    }
                }
            }
        }
    }

    end{
        $ErrorActionPreference = $ea
    }
}
