# Visual acceptance check: drives the real EXE (tools/verify-window.ps1) and then
# asserts the produced artefacts, so a broken paint pass cannot pass silently.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$assets = Join-Path $PSScriptRoot '..\assets'

& (Join-Path $PSScriptRoot '..\tools\verify-window.ps1')
if (-not $?) { throw 'verify-window.ps1 failed' }

function Get-Bitmap([string]$name) {
    $path = Join-Path $assets $name
    if (-not (Test-Path $path)) { throw "missing screenshot $name" }
    $bitmap = New-Object System.Drawing.Bitmap $path
    if ($bitmap.Width -lt 1100 -or $bitmap.Height -lt 750) {
        $size = '{0}x{1}' -f $bitmap.Width, $bitmap.Height
        $bitmap.Dispose()
        throw "screenshot $name is $size, expected at least 1100x750"
    }
    return $bitmap
}

# The popover is drawn over the memory ring, so a large pixel delta in that band
# proves the panel was actually rendered instead of staying closed.
$idle = Get-Bitmap 'verify-idle.png'
$popover = Get-Bitmap 'verify-popover.png'
$copy = Get-Bitmap 'verify-copy.png'
$different = 0
$total = 0
for ($x = 30; $x -lt 430; $x += 4) {
    for ($y = 240; $y -lt 660; $y += 4) {
        $total++
        if ($idle.GetPixel($x, $y).ToArgb() -ne $popover.GetPixel($x, $y).ToArgb()) { $different++ }
    }
}
$ratio = [double]$different / [double]$total
Write-Output ('panel region delta: {0:P1} of {1} samples' -f $ratio, $total)
if ($ratio -lt 0.5) { throw "config panel was not rendered (delta $ratio)" }

$toastDelta = 0
for ($x = 760; $x -lt 1090; $x += 4) {
    for ($y = 700; $y -lt 760; $y += 4) {
        if ($popover.GetPixel($x, $y).ToArgb() -ne $copy.GetPixel($x, $y).ToArgb()) { $toastDelta++ }
    }
}
Write-Output "copy toast changed pixels: $toastDelta"
if ($toastDelta -lt 20) { throw 'copy confirmation toast did not appear' }

# The embedded icon must carry real artwork, not an empty/transparent frame.
$iconPath = Join-Path $assets 'verify-exe-icon.png'
if (-not (Test-Path $iconPath)) { throw 'missing verify-exe-icon.png' }
$iconBitmap = New-Object System.Drawing.Bitmap $iconPath
$opaque = 0
for ($x = 0; $x -lt $iconBitmap.Width; $x++) {
    for ($y = 0; $y -lt $iconBitmap.Height; $y++) {
        if ($iconBitmap.GetPixel($x, $y).A -gt 32) { $opaque++ }
    }
}
$iconRatio = [double]$opaque / [double]($iconBitmap.Width * $iconBitmap.Height)
Write-Output ('exe icon opaque coverage: {0:P1}' -f $iconRatio)
if ($iconRatio -lt 0.15) { throw "embedded icon looks empty (coverage $iconRatio)" }

$iconBitmap.Dispose()
$idle.Dispose()
$popover.Dispose()
$copy.Dispose()
Write-Output 'PASS: window renders, config panel opens, copy button works, tray commands work, icon embedded.'
