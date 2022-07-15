Function Invoke-RemoteExpression {
    ##############################################################################
    ##
    ## Invoke-RemoteExpression
    ##
    ## From Windows PowerShell Cookbook (O'Reilly)
    ## by Lee Holmes (http://www.leeholmes.com/guide)
    ##
    ##############################################################################

    <#
    .SYNOPSIS
        Invoke a PowerShell expression on a remote machine. Requires PsExec from
        http://live.sysinternals.com/tools/psexec.exe. If the remote machine
        supports PowerShell version two, use PowerShell remoting instead.

    .DESCRIPTION
        A major overhaul of a classic script written by the brilliant Lee Holmes. Added support for commands longer than 8190
        characters, multithreading, and support for running as System. Powershell remoting is almost always the way to go, but there
        are some times where it may not be available or working. The number one use case I've found is when a computers name exceeds
        15 characters. Next most common is occassional environment where someone made the poor decision to not enable PS Remoting.
    
    .PARAMETER ComputerName
        One or more computer names which can also be provided as pipeline input.
    
    .PARAMETER ScriptBlock
        The script/command to execute remotely. This can be a string or a scriptblock. If hidden admin share c$ is available, then any
        size script can be used. 
    
    .PARAMETER Credential
        The credential to be used for the remote execution. This can be a simple username (you will be prompted for password) or a 
        credential object.
    
    .PARAMETER NoProfile
        Specifies not to load the powershell profile on the remote system.
    
    .PARAMETER System
        Specifies to run powershell as 'NT Authority\System' on the remote system.
    
    .PARAMETER ThrottleLimit
        Specifies the maximum number of concurrent threads allowed. Defaults to 32.

    .EXAMPLE
        Invoke-RemoteExpression LEE-DESK 'Hostname;ipconfig /all'
        Retrieves the output of simple commands from a remote machine

    .EXAMPLE
        (Invoke-RemoteExpression LEE-DESK { Get-Date }).AddDays(1)
        Invokes a command on a remote machine. Since the command returns one of
        PowerShell's primitive types (a DateTime object,) you can manipulate
        its output as an object afterward.

    .EXAMPLE
        Invoke-RemoteExpression LEE-DESK { Get-Process } | Sort Handles
        Invokes a command on a remote machine. The command does not return one of
        PowerShell's primitive types, but you can still use PowerShell's filtering
        cmdlets to work with its structured output.
    
    .EXAMPLE
        $ComputerList | Invoke-RemoteExpression -ScriptBlock $ScriptBlock -Verbose
        Executes the defined scriptblock against the list of computers. This can be
        a simple string array of computer names or an object with ComputerName property.
    
    .LINK
        https://github.com/krzydoug/Tools/blob/master/Invoke-RemoteExpression.ps1
    
        
    #>

    param(
        [Parameter(Mandatory,Position = 0,ValueFromPipeline,ValueFromPipelineByPropertyName,HelpMessage='The computer(s) on which to invoke the command')]
        [string[]]$ComputerName,

        [Parameter(Mandatory,Position = 1,HelpMessage='The scriptblock to invoke on the remote machine(s)')]
        [string]$ScriptBlock,

        [Parameter(HelpMessage='The username/password to use for the remote connection')]
        [Alias('PSCredential')] 
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]$Credential,

        [Parameter(HelpMessage='Determines if powershell should load the user profile on the remote machine')]
        [switch]$NoProfile,

        [Parameter(HelpMessage='Determines if powershell should be executed as the system account on the remote machine')]
        [switch]$System,

        [Parameter(HelpMessage='Determines the maximum number of threads that can run concurrently')]
        [int]$ThrottleLimit = 32
    )

    begin{
        #Set-StrictMode -Version 3
        $ErrorActionPreference = "Stop"
        $title = $host.UI.RawUI.WindowTitle
        $file = "PsExec.exe"
        $path = $env:TEMP
        $psexec = Join-Path -Path $path -ChildPath $file

        Function Download-PsExec{
            #Sources:
            # blog.jourdant.me/3-ways-to-download-files-with-powershell/
            # blogs.technet.microsoft.com/heyscriptingguy/2011/06/17/manage-event-subscriptions-with-powershell/

            # global variables
            $global:lastpercentage = -1
            $global:are = New-Object System.Threading.AutoResetEvent $false

            # variables
            $global:file = "PsExec.exe"
            $global:path = $env:TEMP
            $uri = "https://live.sysinternals.com/PsExec.exe"
            $of = join-path -Path $env:temp -ChildPath "PsExec.exe"

            # web client
            # (!) output is buffered to disk -> great speed
            $wc = New-Object System.Net.WebClient

            Register-ObjectEvent -InputObject $wc -EventName DownloadProgressChanged -Action {
                # (!) getting event args
                $percentage = $event.sourceEventArgs.ProgressPercentage
                if($global:lastpercentage -lt $percentage)
                {
                    $global:lastpercentage = $percentage
                    # stackoverflow.com/questions/3896258
                    Write-progress -activity "Downloading PsExec" -PercentComplete $percentage -Status "Downloading $global:file to $global:path"
                }
            } > $null

            Register-ObjectEvent -InputObject $wc -EventName DownloadFileCompleted -Action {
                $global:are.Set()
            } > $null

            $wc.DownloadFileAsync($uri, $of)
            # ps script runs probably in one thread only (event is reised in same thread - blocking problems)
            # $global:are.WaitOne() not work
            while(!$global:are.WaitOne(500)) {}
            Remove-Variable -Name lastpercentage,are,file,path,of -ErrorAction SilentlyContinue
        }

        if(-not (Test-Path $psexec)){
            Download-PsExec
        }

        if(-not (Test-Path $psexec)){
            throw "PsExec.exe is required for this script to run"
            return
        }


        Write-Verbose "Building local psexec arguments and remote powershell command"
        ## Prepare the command line for PsExec. We use the XML output encoding so
        ## that PowerShell can convert the output back into structured objects.
        ## PowerShell expects that you pass it some input when being run by PsExec
        ## this way, so the 'echo .' statement satisfies that appetite.
        $commandLine = "echo . | powershell -Output XML -WindowStyle Hidden -ExecutionPolicy Unrestricted "

        Write-Verbose "Scriptblock length $($ScriptBlock.length)"
        $firstargs = New-Object System.Collections.Generic.List[string]
        $lastargs = New-Object System.Collections.Generic.List[string]
        $runspacelist = New-Object System.Collections.Generic.List[object]

        '-acceptEula','-nobanner' | ForEach-Object{
            $firstargs.Add($_)
        }

        if($noProfile){
            if($Credential){
                $firstargs.Add('-e')
            }

            $commandLine += "-NoProfile "
        }

        if($System){
            $firstargs.Add('-s')
        }

        if($Credential){
            # This lets users pass either a username, or full credential to our
            # credential parameter
            $credential = Get-Credential $credential
            $username = $Credential.Username
            $password = $Credential.GetNetworkCredential().Password

            '-i','-u',$username,'-p',$password | ForEach-Object {
                $lastargs.Add($_)
            }
        }
        
        ## Convert the command into an encoded command for PowerShell
        $commandBytes = [System.Text.Encoding]::Unicode.GetBytes($scriptblock)
        $encodedCommand = [Convert]::ToBase64String($commandBytes)
        Write-Verbose "Encodedcommand length $($Encodedcommand.length)"

        if($encodedCommand.length -gt 7800){
            Write-Verbose "Encoded scriptblock length exceeds limit for powershell"
            $commandLine += "-File c:\users\public\remoteexpression.ps1"
        }
        else{
            Write-Verbose "Encoded scriptblock length below limit for powershell"
            $commandLine += "-EncodedCommand $encodedCommand"
        }

        'powershell.exe',$commandLine | ForEach-Object{
            $lastargs.Add($_)
        }
        
        $InitialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        $InitialSessionState.Variables.Add([System.Management.Automation.Runspaces.SessionStateVariableEntry]::new('psexec',$psexec,'Path to psexec.exe'))
        $InitialSessionState.Variables.Add([System.Management.Automation.Runspaces.SessionStateVariableEntry]::new('firstargs',$firstargs,'First arguments for psexec'))
        $InitialSessionState.Variables.Add([System.Management.Automation.Runspaces.SessionStateVariableEntry]::new('lastargs',$lastargs,'Last arguments for psexec'))
        $InitialSessionState.Variables.Add([System.Management.Automation.Runspaces.SessionStateVariableEntry]::new('scriptblock',$scriptblock,'Script to run against remote system'))
        $pool = [RunspaceFactory]::CreateRunspacePool(1, $ThrottleLimit,$InitialSessionState,$Host)
        $pool.ApartmentState = "MTA"
        $pool.Open()

        $host.UI.RawUI.WindowTitle = 'Invoke-RemoteExpression'
        
        $script = {
            Param(
                $computer,
                $verbose
            )

            $errorfile = New-TemporaryFile

            if($lastargs -match '-File'){
                $remotefile = "\\$computer\c$\users\public\remoteexpression.ps1"

                Write-Verbose "Creating powershell script $remotefile for psexec" -Verbose:$verbose

                try{
                    $scriptblock | Set-Content -LiteralPath $remotefile
                }
                catch{
                    Write-Warning "An error occurred writing to $remotefile"
                    Write-Warning "Please verify $remotefile is accessible or provide a shorter script"
                    continue
                }
            }

            $psexecargs = $firstargs + "\\$Computer" + $lastargs
        
            Write-Verbose "Execute psexec command against \\$computer" -Verbose:$verbose
            
            # capture to a variable so powershell deserializes the return data
            $output = try{
                &$psexec @psexecargs 2>$errorfile
            }
            catch{
                $error[0] | Set-Content $errorfile
            }

            if(($output | Select-Object -First 1) -is [string]){
                [PSCustomObject]@{
                    ComputerName   = $Computer
                    Output         = $output
                }
            }
            else{
                $output | Add-Member -MemberType NoteProperty -Name ComputerName -Value $Computer -Force -PassThru
            }

            <#
            if($erroroutput -Match 'PsExec.exe : powershell.exe exited with error code (?<ErrorCode>\d*)' -and $matches.ErrorCode -ne 0){
                Write-Warning "An error occurred running PSExec"
                Write-Warning $error[0].Exception.Message
            }
            #>

            if($LASTEXITCODE -ne 0){
                
                $erroroutput = Get-Content -LiteralPath $errorfile.FullName | Where-Object {$_}

                $erroroutput | ForEach-Object {
                    if($_ -notmatch "Cannot process the XML from the 'Error' stream of|connecting to"){
                        Write-Warning " [$computer]  $_"
                    }
                }
            }
            
            Remove-Item -LiteralPath $errorfile.FullName -ErrorAction SilentlyContinue

            if($remotefile){
                Write-Verbose "Deleting script $remotefile" -Verbose:$verbose
                Remove-Item -LiteralPath $remotefile -ErrorAction SilentlyContinue
            }
        }

        $psexecargs = $firstargs + '\\$ComputerName' + $lastargs

        Write-Verbose "Psexec argument count: $($psexecargs.Count)"

        $psexecargs | ForEach-Object {
            if($maskpassword -eq $true){
                Write-Verbose "Argument: $('*' * (Get-Random (9..17)))"
                $maskpassword = $false
            }
            else{
                if($_ -eq '-p'){
                    $maskpassword = $true
                }
                Write-Verbose "Argument: $_"
            }
        }
    }
    
    process{
        try{
            foreach($computer in $ComputerName){
                Write-Verbose "Creating powershell runspace for computer $computer"

                $runspace = [PowerShell]::Create()
                $null = $runspace.AddScript($script)
                $null = $runspace.AddArgument($computer)
                $null = $runspace.AddArgument($PSBoundParameters.ContainsKey('Verbose'))
                $runspace.RunspacePool = $pool
                $runspacelist.Add([PSCustomObject]@{ Pipe = $runspace; Status = $runspace.BeginInvoke()})
            }
        }
        catch{
            Write-Warning $_.Exception.Message
        }
    }

    end{        
        try{
            while($runspacelist[0]){
                if($runspacelist[0].Status.IsCompleted){
                    $runspacelist[0].Pipe.EndInvoke($runspacelist[0].Status)
                    $runspacelist[0].Pipe.Dispose()
                    $runspacelist.RemoveAt(0)
                }

                Start-Sleep -Milliseconds 200
            }
        }
        finally{
            $runspace.RunspacePool.Close()
            $runspace.RunspacePool.Dispose()
        }

        $host.UI.RawUI.WindowTitle = $title
        
    }
    
}
