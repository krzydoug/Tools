Function Get-FileTypeAssociation {
    [cmdletbinding()]
    Param(
        $Extension,
        $FileType
    )
    
    $extassociations = Get-FileExtensionAssociation

    $exttable = $extassociations | Group-Object -Property Association -AsHashTable -AsString

    $results = (cmd /c ftype) | ForEach-Object {
        $arr = $_ -split '(?<=^[^=]*)='
        [PSCustomObject]@{
            FileType     = $arr[0]
            Extension    = $exttable[$arr[0]].FileExtension
            Command      = $arr[1]
        }
    }

    if($Extension){
        Write-Verbose "Filtering extension by $Extension"
        $results | Where-Object Extension -like *$extension*
    }
    elseif($FileType){
        Write-Verbose "Filtering filetype by $FileType"
        $results | Where-Object FileType -eq $FileType
    }
    else{
        $results
    }
}

Function Get-FileExtensionAssociation {
    [cmdletbinding()]
    Param(
        $Extension = '*'
    )

    $results = (cmd /c assoc) | ForEach-Object {
        $arr = $_ -split '(?<=^[^=]*)='

        [PSCustomObject]@{
            FileExtension = $arr[0]
            Association   = $arr[1]
        }
    }

    $results | Where-Object FileExtension -like *$extension*
}

Register-ArgumentCompleter -CommandName Get-FileExtensionAssociation -ParameterName Extension -ScriptBlock {
    param(
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters
    )

    $extlist = (Get-FileExtensionAssociation).FileExtension | Sort

    $extlist | Where-Object {
        $_ -match [regex]::Escape("$wordToComplete")
    }
}

Register-ArgumentCompleter -CommandName Get-FileTypeAssociation -ParameterName Extension -ScriptBlock {
    param(
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters
    )

    $extlist = (Get-FileTypeAssociation).Extension | Sort

    $extlist | Where-Object {
        $_ -match [regex]::Escape("$wordToComplete")
    }
}

Register-ArgumentCompleter -CommandName Get-FileTypeAssociation -ParameterName FileType -ScriptBlock {
    param(
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters
    )

    $filetypelist = (Get-FileTypeAssociation).FileType | Sort

    $filetypelist | Where-Object {
        $_ -match "^$wordToComplete"
    }
}
