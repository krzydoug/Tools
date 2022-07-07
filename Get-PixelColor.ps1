Function Get-PixelColor {
    <#
    .SYNOPSIS
    Gets the color of the pixel under the mouse, or of the specified space.
    .DESCRIPTION
    Returns the pixel color either under the mouse, or of a location onscreen using X/Y locating.
    If no parameters are supplied, the mouse cursor position will be retrieved and used.

    Current Version - 1.0
    .EXAMPLE
    Get-PixelColor
    Returns the color of the pixel directly under the mouse cursor.
    .EXAMPLE
    Get-PixelColor -X 300 -Y 300
    Returns the color of the pixel 300 pixels from the top of the screen and 300 pixels from the left.
    .PARAMETER X
    Distance from the top of the screen to retrieve color, in pixels.
    .PARAMETER Y
    Distance from the left of the screen to retrieve color, in pixels.
    .NOTES

    Revision History
    Version 1.0
        - Live release.  Contains two parameter sets - an empty default, and an X/Y set.
    Version 2.0 Doug Maurer
        - Simplified.
    #>

    #Requires -Version 4.0

    [CmdletBinding(DefaultParameterSetName='None')]

    param(
        [Parameter()]
        [Int]
        $X,

        [Parameter()]
        [Int]
        $Y
    )
    
    begin {
        Add-Type -AssemblyName PresentationFramework
        Add-Type -AssemblyName System.Drawing
        Add-Type -AssemblyName System.Windows.Forms

        if(-not $X){
            $X = ([System.Windows.Forms.Cursor]::Position).X
        }

        if(-not $Y){
            $Y = ([System.Windows.Forms.Cursor]::Position).Y
        }
    }

    process {
        $map = [System.Drawing.Rectangle]::FromLTRB($X, $Y, $X + 1, $Y + 1)
        $bmp = New-Object System.Drawing.Bitmap(1,1)
        $graphics = [System.Drawing.Graphics]::FromImage($bmp)
        $graphics.CopyFromScreen($map.Location, [System.Drawing.Point]::Empty, $map.Size)
        $pixel = $bmp.GetPixel(0,0)

        [PSCustomObject]@{
            X = $X
            Y = $Y
            Red = $pixel.R
            Green = $pixel.G
            Blue = $pixel.B
        }
    }
}
