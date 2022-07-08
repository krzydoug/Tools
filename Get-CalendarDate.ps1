function Get-CalendarDate {
    [cmdletbinding()]
    Param()
    
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object Windows.Forms.Form -Property @{
        StartPosition = [Windows.Forms.FormStartPosition]::CenterScreen
        Size          = New-Object Drawing.Size 243, 230
        Text          = 'Start Date'
        Topmost       = $true
    }

    $calendar = New-Object Windows.Forms.MonthCalendar -Property @{
        ShowTodayCircle   = $true
        MaxSelectionCount = 1
        Padding = 500
    }

    $form.Controls.Add($calendar)

    $okButton = New-Object Windows.Forms.Button -Property @{
        Location     = New-Object Drawing.Point 38, 165
        Size         = New-Object Drawing.Size 75, 23
        Text         = 'OK'
        DialogResult = [Windows.Forms.DialogResult]::OK
    }

    $form.AcceptButton = $okButton
    $form.Controls.Add($okButton)

    $cancelButton = New-Object Windows.Forms.Button -Property @{
        Location     = New-Object Drawing.Point 113, 165
        Size         = New-Object Drawing.Size 75, 23
        Text         = 'Cancel'
        DialogResult = [Windows.Forms.DialogResult]::Cancel
    }

    $form.CancelButton = $cancelButton
    $form.Controls.Add($cancelButton)

    try{
        $result = $form.ShowDialog()

        if ($result -eq [Windows.Forms.DialogResult]::OK){
            $calendar.SelectionStart
        }
    }
    catch{
        Write-Warning $_.exception.message
    }
    finally{
        $calendar.Dispose()
        $form.Close()
        $form.Dispose()
    }
}
