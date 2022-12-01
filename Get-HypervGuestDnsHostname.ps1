function Get-HypervGuestDnsHostname {
    [cmdletbinding()]
    Param(
        [parameter(Mandatory,Position=0,ValueFromPipeline)]
        $VMName
    )

    process {
        $params = @{
            Namespace = 'root\virtualization\v2'
            Class     = 'Msvm_ComputerSystem'
            Filter    = "ElementName = '$VMName'"
        }

        $instance = Get-CimInstance @params |
            Get-CimAssociatedInstance -ResultClassName Msvm_KvpExchangeComponent

        foreach($entry in $instance){
            foreach($kvp in $entry.GuestIntrinsicExchangeItems){
                $node = ([xml]$kvp).SelectSingleNode("/INSTANCE/PROPERTY[@NAME='Name']/VALUE[child::text() = 'FullyQualifiedDomainName']")

                if($node){
                    $node.SelectSingleNode("/INSTANCE/PROPERTY[@NAME='Data']/VALUE/child::text()").value
                }
            }
        }
    }
}
