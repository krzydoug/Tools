Function Get-ExchangeOnlineReport {
    [cmdletbinding()]
    Param(
	    $Path
    )

    begin{
        $ErrorActionPreference = 'Stop'
	
        Write-Verbose "Prompting user for export folder" -Verbose

        $shell = New-Object -ComObject wscript.shell

        if(-not $Path){
            $folder = (New-Object -ComObject Shell.Application).browseforfolder(0,"Choose location for export",16384,17)
    
            if($folder = $folder.Self.Path){
                $Path = $folder
            }
            else{
                Write-Warning "No folder was selected for export"
                pause
                return
            }
        }

        $version = "2.8.5.208"

        Write-Verbose "Verifying NuGet $version or later is installed" -Verbose

        $nuget = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue |
                     Sort-Object -Property {[version]$_.version} | Select-Object -Last 1

        if(-not $nuget -or [version]$nuget.version -lt [version]$version){
            Write-Verbose "Installing NuGet $($nuget.Version)" -Verbose
            $null = Install-PackageProvider -Name NuGet -MinimumVersion $nuget.version -Force
        }

        $version = '3.0.0'

        Write-Verbose "Verifying ExchangeOnlineManagement $version or later is installed" -Verbose

        $exchangemodule = Get-Module -ListAvailable -Name ExchangeOnlineManagement |
                     Sort-Object -Property {[version]$_.version} | Select-Object -Last 1

        if(-not $exchangemodule -or [version]$exchangemodule.version -lt [version]$version){
            $exchangemodule = Find-Module -Name ExchangeOnlineManagement |
                     Sort-Object -Property {[version]$_.version} | Select-Object -Last 1

            Write-Verbose "Installing ExchangeOnlineManagement $($exchangemodule.Version)" -Verbose
            $exchangemodule | Install-Module -Force
        }
    
        Write-Verbose "Verifying ImportExcel module is installed" -Verbose

        $excelmodule = Get-Module -ListAvailable -Name ImportExcel

        if(-not $excelmodule){
            $excelmodule = Find-Module -Name ImportExcel -AllVersions |
                     Sort-Object -Property {[version]$_.version} | Select-Object -Last 1

            Write-Verbose "Installing ImportExcel $($excelmodule.Version)" -Verbose
            $excelmodule | Install-Module -Force
        }

        Write-Verbose "Connecting to ExchangeOnline" -Verbose

        try{
            Connect-ExchangeOnline -ShowBanner:$false
        }
        catch{
            Write-Warning $_.exception.message
            pause
            break
        }

        $report = Join-Path $Path ("ExchangeOnline_$(Get-Date -UFormat "%Y-%m-%d_%H-%M-%S").xlsx")

        Function Export-Sheet {
            [cmdletbinding()]
            Param(
                [parameter()]
                [object[]]$InputObject,

                [string]$WorkSheetName
            )

            Write-Verbose "Exporting worksheet $WorkSheetName" -Verbose

            if($InputObject){
                $proplist = $InputObject[0].psobject.properties.name

                $InputObject | ForEach-Object {
                    foreach($prop in $proplist){
                        $_.$prop = $($_.$prop) -join '; '
                    }
                }
            }
            else{
                $inputObject = [PSCustomObject]@{NO_RECORDS = 'There were no records found for this report'}
            }

            $styles = @(
                11, 2, 6, 5 | ForEach-Object {"Dark$_"}
                2, 6, 7, 9, 10, 13, 14, 16, 17, 20, 21 | ForEach-Object {"Medium$_"}
                9, 10, 13, 14 | ForEach-Object {"Light$_"}
            )

            if(-not $excelparams){
                $excelparams = @{
                    Path         = $report
                    AutoSize     = $true
                    AutoFilter   = $true
                    Clearsheet   = $true
                    BoldTopRow   = $true
                    FreezeTopRow = $true
                }
            }

            $excelparams.WorksheetName = $WorkSheetName
            $excelparams.TableStyle = Get-Random $styles

            try{
                $($InputObject) | Export-Excel @excelparams
            }
            catch{
                Write-Warning $_.exception.message
            }
        }

        $statlist = New-Object System.Collections.Generic.List[object]

        $fwdrulelist = New-Object System.Collections.Generic.List[object]

        $mailboxtype = 'RoomMailbox', 'EquipmentMailbox', 'SchedulingMailbox',
                'LegacyMailbox', 'LinkedMailbox', 'LinkedRoomMailbox',
                'UserMailbox', 'TeamMailbox', 'SharedMailbox', 'GroupMailbox'

        $dgtype = 'MailNonUniversalGroup', 'MailUniversalDistributionGroup',
                  'MailUniversalSecurityGroup', 'RoomList'

    }

    process {
        Write-Verbose "Gathering distribution groups" -Verbose

        $dglist = Get-DistributionGroup -ResultSize Unlimited -RecipientTypeDetails $dgtype | Select-Object -Property *

        $dglistbrief = $dglist | ForEach-Object {
            Write-Verbose "Gathering members for distribution group $($_.DisplayName)" -Verbose

            $members = Get-DistributionGroupMember -Identity $_.samaccountname

            $memberlist = foreach($member in $members){
                "$($member.name) ($($member.primarysmtpaddress))"
            }

            $_ | Add-Member -NotePropertyName Members -NotePropertyValue ($memberlist -join '; ') -Force

            [PScustomObject]@{
                GroupName     = $_.Name
                DisplayName   = $_.DisplayName
                GroupType     = $_.GroupType
                Emailaddress  = $_.PrimarySmtpAddress
                IsDirSynced   = $_.IsDirSynced
                RecipientType = $_.RecipientTypeDetails
                Members       = $memberlist -join '; '
            }
        }

        Write-Verbose "Gathering mailbox list" -Verbose

        try{
            $mailboxlist = Get-EXOMailbox -ResultSize unlimited -RecipientTypeDetails $mailboxtype -PropertySets All | Select-Object -Property *
        }
        catch{
            Write-Warning $_.exception.message
        }

        $mailboxlistbrief = foreach($mailbox in $mailboxlist){
        
            Write-Verbose "Gathering details for mailbox $($mailbox.UserPrincipalName)" -Verbose

            try{
                $stats = Get-MailboxStatistics -Identity $mailbox.identity |
                    Select-Object -Property @{n='Mailbox';e={"$($mailbox.DisplayName) ($($mailbox.PrimarySmtpAddress))"}},*
            }
            catch{
                Write-Warning $_.exception.message
            }

            $statlist.Add($stats)

            [PSCustomObject]@{
                DisplayName        = $mailbox.DisplayName
                Alias              = $mailbox.Alias
                UserPrincipalName  = $mailbox.UserPrincipalName
                PrimarySmtpAddress = $mailbox.PrimarySmtpAddress
                MailboxSize        = $stats.TotalItemSize
                RecipientType      = $mailbox.RecipientTypeDetails
                EmailAddresses     = @($mailbox.EmailAddresses -CMatch 'smtp') -notmatch 'onmicrosoft' -Replace 'smtp:' -join '; '
            }

        }
    
        Write-Verbose "Gathering mail contact list" -Verbose

        try{
            $mailcontact = Get-MailUser -ResultSize unlimited
        }
        catch{
            Write-Warning $_.exception.message
        }
    
        try{
            $mailcontactbrief = $mailcontact | 
                Select-Object -Property DisplayName, PrimarySmtpAddress, Name,
                                                     @{n='HiddenFromGAL';e={$_.HiddenFromAddressListsEnabled}},
                                                     OtherMail, @{n='RecipientType';e={$_.RecipientTypeDetails}}, WhenCreated
        }
        catch{
            Write-Warning $_.exception.message
        }
    
        Write-Verbose "Gathering account forwarding details" -Verbose

        $forwardlist = $mailboxlist | Where-Object {
            $_.forwardingaddress -or
            $_.forwardingsmtpaddress
        } | Select-Object -Property DisplayName, PrimarySmtpAddress, *Forward*
    
        $inboxrulelist = foreach($mailbox in $mailboxlistbrief){
            Write-Verbose "Processing inbox rules for $($mailbox.PrimarySmtpAddress)" -Verbose

            try{
                $rules = Get-InboxRule -Mailbox $mailbox.PrimarySmtpAddress
            }
            catch{
                Write-Warning $_.exception.message
            }

            foreach($rule in $rules | Where-Object {
                $_.forwardto -or
                $_.forwardasattachmentto
            }){
                $recipients = $($rule.forwardto),$($rule.forwardasattachmentto)

                $fwdrulelist.Add(
                    [PSCustomObject]@{
                        DisplayName        = $mailbox.DisplayName
                        PrimarySmtpAddress = $mailbox.PrimarySmtpAddress
                        RuleId             = $rule.Identity
                        RuleName           = $rule.Name
                        RuleDescription    = $rule.Description
                        ForwardTo          = $recipients -join '; '
                    }
                )
            }

            $rules | Select-Object -Property @{n='Mailbox';e={"$($mailbox.DisplayName) ($($mailbox.PrimarySmtpAddress))"}},*
        }

        Write-Verbose "Building report $report" -Verbose

        Export-Sheet -InputObject $mailboxlistbrief -WorkSheetName "Mailbox list"
        Export-Sheet -InputObject $dglistbrief -WorkSheetName "Distribution Group list"
        Export-Sheet -InputObject $mailcontactbrief -WorkSheetName "Mail contact list"
        Export-Sheet -InputObject $forwardlist -WorkSheetName "Account forwarding"
        Export-Sheet -InputObject $fwdrulelist -WorkSheetName "Inbox rule forwarding"
        Export-Sheet -InputObject $mailboxlist -WorkSheetName "Detailed mailbox list"
        Export-Sheet -InputObject $dglist -WorkSheetName "Detailed DG list"
        Export-Sheet -InputObject $mailcontact -WorkSheetName "Detailed mail contact list"
        Export-Sheet -InputObject $inboxrulelist -WorkSheetName "All inbox rule list"
        Export-Sheet -InputObject $statlist -WorkSheetName "Mailbox statistics"

        Write-Verbose "Exchange Online report complete" -Verbose

        pause

        explorer (Split-Path $report -Parent)

    }

}
