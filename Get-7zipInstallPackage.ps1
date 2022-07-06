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

    $urlandext = 'href="(?<URL>a.+?)(?=").+?\r?\n.+?>(?<Extension>\S+?)(?=<)'

    $pattern = '(?s){0}.+?\r?\n.+?>(?<System>.+?)(?=<)(.+?\r?\n.+?>(?<Description>.+?)(?=<))?|{0}' -f $urlandext

    $downloadlist = switch -Regex ($downloadlist.RawContent -split '<TR>'){
        $pattern {
            if($Matches.Description){
                $description = $Matches.Description
                $system = $Matches.System
                $Matches.Remove(1)
            }
            else{
                $Matches.Description = $description
            }
            
            if(-not $Matches.System){
                $Matches.System = $system                
            }

            $Matches.FileName = $Matches.URL -replace 'a/'
            $Matches.URL = "$baseurl{0}" -f $Matches.URL
            $Matches.Remove(0)

            [PSCustomObject]$Matches
        }
    }

    $downloadlist | Where-Object System -like *$OperatingSystem*
}
