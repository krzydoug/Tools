function Get-WifiProfile {
    <#
    .SYNOPSIS
        Function to pull stored wifi profiles and security keys. 
    .DESCRIPTION
        Function to pull stored wifi profiles and security keys. Running the function with no parameters will
        show all stored wifi profiles with any stored security keys obfuscated. 
    .EXAMPLE
        PS C:\> <example usage>
        Explanation of what the example does
    .EXAMPLE
        PS C:\> <example usage>
        Explanation of what the example does
    .PARAMETER Name
        Partial or full name of a wifi network
    .PARAMETER Showkey
        Switch to choose showing security key in plain text. 
    .NOTES
        https://www.reddit.com/r/PowerShell/comments/tnzyxw/showwifipasswords/
        https://github.com/krzydoug/Tools/blob/master/Get-WifiProfile.ps1
    #>

    [CmdletBinding()]
    param (
        [Parameter(HelpMessage="Enter the name of the Wifi profile")]
        [Alias("SSID","Network")]
        [string[]]$Name,

        [switch]$ShowKey
    )
    
    begin {
        $networklist = (netsh wlan show profiles) -match ' :'  -replace '.+: '
        $command = {netsh wlan show profiles $($network -replace "'",'*') ('','key=clear')[$ShowKey.IsPresent]}
    }
    
    process {
        $lookuplist = if($Name){
            $regexlist = $Name -join '|'
            @($networklist) -match $regexlist
        }
        else{
            $networklist
        }

        foreach($network in $lookuplist){
            Write-Verbose "Process network $network"
            $ht = [ordered]@{}

            (& $command) -match " : .+" | ForEach-Object{
                ,($_.Trim() -split '\s+:\s+') | ForEach-Object{

                    
                    if($_[0] -eq 'Security Key' -and -not $ShowKey){
                        $ht.'Key Content' = if($_[1] -eq 'present'){
                            '*' * (Get-Random (6..10))
                        }
                        else{
                            "N/A"
                        }
                    }

                    if($entry = $ht[$_[0]]){
                        if(($array = $entry -split ',') -notcontains $_[1]){
                            $ht[$_[0]] = @($array) + $_[1] -join ','
                        }
                    }
                    else{
                        $ht[$_[0]] = $_[1]
                    }
                }
            }

            [PSCustomObject]$ht
        }
    }
    
    end {
        
    }
}
