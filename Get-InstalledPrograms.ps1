Function Get-InstalledPrograms {

    [CmdletBinding(DefaultParameterSetName="UserDefined")]

    Param(
        [Parameter(Position=0)]
        [Alias("ProgramName","PN")]
            [String[]]$Name,

        [Parameter(Position=1,ParameterSetName="UserDefined")]
            [String[]]$Property=@("DisplayName","DisplayVersion","InstallDate","InstallSource","UninstallString","QuietUninstallString","EstimatedSize","Guid"),
    
        [Parameter(Position=2,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [Alias("CN")]
            [String[]]$ComputerName=$env:COMPUTERNAME,

        [Parameter(Mandatory=$true,ParameterSetName="All")]
            [Switch]$All
    )

    Begin {
        $proplist = New-Object System.Collections.Generic.List[string]
        $finalproplist = New-Object System.Collections.Generic.List[string]
        $finalproplist.Add('GUID')

        $ProgCmd = {
            Param($prog,$props)
            $programs = @()
            $Is64Bit = (Get-WmiObject Win32_OperatingSystem).OSArchitecture -eq "64-bit"

            if ($prog) {
                if ($Is64Bit) {
                    $tempProgs = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*,HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*
                    foreach ($tp in $tempProgs) {
                        if ($tp.DisplayName -like $prog) {$programs += $tp}
                    }
                }
                else {
                    $tempProgs = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*
                    foreach ($tp in $tempProgs) {
                        if ($tp.DisplayName -like $prog) {$programs += $tp}
                    }
                }
            }
            else {
                if ($Is64Bit) {$programs += Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*,HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*}
                else {$programs += Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*}
            }

            foreach($program in $programs){
                $guid = if($guid = $program.UninstallString -replace '.+(?=\{)|(?:\}).+'){
                    $guid
                }
                else{
                    $program.pschildname
                }
                $program | Add-Member -MemberType NoteProperty -Name GUID -Value $guid -Force
            }

            if ($props -eq "All" -or $props -contains "All" -or $All) {$programs}
            else {$programs | Select-Object -Property $props | Add-Member -MemberType NoteProperty -Name ComputerName -Value $compName -PassThru}
        }

        Function Choose-Invocation($ProgName, $CompName) {
            if ($CompName -eq "." -or $CompName -eq "localhost" -or $CompName -eq $env:COMPUTERNAME) {
                & $ProgCmd $ProgName $Property
            }
            else {Invoke-Command -ScriptBlock $ProgCmd -ArgumentList $ProgName,$Property -ComputerName $CompName}
        }

        Function Get-ProgramFromRegistry ($ProgName, $CompName) {
            if ($ProgName) {
                foreach ($n in $ProgName) {
                    Choose-Invocation -ProgName $n -CompName $CompName
                }
            }
            else {
                Choose-Invocation -CompName $CompName
            }
        }
    }

    Process {
        foreach ($comp in $ComputerName) {
            $programlist = Get-ProgramFromRegistry -CompName $comp -ProgName $Name
            foreach($program in $programlist){
                foreach($propname in $program.psobject.properties){
                    if($propname.value -and $propname.name -notmatch '^ps'){
                        if($proplist -notcontains $propname.name){
                            $proplist.Add($propname.name)
                        }
                        else{
                            if($finalproplist -notcontains $propname.name){
                                $finalproplist.Add($propname.name)
                            }
                        }
                    }
                }
            }
            $programlist | Select-Object $finalproplist | Select-Object -ExcludeProperty ps*
        }
    }
}
