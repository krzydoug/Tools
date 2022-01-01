Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force -Confirm:$false

Invoke-Expression "& { $(Invoke-RestMethod 'https://aka.ms/install-powershell.ps1') } -UseMSI -AddExplorerContextMenu -Quiet" 

Start-Process pwsh.exe -ArgumentList "-NoExit","-command",{
    irm https://raw.githubusercontent.com/krzydoug/Tools/master/Test-TCPPort.ps1 | Invoke-Expression
    irm https://raw.githubusercontent.com/krzydoug/Tools/master/Get-Subnet.ps1 | Invoke-Expression

    $params = @{
        ComputerName  = ($subnet = Get-Subnet -Verbose).hostaddresses
        Port          = 20,21,22,25,80,443,1311,1433
        OutVariable   = 'results'
        ThrottleLimit = 200
    }

    Write-Host Testing ports $params.port on hosts $subnet.range -ForegroundColor Cyan

    [PSCustomObject]@{
        'Total hosts'      = ($hosts = $params.ComputerName.count)
        'Total ports'      = ($ports = $params.Port.count)
        'Total tests'      = ($total = $hosts * $ports)
        'Total seconds'    = ($seconds = (Measure-Command -Expression {Test-TCPPort @params | Out-GridView}).totalseconds)
        'Tests per second' = $total / $seconds
        'Total open ports' = $results.foreach{$_.psobject.members.where{$_.value -eq $true}}.count
    }

    Read-Host -Prompt 'Press enter to complete'
}
