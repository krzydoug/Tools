Function Get-InstalledPrograms{
    <#
.Synopsis
Get a list of installed programs from local or remote computers.
 
.DESCRIPTION
Get a list of installed programs from local or remote computers. Will pull list from both 32 and 64bit hives (not a complete and accurate list)

.NOTES   
Name: Get-InstalledPrograms.ps1
Author: Doug Maurer
Version: 1.0.2.2
DateCreated: 2018-11-22
DateUpdated: 2019-04-10

.LINK

.INPUTS
String

.OUTPUTS
pscustomobject

.EXAMPLE   
get-adcomputer -filter * | Get-InstalledPrograms -OutVariable results
Description 
-----------     
Attempts to get a list of installed programs from all AD Computers and store output in $results variable

.EXAMPLE   
get-content c:\servers.txt | Get-InstalledPrograms
Description 
-----------     
Attempts to get a list of installed programs from all computers in servers.txt

.EXAMPLE   
$programs = 'server1','server2','wks1' | Get-InstalledPrograms

.EXAMPLE   
Get-InstalledPrograms -name 'server1','server2','wks1' | tee-object -variable results
 
#>
    [cmdletbinding()]
    Param(
        [alias("CN","ComputerName","HostName","Computer")]
        [parameter(ValuefromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [String[]]$Name
        )

    begin{}
    process{
        if(-not $Name){$Name = $env:COMPUTERNAME}
            FOREACH ($PC in $Name) {
            $computername=$PC
 
            # Branch of the Registry  
            $Branch='LocalMachine'
            0..1 | foreach {
                try{
                    $regservice = Get-Service -Name RemoteRegistry -ComputerName $computername -ErrorAction Stop
                }catch{
                    if($_ -eq 2){
                        Write-Warning "Unable to query remoteregistry on $PC"
                        break
                    }
                }
            }
            $tracker = New-Object System.Collections.ArrayList
            try{
                if($regservice.StartType -eq 'disabled'){
                    Set-Service -InputObject $regservice -StartupType Manual -ErrorAction stop
                    $servicedisabled = $true
                }
                if($regservice.Status -ne 'running'){
                    Start-Service -InputObject $regservice -ErrorAction SilentlyContinue
                    $servicestarted = $true
                    Start-Sleep -Seconds 2
                }
            }catch{
                write-warning "Unable to reach remote registry service on $PC";break
            }
            
            if((Get-Service -Name RemoteRegistry -ComputerName $computername -EA SilentlyContinue).status -ne 'running'){
                write-warning "Unable to reach remote registry service on $PC"
                break
            }
            
            $SubBranch="SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall"   
            @{View=512;Bit='32-Bit'},@{View=256;Bit='64-Bit'} | foreach{
                $registry= [microsoft.win32.registrykey]::OpenremoteBaseKey($Branch,$PC,$_.view)
                $registrykey=$registry.OpenSubKey($Subbranch)
                $subkeys = $registrykey.GetSubKeyNames()
                Foreach ($key in $subkeys)  
                {
                    if($key -in $tracker.key){continue}
                    [void]$tracker.Add(@{Key=$key})
                    $NewSubKey=$SubBranch+"\\"+$key
                    $Readkey=$registry.OpenSubKey($NewSubKey)
                    try{
                    $Displayname=$Readkey.GetValue("DisplayName")
                    $UninstallString = $readkey.GetValue("UninstallString")
                    }
                    catch{}
                    $properties = [ordered]@{
                        PC = $PC
                        Displayname = $displayname
                        Architecture = $_.bit
                        Subkey= $key
                        UninstallString = $UninstallString
                }
                $obj = New-Object -TypeName PSObject -Property $properties
                write-output $obj
                }
            }

            if($registrykey){$registrykey.close()}
            if($registry){$registry.close()}
            if($servicedisabled){Set-Service -InputObject $regservice -StartupType Disabled}
            if($servicestarted){Stop-Service -InputObject $regservice -ErrorAction SilentlyContinue}
            
        }
    }
    end{}
    
}