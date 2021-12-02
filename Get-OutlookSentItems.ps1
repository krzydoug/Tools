Function Get-OutlookSentItems {

    $email = {
        $(
            if($_.to -match '.+@.+\..+')
            {
                $_.to
            }
            elseif($($_.recipients).address -match '.+@.+\..+')
            {
                $($_.recipients).address
            }
            else
            {
                $($_.recipients).name}
        ) -join ', '
    }

    Add-type -assembly “Microsoft.Office.Interop.Outlook” | out-null
    $olFolders = “Microsoft.Office.Interop.Outlook.olDefaultFolders” -as [type]
    $outlook = new-object -comobject outlook.application
    $namespace = $outlook.GetNameSpace(“MAPI”)
    $folder = $namespace.getDefaultFolder($olFolders::olFolderSentMail)
    $folder.items | Select-Object -Property Subject, SentOn, Importance, @{n='To';e={& $email}}

} #end function Get-OutlookSentItems
