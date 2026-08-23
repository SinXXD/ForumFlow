Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function New-RoundedPath {
    param(
        [float]$X,
        [float]$Y,
        [float]$Width,
        [float]$Height,
        [float]$Radius
    )

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $diameter = $Radius * 2
    $path.AddArc($X, $Y, $diameter, $diameter, 180, 90)
    $path.AddArc($X + $Width - $diameter, $Y, $diameter, $diameter, 270, 90)
    $path.AddArc($X + $Width - $diameter, $Y + $Height - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($X, $Y + $Height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function New-ForumFlowBitmap {
    param(
        [int]$Size,
        [switch]$Light
    )

    $scale = $Size / 1024.0
    $bitmap = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.Clear([System.Drawing.Color]::Transparent)

    if ($Light) {
        $outer = [System.Drawing.Color]::FromArgb(233, 238, 255)
        $inner = [System.Drawing.Color]::FromArgb(249, 251, 255)
        $bubble = [System.Drawing.Color]::FromArgb(36, 53, 104)
        $markStart = [System.Drawing.Color]::FromArgb(26, 191, 155)
        $markEnd = [System.Drawing.Color]::FromArgb(138, 93, 231)
    } else {
        $outer = [System.Drawing.Color]::FromArgb(9, 15, 37)
        $inner = $null
        $bubble = [System.Drawing.Color]::FromArgb(248, 251, 255)
        $markStart = [System.Drawing.Color]::FromArgb(112, 242, 208)
        $markEnd = [System.Drawing.Color]::FromArgb(196, 168, 255)
    }

    $outerPath = New-RoundedPath (24 * $scale) (24 * $scale) (976 * $scale) (976 * $scale) (244 * $scale)
    $graphics.FillPath((New-Object System.Drawing.SolidBrush($outer)), $outerPath)
    $outerPath.Dispose()

    $innerPath = New-RoundedPath (56 * $scale) (56 * $scale) (912 * $scale) (912 * $scale) (220 * $scale)
    $innerRect = New-Object System.Drawing.RectangleF((56 * $scale), (56 * $scale), (912 * $scale), (912 * $scale))
    if ($Light) {
        $graphics.FillPath((New-Object System.Drawing.SolidBrush($inner)), $innerPath)
    } else {
        $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($innerRect, [System.Drawing.Color]::FromArgb(16, 26, 58), [System.Drawing.Color]::FromArgb(107, 86, 217), 45)
        $graphics.FillPath($bgBrush, $innerPath)
        $bgBrush.Dispose()
    }
    $innerPath.Dispose()

    $glowA = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(28, 139, 124, 255))
    $graphics.FillEllipse($glowA, (624 * $scale), (38 * $scale), (340 * $scale), (340 * $scale))
    $glowA.Dispose()
    $glowB = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(25, 75, 224, 192))
    $graphics.FillEllipse($glowB, (56 * $scale), (620 * $scale), (320 * $scale), (320 * $scale))
    $glowB.Dispose()

    $topPath = New-RoundedPath (286 * $scale) (250 * $scale) (450 * $scale) (298 * $scale) (120 * $scale)
    $graphics.FillPath((New-Object System.Drawing.SolidBrush($bubble)), $topPath)
    $topPath.Dispose()
    $topTail = [System.Drawing.PointF[]]@(
        (New-Object System.Drawing.PointF((366 * $scale), (490 * $scale))),
        (New-Object System.Drawing.PointF((366 * $scale), (644 * $scale))),
        (New-Object System.Drawing.PointF((510 * $scale), (548 * $scale)))
    )
    $graphics.FillPolygon((New-Object System.Drawing.SolidBrush($bubble)), $topTail)

    $lineBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(52, 68, 141))
    $linePen = New-Object System.Drawing.Pen($lineBrush, (34 * $scale))
    $linePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $linePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $graphics.DrawLine($linePen, (354 * $scale), (438 * $scale), (614 * $scale), (438 * $scale))
    $graphics.DrawLine($linePen, (354 * $scale), (510 * $scale), (508 * $scale), (510 * $scale))
    $linePen.Dispose()
    $lineBrush.Dispose()
    $dot = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(112, 242, 208))
    $graphics.FillEllipse($dot, (649 * $scale), (493 * $scale), (34 * $scale), (34 * $scale))
    $dot.Dispose()

    $bottomPath = New-RoundedPath (388 * $scale) (536 * $scale) (364 * $scale) (266 * $scale) (112 * $scale)
    $bottomRect = New-Object System.Drawing.RectangleF((388 * $scale), (536 * $scale), (364 * $scale), (266 * $scale))
    $markBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($bottomRect, $markStart, $markEnd, 45)
    $graphics.FillPath($markBrush, $bottomPath)
    $markBrush.Dispose()
    $bottomPath.Dispose()
    $bottomTail = [System.Drawing.PointF[]]@(
        (New-Object System.Drawing.PointF((410 * $scale), (700 * $scale))),
        (New-Object System.Drawing.PointF((410 * $scale), (784 * $scale))),
        (New-Object System.Drawing.PointF((508 * $scale), (700 * $scale)))
    )
    $bottomTailBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($bottomRect, $markStart, $markEnd, 45)
    $graphics.FillPolygon($bottomTailBrush, $bottomTail)
    $bottomTailBrush.Dispose()

    $bottomPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(24, 37, 90), (30 * $scale))
    $bottomPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $bottomPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $graphics.DrawLine($bottomPen, (486 * $scale), (670 * $scale), (662 * $scale), (670 * $scale))
    $graphics.DrawLine($bottomPen, (486 * $scale), (732 * $scale), (594 * $scale), (732 * $scale))
    $bottomPen.Dispose()
    $bottomDot = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(24, 37, 90))
    $graphics.FillEllipse($bottomDot, (689 * $scale), (717 * $scale), (30 * $scale), (30 * $scale))
    $bottomDot.Dispose()

    $graphics.Dispose()
    return $bitmap
}

function Save-Png {
    param([System.Drawing.Bitmap]$Bitmap, [string]$Path)
    $directory = Split-Path -Parent $Path
    if (!(Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $Bitmap.Dispose()
}

function Get-PngBytes {
    param([System.Drawing.Bitmap]$Bitmap)
    $stream = New-Object System.IO.MemoryStream
    $Bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
    $bytes = $stream.ToArray()
    $stream.Dispose()
    $Bitmap.Dispose()
    # Preserve the byte array as one pipeline value; otherwise PowerShell
    # expands it into an object array and BinaryWriter selects the wrong
    # overload when writing the ICO payload.
    return ,([byte[]]$bytes)
}

function Write-Ico {
    param([string]$Path, [object[]]$Entries)
    $directory = Split-Path -Parent $Path
    if (!(Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    $stream = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Create)
    $writer = New-Object System.IO.BinaryWriter($stream)
    $writer.Write([uint16]0)
    $writer.Write([uint16]1)
    $writer.Write([uint16]$Entries.Count)
    $offset = 6 + (16 * $Entries.Count)
    foreach ($entry in $Entries) {
        $dimension = if ($entry.Size -ge 256) { 0 } else { [byte]$entry.Size }
        $writer.Write([byte]$dimension)
        $writer.Write([byte]$dimension)
        $writer.Write([byte]0)
        $writer.Write([byte]0)
        $writer.Write([uint16]1)
        $writer.Write([uint16]32)
        $writer.Write([uint32]$entry.Bytes.Length)
        $writer.Write([uint32]$offset)
        $offset += $entry.Bytes.Length
    }
    foreach ($entry in $Entries) {
        $payload = [byte[]]$entry.Bytes
        $writer.Write($payload, 0, $payload.Length)
    }
    $writer.Dispose()
    $stream.Dispose()
}

$androidSizes = @{
    'mipmap-mdpi' = 48
    'mipmap-hdpi' = 72
    'mipmap-xhdpi' = 96
    'mipmap-xxhdpi' = 144
    'mipmap-xxxhdpi' = 192
}
foreach ($resourceDir in $androidSizes.Keys) {
    $size = $androidSizes[$resourceDir]
    $nightResourceDir = $resourceDir -replace '^mipmap-', 'mipmap-night-'
    foreach ($dirName in @($resourceDir, $nightResourceDir)) {
        $dir = Join-Path $root "android/app/src/main/res/$dirName"
        foreach ($name in @('ic_launcher.png', 'ic_launcher_modern.png')) {
            Save-Png (New-ForumFlowBitmap $size) (Join-Path $dir $name)
        }
    }
}

foreach ($target in @(
    @{ Path = 'web/icons/Icon-192.png'; Size = 192 },
    @{ Path = 'web/icons/Icon-512.png'; Size = 512 },
    @{ Path = 'web/icons/Icon-maskable-192.png'; Size = 192 },
    @{ Path = 'web/icons/Icon-maskable-512.png'; Size = 512 },
    @{ Path = 'web/favicon.png'; Size = 64 },
    @{ Path = 'flatpak/icons/app.forumflow.png'; Size = 512 }
)) {
    Save-Png (New-ForumFlowBitmap $target.Size) (Join-Path $root $target.Path)
}

# iOS keeps separate light/dark renditions for both selectable icon styles.
foreach ($target in @(
    @{ Path = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/AppIcon-Dark-1024x1024.png'; Size = 1024 },
    @{ Path = 'ios/Runner/Assets.xcassets/ModernIcon.appiconset/ModernIcon-Dark-1024x1024.png'; Size = 1024 }
)) {
    Save-Png (New-ForumFlowBitmap $target.Size) (Join-Path $root $target.Path)
}
foreach ($target in @(
    @{ Path = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/AppIcon-Light-1024x1024.png'; Size = 1024 },
    @{ Path = 'ios/Runner/Assets.xcassets/ModernIcon.appiconset/ModernIcon-Light-1024x1024.png'; Size = 1024 },
    @{ Path = 'assets/images/icon_default_preview.png'; Size = 512 },
    @{ Path = 'assets/images/icon_modern_light_preview.png'; Size = 512 }
)) {
    Save-Png (New-ForumFlowBitmap $target.Size -Light) (Join-Path $root $target.Path)
}
Save-Png (New-ForumFlowBitmap 512) (Join-Path $root 'assets/images/icon_default_dark_preview.png')
Save-Png (New-ForumFlowBitmap 512) (Join-Path $root 'assets/images/icon_modern_preview.png')

$macSizes = @{
    16 = 16; 32 = 32; 64 = 64; 128 = 128; 256 = 256; 512 = 512; 1024 = 1024
}
foreach ($entry in $macSizes.GetEnumerator()) {
    Save-Png (New-ForumFlowBitmap $entry.Value) (Join-Path $root "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$($entry.Key).png")
}

$icoEntries = @()
foreach ($size in @(16, 32, 48, 64, 128, 256)) {
    $icoEntries += [pscustomobject]@{ Size = $size; Bytes = Get-PngBytes (New-ForumFlowBitmap $size) }
}
Write-Ico (Join-Path $root 'windows/runner/resources/app_icon.ico') $icoEntries

Write-Host 'Generated ForumFlow icons for Android, Web, iOS, macOS, Flatpak, and Windows.'
