function Get-ADConnectVersionHistory {

    [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
    $URI="https://docs.microsoft.com/en-us/azure/active-directory/hybrid/reference-connect-version-history"
    $webclient = New-Object System.Net.WebClient
    $result = $webclient.DownloadString($URI)
    $pattern = '(?s)h2.+?>(?<version>.+?)</h2.+(note|ease-status).+?<p>((?<date>\d{1,2}/\d{1,2}/\d{4}):\s(?<Status>.+?)(?=</p>)).+?(?<items>(fixe|ional-changes).+</(p|ul)>)'

    foreach($section in $result -split '(?=<h2)'){
        if($section -match $pattern){
            $items = $Matches.Items

            [PSCustomObject]@{
                Version = $Matches.version
                Date    = $Matches.date
                Status  = $Matches.Status
                Fixes   = if($items -match '(?s)(?<bugfix>fixe.+</(ul|li|p)>)'){
                    [regex]::Matches($Matches.bugfix,'(?s)(?<=<(li|p)>).+?(?=</(li|p)>)').value -replace '</?(p|li|ul)>'
                }
                else{
                    'No bug fixes'
                }

                Changes = if($items -match '(?s)(?<func>ional-changes.+</p?)(.+?<h3|ul)'){
                    [regex]::Matches($Matches.func,'(?s)(?<=<(li|p)>).+?(?=</(li|p))').value -replace '<p>'
                }
                else{
                    'No functional changes'
                }
            }
        }
    }
}
