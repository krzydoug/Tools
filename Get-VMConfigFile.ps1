Function Get-VMConfigFile {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
            [Alias("VMName")]
            [String[]]$VM
    )

    begin {
        Register-ArgumentCompleter -CommandName Get-VMConfigFile -ParameterName VM -ScriptBlock {
            try{
                (Get-VM).Name
            }
            catch{}
        }
    }

    process {
        foreach($guest in $VM){
            
            foreach($vminfo in Get-VM $guest){
                [PsCustomObject]@{
                    Name = $vminfo.name
                    VMX  = $vminfo.ExtensionData.Config.Files.VmPathName
                }
            }
        }
    }

    end {}

}
