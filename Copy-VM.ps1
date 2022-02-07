function Copy-VM {
    <#
    .SYNOPSIS
        Copies a source vmware VM to one or more new VMs
    .DESCRIPTION
        This function can be run interactively or as part of automation.
        It contains logic to create the new VM with the same settings as the source. 
    .EXAMPLE
        PS C:\> $params = @{
            Name       = 'NewVM'
            VMHost     = '172.27.14.222'
            Verbose    = $true
            SourceVM   = 'WIN19SVR-STD-TEMPLATE'
            Credential = Get-Credential root
        }
        
        PS C:\> Copy-VM @params

        This example shows providing the required arguments via hashtable using splatting.
    .EXAMPLE
        PS C:\> Copy-VM
        Enter the ESXi hostname or IP: 172.27.14.222

        PowerShell credential request
        Enter credentials for 172.27.14.222
        User: root
        Password for user root: *********

        Enter the name for the new VM: test

        This example shows interactive prompts from running Copy-VM alone
    .INPUTS
        String
    .OUTPUTS
        None
    .NOTES
        TODO: account for multiple controllers
    #>

    [CmdletBinding()]
    param (
        $VMHost,

        $SourceVM,

        [pscredential]$Credential,

        [parameter(ValueFromPipelineByPropertyName)]
        [string]$Name,

        [parameter(ValueFromPipelineByPropertyName)]
        [string]$Datastore,

        [parameter(ValueFromPipelineByPropertyName)]
        [string]$MemoryGB,

        [parameter(ValueFromPipelineByPropertyName)]
        [string]$NetworkName,

        [parameter(ValueFromPipelineByPropertyName)]
        [switch]$SkipHardDisks
    )
    
    begin {
        if(!(Get-Module vmware.powercli -ListAvailable)){
            Install-Module vmware.powercli -Force
        }

        $script:tasklist = New-Object System.Collections.Generic.List[PSCustomobject]

        $config = @{
            Confirm                    = $false
            ParticipateInCeip          = $false
            InvalidCertificateAction   = 'Ignore'
            DisplayDeprecationWarnings = $false
        }

        $null = Set-PowerCLIConfiguration @config

        if(!$VMHost){
            $VMHost = Read-Host "Enter the ESXi hostname or IP"
            if(!$VMHost){
                Write-Warning "Source ESXi host required"
                break
            }
        }

        if(!$Credential){
            $Credential = Get-Credential -Message "Enter credentials for $VMHost"
            if(!$Credential){
                Write-Warning "Credentials are required to connect to $VMHost"
                break
            }
        }

        try{
            $null = Connect-VIServer -Server $VMHost -Credential $Credential -Verbose
        }
        catch{
            Write-Warning "Error connecting to $VMHost"
            break
        }

        $SourceVMobject = if($SourceVM){
            Get-VM $SourceVM
        }
        else{
            Get-VM | Out-GridView -Title "Select the VM to clone" -OutputMode Single

        }
        
        if(!$SourceVMobject){
            Write-Warning "Source ESXi host required"
            break
        }
    }
    
    process {
        if(!$Name){
            $Name = Read-Host -Prompt "Enter the name for the new VM"

            if(!$Name){
                Write-Warning "New VM name is required"
                break
            }
        }

        if(!$Datastore){
            $Datastore = $SourceVMobject.ExtensionData.config.datastoreURL.name
        }

        if(!$NetworkName){
            $NetworkName = ($SourceVMobject | Get-NetworkAdapter).networkname
        }

        if(!$MemoryGB){
            $MemoryGB = $SourceVMobject.MemoryGB
        }
        
        if(!$NumCPU){
            $NumCPU = $SourceVMobject.NumCpu
        }

        if(!$CoresPerSocket){
            $CoresPerSocket = $SourceVMobject.CoresPerSocket
        }

        if(!$SkipHardDisks){
            $Harddisklist = $SourceVMobject | Get-HardDisk
        }

        $params = @{
            Name = $Name
            VMHost = $VMHost
            NetworkName = $NetworkName
            Datastore  = $Datastore
            MemoryGB    = $MemoryGB
            NumCPU = $NumCPU
            CoresPerSocket = $CoresPerSocket
            HardwareVersion = $SourceVMobject.HardwareVersion
            GuestID         = $SourceVMobject.GuestId
        }

        Write-Verbose -Message "Creating vm $Name"

        $targetvm = New-VM @params
        
        if($SourceVMobject.ExtensionData.Config.Firmware -eq 'EFI'){
            $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
            $spec.Firmware = [VMware.Vim.GuestOsDescriptorFirmwareType]::efi
            $boot = New-Object VMware.Vim.VirtualMachineBootOptions

            if($SourceVMobject.ExtensionData.Config.bootoptions.EfiSecureBootEnabled){
                $boot.EfiSecureBootEnabled = $true
            }

            $spec.BootOptions = $boot
            $targetvm.ExtensionData.ReconfigVM($spec)
        }

        $newdisk = $targetvm | Get-HardDisk
        $vmpath = $newdisk.Filename.Split("/")[0]
        $newdisk | Remove-HardDisk -Confirm:$false -DeletePermanently
        
        for($i = 0; $i -lt @($Harddisklist).count; $i++){
            Write-Verbose "Cloning disk $($harddisk.Name) from $($SourceVMobject.name) to $($Name)_$i"
            $vmdk = "$vmpath/$($Name)_$i.vmdk"
            $diskjob = $Harddisklist[$i] | Copy-HardDisk -DestinationPath $vmdk -DestinationStorageFormat Thin -RunAsync

            $script:tasklist.Add($(
                [PSCustomObject]@{
                    Disk = $vmdk
                    VM   = $targetvm
                    Task = $diskjob
                    Type = (Get-ScsiController -VM $SourceVMobject)[0].type
                }
            ))

        }
    }

    end {
        do{
            $percentcomplete = (@($script:tasklist.task).percentcomplete | Measure-Object -Sum).sum / @($script:tasklist.task).count

            $s = if($script:tasklist.count -gt 1){'s'}else{''}

            $count = @($script:tasklist.task.where{$_.state -eq 'Running'}).count

            Write-Progress -Activity "Copying hard drive$s from source VM" -Status "  Remaining disks: $count" -PercentComplete $percentcomplete -Id 1
        }
        until(@($script:tasklist.task).state -notcontains 'Running')

        Write-Progress -Activity "Completed" -Completed -Id 1

        foreach($task in $script:tasklist){
            Write-Verbose "Attaching $($task.disk) to $($task.vm.name)"

            $null = $task.vm | New-HardDisk -DiskPath $task.disk

            $null = $task.vm | Get-ScsiController | Set-ScsiController -Type $task.type
        } 

        Disconnect-VIServer -confirm:$false
    }
}
