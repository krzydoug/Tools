Function Get-Windows11Iso {
    [cmdletbinding()]
    Param(
        $Path = 'c:\Windows\temp\',

        [parameter()]
        [ValidateSet("Arabic", "Brazilian Portuguese", "Bulgarian", "Chinese Simplified", "Chinese Traditional", "Croatian", "Czech", "Danish", "Dutch", "English (United States)", "English International", "Estonian", "Finnish", "French", "French Canadian", "German", "Greek", "Hebrew", "Hungarian", "Italian", "Japanese", "Korean", "Latvian", "Lithuanian", "Norwegian", "Polish", "Portuguese", "Romanian", "Russian", "Serbian Latin", "Slovak", "Slovenian", "Spanish", "Spanish (Mexico)", "Swedish", "Thai", "Turkish", "Ukrainian")]
        $Language = 'English (United States)'
    )

    $hashlookup = @{
        'Arabic'                  = 'Arabic 64-bit'
        'Brazilian Portuguese'    = 'Brazilian Portuguese 64-bit'
        'Bulgarian'               = 'Bulgarian 64-bit'
        'Chinese Simplified'      = 'Chinese Simplified 64-bit'
        'Chinese Traditional'     = 'Chinese Traditional 64-bit'
        'Croatian'                = 'Croatian 64-bit'
        'Danish'                  = 'Danish 64-bit'
        'Dutch'                   = 'Dutch 64-bit'
        'English (United States)' = 'English 64-bit'
        'English International'   = 'English International 64-bit'
        'Estonian'                = 'Estonian 64-bit'
        'Finnish'                 = 'Finnish 64-bit'
        'French'                  = 'French 64-bit'
        'French Canadian'         = 'French Canadian 64-bit'
        'German'                  = 'German 64-bit'
        'Greek'                   = 'Greek 64-bit'
        'Hebrew'                  = 'Hebrew 64-bit'
        'Hungarian'               = 'Hungarian 64-bit'
        'Italian'                 = 'Italian 64-bit'
        'Japanese'                = 'Japanese 64-bit'
        'Korean'                  = 'Korean 64-bit'
        'Latvian'                 = 'Latvian 64-bit'
        'Lithuanian'              = 'Lithuanian 64-bit'
        'Norwegian'               = 'Norwegian 64-bit'
        'Polish'                  = 'Polish 64-bit'
        'Portuguese'              = 'Portuguese 64-bit'
        'Romanian'                = 'Romanian 64-bit'
        'Russian'                 = 'Russian 64-bit'
        'Serbian Latin'           = 'Serbian Latin 64-bit'
        'Slovak'                  = 'Slovak 64-bit'
        'Slovenian'               = 'Slovenian 64-bit'
        'Spanish'                 = 'Spanish (Mexico) 64-bit'
        'Spanish (Mexico)'        = 'Spanish 64-bit'
        'Swedish'                 = 'Swedish 64-bit'
        'Thai'                    = 'Thai 64-bit'
        'Turkish'                 = 'Turkish 64-bit'
        'Ukrainian'               = 'Ukrainian 64-bit'
    }

    $ErrorActionPreference = 'Stop'

    Write-Host "[$(Get-Date -Format s)] Function initializing"

    $nuget = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue |
                    Sort-Object -Property {[version]$_.version} | Select-Object -Last 1

    if(-not $nuget -or [version]$nuget.version -lt [version]2.8.5.208){
        Write-Verbose "[$(Get-Date -Format s)] Installing NuGet 2.8.5.208"

        try{
            $null = Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.208 -Force
        }
        catch{
            Write-Warning "[$(Get-Date -Format s)] $($_.exception.message)"
        }
    }

    $modulelist = @'
        Name,Version
        Selenium,3.0.1
'@ | ConvertFrom-Csv
    
    foreach($module in $modulelist){
        if([version](Get-Module -ListAvailable -Name $module.name | Sort-Object -Property Version -Descending | Select-Object -First 1).Version -lt [version]$module.version){
            Write-Verbose "[$(Get-Date -Format s)] Installing $($module.name) module, version $($module.version)" -Verbose

            try{
                Install-Module $module.name -Force
            }
            catch{
                Write-Warning "[$(Get-Date -Format s)] $($_.exception.message)"
            }
        }
    }

    try{
        $firefox = Start-SeFirefox -Quiet -Headless
    }
    catch{}

    if(-not $firefox){
        Write-Verbose "[$(Get-Date -Format s)] Installing Firefox"

        $DateStamp = Get-Date -Format yyyyMMddTHHmmss
        $log = '{0}-{1}.log' -f $DateStamp,'Firefox_Installation'

        $MsiParams = @{
            FilePath     = 'msiexec.exe'

            ArgumentList = "/i",
                            "firefox.msi",
                            "/qn",
                            "/norestart",
                            "/L",
                            $log

            Wait         = [switch]::Present

            PassThru     = [switch]::Present
        }

        try{
            $result = Start-Process @MsiParams

            if($result.ExitCode -eq 0){
                Write-Verbose "[$(Get-Date -Format s)] MSI execution succeeded"
            }
            else{
                $msg = "[$(Get-Date -Format s)] Firefox MSI execution completed with error. ExitCode: $($result.ExitCode)"
                Write-Error $msg
            }
        }
        catch{
            $msg = "[$(Get-Date -Format s)] Error starting MSI installation: $($_.exception.message)"
            Write-Error $msg
        }

        $firefox = Start-SeFirefox -Quiet -Headless
    }

    if(-not $firefox){
        Write-Warning "[$(Get-Date -Format s)] unable to automatically create download link, please go to https://www.microsoft.com/software-download/windows11 and generate a download link"
        break
    }
    
    Write-Verbose "[$(Get-Date -Format s)] Loading Microsoft Windows 11 Software Download site"

    $firefox.Navigate().GoToUrl('https://www.microsoft.com/software-download/windows11')

    $downloadselector = $firefox.FindElement([OpenQA.Selenium.By]::XPath('//*[@id="product-edition"]'))
    $downloadselector.SendKeys('w')

    $downloadbutton = $firefox.FindElement([OpenQA.Selenium.By]::XPath('//*[@id="submit-product-edition"]'))
    $downloadbutton.Click()
    
    Write-Verbose "[$(Get-Date -Format s)] Setting iso language to $Language"

    $languageselector = $firefox.FindElement([OpenQA.Selenium.By]::XPath('//*[@id="product-languages"]'))
    $firstletter = $Language.Substring(0,1)
    $languagelist = $languageselector.text -split '\r?\n' -notmatch "^choose"
    $matchinglanguage = $languagelist -match "^$firstletter"
    $position = $matchinglanguage.IndexOf($Language) +1

    1..$position | ForEach-Object {
        $languageselector.SendKeys($firstletter)
        Start-Sleep -Milliseconds 200
    }

    Write-Verbose "[$(Get-Date -Format s)] Generating download link"

    $confirmbutton = $firefox.FindElement([OpenQA.Selenium.By]::XPath('//*[@id="submit-sku"]'))
    $confirmbutton.Click()

    try{
        $verifybutton = $firefox.FindElement([OpenQA.Selenium.By]::XPath("//span[contains(text(), 'Verify')]"))
        $verifybutton.Click()
    }
    catch{
        if($firefox.PageSource -match 'entities and locations are banned'){
            Write-Warning "[$(Get-Date -Format s)] Microsoft has blocked this automation, please download the ISO manually and pass as ISO argument"
            break
        }
        else{
            Write-Warning "[$(Get-Date -Format s)] $($_.Exception.message)"
        }
    }
    
    $downloadlink = $firefox.FindElement([OpenQA.Selenium.By]::XPath("//a[contains(@href, 'prss')]"))

    # TODO: dynamically handle hash lookup for all languages
    $checksum = $firefox.FindElements([OpenQA.Selenium.By]::XPath("//td[contains(text(), 'English') and not(contains(text(), 'International'))]/following-sibling::td")).text
    
    $expiration = $firefox.FindElement([OpenQA.Selenium.By]::XPath("//i[contains(text(), 'expire')]")).text -replace '^.+expire:\s'

    $link = $downloadlink.GetAttribute('href')
    $filename = $link -replace '^.+(?=Win11)|(?<=\.iso).+$'
    
    Write-Verbose "[$(Get-Date -Format s)] Download link: $link"
    Write-Verbose "[$(Get-Date -Format s)] Link expires: $expiration"
    Write-Verbose "[$(Get-Date -Format s)] Iso Filename: $filename"

    $fullpath = Join-Path $path $filename

    Write-Host "[$(Get-Date -Format s)] Downloading $filename"

    if(Test-Path $fullpath){
        Write-Verbose "[$(Get-Date -Format s)] $filename already exists at $fullpath, verifying hash" 

        $filehash = Get-FileHash $fullpath
        
        if($filehash.hash -eq $checksum){
            Write-Verbose "[$(Get-Date -Format s)] File hash matches checksum"
        }
        else{
            Write-Verbose "[$(Get-Date -Format s)] File hash does not match checksum"
            Remove-Item -LiteralPath $fullpath
            Write-Host "[$(Get-Date -Format s)] Downloading $filename to $fullpath"
            Invoke-WebRequest -Uri $link -UseBasicParsing -OutFile $fullpath
        }
    }
    else{
        Write-Host "[$(Get-Date -Format s)] Downloading $filename to $fullpath"
        Invoke-WebRequest -Uri $link -UseBasicParsing -OutFile $fullpath
    }

    $firefox.Dispose()
    Get-Item -LiteralPath $fullpath
}
