function Get-WifiProfile {
    <#
    .SYNOPSIS
        Function to pull stored wifi profiles and security keys. 
    .DESCRIPTION
        Function to pull stored wifi profiles and security keys. Running the function with no parameters will
        show all stored wifi profiles with any stored security keys obfuscated. 
    .EXAMPLE
        PS C:\> Get-WifiProfile 'Hilton'
        Gets all wifi profiles that contain the word Hilton with passwords obfuscated
    .EXAMPLE
        PS C:\> Get-WifiProfile 'Hilton' -ShowKey
        Gets all wifi profiles that contain the word Hilton with passwords in plain text
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
        # Start by getting a list of all existing profiles
        $networklist = (netsh wlan show profiles) -match ' :'  -replace '.+: '
        
        # Store command as a scriptblock. If $ShowKey is present then key=clear will be added to the command
        # Issue encountered with SSID that include single quote. Replace single quote with asterisk in profile lookup
        $command = {netsh wlan show profiles $($network -replace "'",'*') ('','key=clear')[$ShowKey.IsPresent]}
    }
    
    process {
        $lookuplist = if($Name){
            # Concantonate all names as a regex or pattern (if only one value no pipe is appended)
            $regexlist = $Name -join '|'
            
            # Force array matching even if only one value so any matches are output
            @($networklist) -match $regexlist
        }
        else{
            $networklist
        }

        foreach($network in $lookuplist){
            Write-Verbose "Processing network $network"
            $ht = [ordered]@{}
            
            # match only the lines that may have values
            (& $command) -match " : .+" | ForEach-Object{
                # , is the array operator to send the result of the split as an array instead of one at a time
                ,($_.Trim() -split '\s+:\s+') | ForEach-Object{

                    # to maintain the order of properties when $ShowKey is not called add the obfuscated password or N/A right after 'Security Key'
                    if($_[0] -eq 'Security Key' -and -not $ShowKey){
                        $ht.'Key Content' = if($_[1] -eq 'present'){
                            # Password is present and $ShowKey not called so replace password with 6 to 10 asterisks
                            '*' * (Get-Random (6..10))
                        }
                        else{
                            # Security key is not present
                            "N/A"
                        }
                    }

                    # If the hashtable already contains the key capture the values
                    if($entry = $ht[$_[0]]){
                        # Split on comma even if there are none and check if current value already present
                        if(($array = $entry -split ',') -notcontains $_[1]){
                            # Add value to existing values joined with commas
                            $ht[$_[0]] = @($array) + $_[1] -join ','
                        }
                    }
                    else{
                        # Key not present in hashtable so create it while setting the value
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
