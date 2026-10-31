# Verifies a persisted custom background image is painted behind the cards.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class BgUi {
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    public struct RECT { public int Left, Top, Right, Bottom; }
}
'@
$exe = (Resolve-Path (Join-Path $PSScriptRoot '..\outputs\NovaMemory-final.exe')).Path
$out = Join-Path $PSScriptRoot '..\assets'
$settings = Join-Path $env:APPDATA 'NovaMemory\settings.json'
$backup = Join-Path $env:TEMP 'nova-settings-backup.json'
$image = (Resolve-Path (Join-Path $PSScriptRoot '..\assets\cat-fish.jpg')).Path -replace '\\', '/'

Get-Process NovaMemory* -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 300
Copy-Item $settings $backup -Force

function Save-Shot([IntPtr]$handle, [string]$name) {
    $window = New-Object 'BgUi+RECT'
    [BgUi]::GetWindowRect($handle, [ref]$window) | Out-Null
    [BgUi]::SetForegroundWindow($handle) | Out-Null
    Start-Sleep -Milliseconds 150
    $bitmap = New-Object System.Drawing.Bitmap ($window.Right - $window.Left), ($window.Bottom - $window.Top)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($window.Left, $window.Top, 0, 0, $bitmap.Size)
    $bitmap.Save((Join-Path $out $name), [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose(); $bitmap.Dispose()
    Write-Output "captured $name"
}

function Click-Client([IntPtr]$handle, [int]$x, [int]$y) {
    $lparam = [IntPtr](($y -shl 16) -bor ($x -band 0xFFFF))
    [BgUi]::PostMessageW($handle, 0x0201, [IntPtr]1, $lparam) | Out-Null
    Start-Sleep -Milliseconds 70
    [BgUi]::PostMessageW($handle, 0x0202, [IntPtr]0, $lparam) | Out-Null
    Start-Sleep -Milliseconds 350
}

$process = Start-Process -FilePath $exe -ArgumentList '--no-elevate' -PassThru
try {
    for ($i = 0; $i -lt 60 -and $process.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $process.Refresh() }
    $handle = $process.MainWindowHandle
    if ($handle -eq 0) { throw 'window did not appear' }
    if (-not $process.HasExited) { $process.Kill() }
    $process.WaitForExit(3000) | Out-Null
    Start-Sleep -Milliseconds 400

    $raw = Get-Content $settings -Raw
    $json = $raw | ConvertFrom-Json
    $json | Add-Member -NotePropertyName background -NotePropertyValue $image -Force
    ($json | ConvertTo-Json -Depth 4) | Set-Content -Path $settings -Encoding UTF8
    Write-Output "settings background: $((Get-Content $settings -Raw | ConvertFrom-Json).background)"

    $process = Start-Process -FilePath $exe -ArgumentList '--no-elevate' -PassThru
    for ($i = 0; $i -lt 60 -and $process.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $process.Refresh() }
    $handle = $process.MainWindowHandle
    [BgUi]::ShowWindow($handle, 9) | Out-Null
    [BgUi]::SetWindowPos($handle, [IntPtr](-2), 40, 40, 1120, 790, 0x0040) | Out-Null
    [BgUi]::SetForegroundWindow($handle) | Out-Null
    Start-Sleep -Milliseconds 800
    Save-Shot $handle 'verify-background.png'
    Click-Client $handle 600 20
    Click-Client $handle 100 421
    Click-Client $handle 1023 105
    Save-Shot $handle 'verify-background-appearance.png'
    Write-Output 'background probe finished'
}
finally {
    Get-Process NovaMemory* -ErrorAction SilentlyContinue | Stop-Process -Force
    Copy-Item $backup $settings -Force
    Remove-Item $backup -Force
}
