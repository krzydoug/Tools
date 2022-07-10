  Function Get-LogonEvent {
    [CmdletBinding()]

    param (

        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('ServerName', 'Server', 'Name')]
        [string[]]$ComputerName = 'localhost',

        [Parameter()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]$Credential,

        [Parameter()]
        [ValidateSet("Service", "Interactive", "RemoteInteractive", "NetworkCleartext", "CachedInteractive", "Unlock", "NewCredentials", "Network", "*")] 
        [string[]]$LogonType = @("Interactive", "RemoteInteractive", "CachedInteractive"),
        
        [Parameter()]
        [string]$UserName,

        [Parameter()]
        [switch]$Oldest,
    
        [Parameter()]
        [int64]$MaxEvents,

        [Parameter()]
        [datetime]$StartTime = [datetime]::Now.AddDays(-1000),

        [Parameter()]
        [datetime]$StopTime = [datetime]::Now
    
    )

    Begin {
        $ErrorActionPreference = 'Stop'

        Function Format-EventMessage {
            [CmdletBinding()]
        
            param( 
                [Parameter(ValueFromPipeline = $true)]
                $Event
            )

            Begin{
                $defaultDisplaySet = 'MachineName', 'Result', 'TimeCreated', 'TargetUserName'
                $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', [string[]]$defaultDisplaySet)
                $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
                $myHash = @{}
            }
            Process{
                $myHash['Result'] = switch ($Event.id){
                    4625 {"Failure"}
                    4624 {"Success"}
                }

                $myHash['ID'] = $Event.ID
                $myHash['TimeCreated'] = $Event.TimeCreated
                $myHash['MachineName'] = $Event.MachineName

                ([xml]($Event.ToXml())).event.eventdata.data | ForEach-Object{
                    $myHash[$PSItem.name] = $PSItem.'#text'
                }

                New-Object -TypeName PSObject -Property $myHash | ForEach-Object{ 
                
                    $PSItem.PSObject.TypeNames.Insert(0, "EventLogRecord.XMLParse")

                    $PSItem | Add-Member MemberSet PSStandardMembers $PSStandardMembers -PassThru 
                }
            }
        }

        $hashLogonType = @{
            Interactive       = 2
            Network           = 3
            Service           = 5
            Unlock            = 7
            NetworkCleartext  = 8
            NewCredentials    = 9
            RemoteInteractive = 10
            CachedInteractive = 11
        }

        $filter = @"
<QueryList>
<Query Id="0" Path="Security">
<Select Path="Security">
    *[System[
        (EventID=4624 or EventID=4625)            
        and TimeCreated[@SystemTime&gt;='{0}' and @SystemTime&lt;='{1}']
    ] 
        and EventData[
            Data[@Name='LogonType'] and ({2})
            {3}
        ]
    ]
</Select>
</Query>
</QueryList>
"@

    }

    Process{
        foreach ($computer in $ComputerName){            
        
            if ($UserName){
                $joinUserName = "and Data[@Name='TargetuserName'] and (Data='{0}')" -f $UserName
            }

            $joinLogonType = if ($LogonType -eq '*'){
                $hashLogonType.Values -replace '^', "Data='" -replace '$', "'" -join " or "
            }
            Else{
                $($LogonType | ForEach-Object {$hashLogonType[$PSItem]}) -replace '^', "Data='" -replace '$', "'" -join " or "
            }

            $computerFilter = $filter -f [string](Get-Date $StartTime).ToUniversalTime().GetDateTimeFormats('s'),
                                    [string](Get-Date $StopTime).ToUniversalTime().GetDateTimeFormats('s'),
                                    $joinLogonType,
                                    $joinUserName
       
            $hashEventParm = @{ 
                ComputerName = $computer
                FilterXml    = $computerFilter
                ErrorAction  = 'Stop'
            }

            if ($Credential){
                $hashEventParm['Credential'] = $Credential
            }

            if ($MaxEvents){
                $hashEventParm['MaxEvents'] = $MaxEvents
            }

            $computerFilter | Write-Verbose

            try{
                Get-WinEvent @hashEventParm | Format-EventMessage
            }
            catch {
                Write-Warning $_.exception.message
            }

        }

    }

    End {}
}
