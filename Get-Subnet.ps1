Function Get-Subnet {
    <#
        .SYNOPSIS
            Returns subnet details for the local IP address, or a given network address and mask.

        .DESCRIPTION
            Use to get subnet details for a given network address and mask, including network address, broadcast address, network class, address range, host addresses and host address count.

        .PARAMETER IP
            A metric object (generated by one of the Get-*Metric cmdlets from this module) which can be provided as pipeline input.

        .PARAMETER MaskBits
            The name of the measure to be updated or created.

        .PARAMETER Force
            Use to force the return of all host IP addresses regardless of the subnet size (skipped by default for subnets larger than /16).

        .EXAMPLE
            Get-Subnet 10.1.2.3/24

            Description
            -----------
            Returns the subnet details for the specified network and mask, specified as a single string to the -IP parameter.

        .EXAMPLE
            Get-Subnet 192.168.0.1 -MaskBits 23

            Description
            -----------
            Returns the subnet details for the specified network and mask.

        .EXAMPLE
            Get-Subnet

            Description
            -----------
            Returns the subnet details for the current local IP.

        .EXAMPLE
            '10.1.2.3/24','10.1.2.4/24' | Get-Subnet

            Description
            -----------
            Returns the subnet details for two specified networks.
    #>

    [cmdletbinding()]
    Param ( 
        [parameter(Position=0,ValueFromPipeline)]
        [string[]]
        $IP,

        [parameter(Position=1)]
        [ValidateRange(0, 32)]
        [int]
        $MaskBits,

        [switch]
        $Force
    )
    
    Begin{
        function Convert-IPtoInt64 ($ip) { 
            $octets = $ip.split(".") 
            [int64]([int64]$octets[0] * 16777216 +
            [int64]$octets[1] * 65536 +
            [int64]$octets[2] * 256 +
            [int64]$octets[3]) 
        }

        function Convert-Int64toIP ([int64]$int) { 
            (([math]::truncate($int / 16777216)).tostring() + "." +
            ([math]::truncate(($int % 16777216) / 65536)).tostring() + "." +
            ([math]::truncate(($int % 65536) / 256)).tostring() + "." +
            ([math]::truncate($int % 256)).tostring() )
        }

        function Get-Class ($IP) {
            switch ($IP.Split('.')[0]){
                { $_ -in 0..127 } { 'A' }
                { $_ -in 128..191 } { 'B' }
                { $_ -in 192..223 } { 'C' }
                { $_ -in 224..239 } { 'D' }
                { $_ -in 240..255 } { 'E' }
            }
        }

        function Get-DefaultMask ($IP) {
            $Class = Get-Class $IP

            Write-Verbose "Class: $Class"

            $Mask = Switch ($Class) {
                    'A' { 8 }
                    'B' { 16 }
                    'C' { 24 }
                    default { Throw "Subnet mask size was not specified and could not be inferred because the address is Class $Class." }
            }

            Write-Warning "No subnet mask was specified. Using default subnet mask /$Mask for Class $Class network."

            $Mask
        }

        $defaultDisplaySet = 'NetworkAddress','SubnetMask','BroadcastAddress','HostAddressCount'

        $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet(‘DefaultDisplayPropertySet’,[string[]]$defaultDisplaySet)
        $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)

        $results = [ordered]@{}
    }

    Process {

        $IPList = If ($IP){
            foreach($address in $IP){
                If($address -match '/\d'){
                    $address,$Mask = $address -Split '/'
                }
                else{
                    $Mask = if($PSBoundParameters.ContainsKey('MaskBits')){
                        $PSBoundParameters['MaskBits']
                    }
                    else{
                        Get-DefaultMask $address
                    }
                }

                [PSCustomObject]@{
                    IPAddress    = $address
                    PrefixLength = $Mask 
                }
            }
        }
        else{
            Get-NetIPAddress | Where-Object {
                $_.AddressFamily -eq 'IPv4' -and $_.PrefixOrigin -ne 'WellKnown'
            }
        }
        
        foreach($address in $IPList){
            $IPAddr = [Net.IPAddress]::Parse($address.IPAddress)

            if($null -eq $IPAddr){
                Write-Warning "Unable to parse $($address.IPAddress)"
                break
            }

            $mask = $address.PrefixLength

            Write-Verbose "IP Addr: $IPAddr"
            Write-Verbose "Mask: $mask"
            
            $MaskAddr = [IPAddress]::Parse((Convert-Int64toIP -int ([convert]::ToInt64(("1" * $mask + "0" * (32 - $mask)), 2))))        
            $NetworkAddr = [IPAddress]($MaskAddr.address -band $IPAddr.address) 
            $BroadcastAddr = [IPAddress](([IPAddress]::parse("255.255.255.255").address -bxor $MaskAddr.address -bor $NetworkAddr.address))
        
            $HostStartAddr = (Convert-IPtoInt64 -ip $NetworkAddr.ipaddresstostring) + 1
            $HostEndAddr = (Convert-IPtoInt64 -ip $broadcastaddr.ipaddresstostring) - 1

            $HostAddressCount = ($HostEndAddr - $HostStartAddr) + 1
        
            If ($mask -ge 16 -or $Force) {
            
                Write-Progress "Calcualting host addresses for $NetworkAddr/$mask.."

                $HostAddresses = for ($i = $HostStartAddr; $i -le $HostEndAddr; $i++) {
                    Convert-Int64toIP -int $i
                }
            }
            Else {
                Write-Warning "Calculation for /$Mask subnet can take a while.`nUse -Force if you want it to occur."
                break
            }

            $current = [pscustomobject]@{
                IPAddress        = $IPAddr
                MaskBits         = $mask
                NetworkAddress   = $NetworkAddr
                BroadcastAddress = $broadcastaddr
                SubnetMask       = $MaskAddr
                NetworkClass     = Get-Class $address.IPAddress
                Range            = "$networkaddr ~ $broadcastaddr"
                HostAddresses    = $HostAddresses
                HostAddressCount = $HostAddressCount
            }

            $current.PSObject.TypeNames.Insert(0,'System.Net.NetworkInformation')
            $current | Add-Member MemberSet PSStandardMembers $PSStandardMembers

            if($results["$NetworkAddr-$mask"]){
                $results["$NetworkAddr-$mask"].IPAddress = $results["$NetworkAddr-$mask"].IPAddress,$current.IPAddress -join ', '
            }
            else{
                $results["$NetworkAddr-$mask"] = $current
            }
        }

        Remove-Variable -Name Mask,IPAddr,IPList -ErrorAction SilentlyContinue
    }

    end{
        $results.values
    }
}
