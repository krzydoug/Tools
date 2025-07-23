function Get-ArpCache {

    switch -Regex (arp -a){
        'interface:\s+(?<InterfaceIP>\S+)\s+---\s+(?<Index>.+)$' {
            $InterfaceIP = $matches.InterfaceIP
            $IfIndex = [System.Convert]::ToInt32($matches.Index,16)
        }
        '^\s{1,}\d' {
            , -split $_ | ForEach-Object {
                [PSCustomObject]@{
                    InterfaceIP    = $InterfaceIP
                    InterfaceIndex = $IfIndex
                    IPAddress      = $_[0]
                    MAC            = $_[1].ToUpper()
                    Type           = $_[2]
                }
            }
        }
    }
}
