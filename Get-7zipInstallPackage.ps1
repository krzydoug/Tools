function Get-7zipInstallPackage {
    [cmdletbinding()]
    Param(
        [parameter(Position=0)]
        [validateset('Windows','Linux','Mac')]
        [alias('OS')]
        [string]$OperatingSystem
    )

    $baseurl = 'https://www.7-zip.org/'

    Write-Verbose "Searching for latest 7zip installation packages"

    $downloadlist = Invoke-WebRequest -Uri "$baseurl\download.html" -UseBasicParsing

    $pattern = '(?s)href="(?<URL>a.+?)(?=").+?\r?\n.+?>(?<Extension>\S+?)(?=<).+?\r?\n.+?>(?<System>.+?)(?=<)(.+?\r?\n.+?>(?<Description>.+?)(?=<))?'

    $downloadlist = switch -Regex ($downloadlist.RawContent -split '<TR>'){
        $pattern {
            if($Matches.Description){
                $description = $Matches.Description
                $Matches.Remove(1)
            }
            else{
                $Matches.Description = $description
            }

            $Matches.FileName = $Matches.URL -replace 'a/'
            $Matches.URL = "$baseurl{0}" -f $Matches.URL
            $Matches.Remove(0)

            [PSCustomObject]$Matches
        }
    }

    $downloadlist | Where-Object System -like *$OperatingSystem*
}
