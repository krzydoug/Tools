Function Get-MsrcMonthlyUpdate {
    [cmdletbinding()]
    Param(
        [parameter()]
        [validateset('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec')]
        [string]$Month = (Get-Date -UFormat %b),

        [parameter()]
        [int]$Year = [datetime]::Now.Year,

        [parameter()]
        [switch]$Raw
    )

    if(-not (Get-Module -Name MsrcSecurityUpdates -ListAvailable)){
        Install-Module -Name MsrcSecurityUpdates -Force -Scope CurrentUser
        Import-Module -Name MsrcSecurityUpdates
    }

    $monthOfInterest = "$Year-$Month"

    Write-Verbose "Downloading $monthOfInterest rollup patch information from Microsoft"

    $reportdata = Get-MsrcCvrfDocument -ID  $MonthOfInterest | Get-MsrcCvrfAffectedSoftware

    if($Raw){
        $reportdata
        return
    }

    Write-Verbose "Sorting records with multiple KBArticle IDs to process seperately"

    $multiple,$single = $reportdata.where({@($_.kbarticle.id).count -gt 1},5)

    Write-Verbose "Extracting property names"

    $properties = $multiple | Select-Object -First 1 | ForEach-Object {
        $_.psobject.properties.name -notmatch 'kbarticle'
    }

    $selectprop = @{name="KBArticle";e={$kb.ID}},
                  @{name="KBUrl";e={$kb.Url}},
                  @{name="KBSubType";e={$kb.SubType}} +
                  $properties

    Write-Verbose "Converting each record with multiple KBArticle IDs into distinct objects"

    $grouped = $multiple + $single | ForEach-Object{
        foreach($kb in $_.kbarticle){
            $_ | Select-Object $selectprop
        }
    } | Group-Object -Property cve,kbarticle

    Write-Verbose "Grouping records with common CVE and KBArticle ID"

    $newprop = 'KBUrl', 'KBSubType' + $properties -notmatch 'CVE'

    Write-Verbose "Creating calculated properties"

    $calculatedprop = foreach($propname in $newprop){
        @{n=$propname;e={($_.group.$propname | Select-Object -Unique | Where-Object {$_}) -join '; '}.GetNewClosure()}
    }

    $combinedprop = @{n='CVE';e={$record.group[0].cve}},@{n='KBArticle';e={$record.group[0].KBArticle}} + $calculatedprop

    Write-Verbose "Creating new custom objects"

    foreach($record in $grouped){
        $record | Select-Object $combinedprop
    }
}
