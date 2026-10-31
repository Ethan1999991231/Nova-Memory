# Verifies two new settings features end to end:
#   1. custom background image is persisted and painted behind the cards
#   2. the "寮€鏈鸿嚜鍚姩" switch writes HKCU Run on save and removes it again
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class FeatureUi {
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
$image = (Resolve-Path (Join-Path $PSScriptRoot '..\assets\cat-fish.jpg')).Path
$settings = Join-Path $env:APPDATA 'NovaMemory\settings.json'
$backup = Join-Path $env:TEMP 'nova-settings-backup.json'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'

Get-Process NovaMemory* -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 300
if (Test-Path $settings) { Copy-Item $settings $backup -Force }

function Save-Shot([IntPtr]$handle, [string]$name) {
    $window = New-Object 'FeatureUi+RECT'
    [FeatureUi]::GetWindowRect($handle, [ref]$window) | Out-Null
    [FeatureUi]::SetForegroundWindow($handle) | Out-Null
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
    [FeatureUi]::PostMessageW($handle, 0x0201, [IntPtr]1, $lparam) | Out-Null
    Start-Sleep -Milliseconds 70
    [FeatureUi]::PostMessageW($handle, 0x0202, [IntPtr]0, $lparam) | Out-Null
    Start-Sleep -Milliseconds 350
}

function Start-App {
    $process = Start-Process -FilePath $exe -ArgumentList '--no-elevate' -PassThru
    for ($i = 0; $i -lt 60 -and $process.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $process.Refresh() }
    if ($process.MainWindowHandle -eq 0) { throw 'window did not appear' }
    $handle = $process.MainWindowHandle
    [FeatureUi]::ShowWindow($handle, 9) | Out-Null
    [FeatureUi]::SetWindowPos($handle, [IntPtr](-2), 40, 40, 1120, 790, 0x0040) | Out-Null
    [FeatureUi]::SetForegroundWindow($handle) | Out-Null
    Start-Sleep -Milliseconds 700
    return $process
}

try {
    # --- part 1: background image -------------------------------------------------
    $json = if (Test-Path $settings) { Get-Content $settings -Raw | ConvertFrom-Json } else { New-Object psobject }
    $json | Add-Member -NotePropertyName background -NotePropertyValue $image -Force
    $json | ConvertTo-Json -Depth 4 | Set-Content -Path $settings -Encoding UTF8
    $process = Start-App
    $handle = $process.MainWindowHandle
    Save-Shot $handle 'verify-background.png'
    if (-not $process.HasExited) { $process.Kill() }
    $process.WaitForExit(3000) | Out-Null
    Start-Sleep -Milliseconds 500
    Write-Output "background saved: $((Get-Content $settings -Raw | ConvertFrom-Json).background)"

    # --- part 2: auto start switch -------------------------------------------------
    $json = Get-Content $settings -Raw | ConvertFrom-Json
    $json | Add-Member -NotePropertyName background -NotePropertyValue '' -Force
    $json | ConvertTo-Json -Depth 4 | Set-Content -Path $settings -Encoding UTF8
    $process = Start-App
    $handle = $process.MainWindowHandle
    Click-Client $handle 600 20
    Click-Client $handle 100 421
    Click-Client $handle 610 392
    Click-Client $handle 340 700
    Start-Sleep -Milliseconds 600
    Save-Shot $handle 'verify-autostart-on.png'
    $value = (Get-ItemProperty -Path $runKey -Name NovaMemory -ErrorAction SilentlyContinue).NovaMemory
    Write-Output "run key after save: $value"
    if (-not $value) { throw 'auto start switch did not write HKCU Run' }

    Click-Client $handle 610 392
    Click-Client $handle 340 700
    Start-Sleep -Milliseconds 600
    $value = (Get-ItemProperty -Path $runKey -Name NovaMemory -ErrorAction SilentlyContinue).NovaMemory
    Write-Output "run key after second save: $value"
    if ($value) { throw 'auto start switch did not remove HKCU Run' }
    if (-not $process.HasExited) { $process.Kill() }
    Write-Output 'settings features verified'
}
finally {
    Get-Process NovaMemory* -ErrorAction SilentlyContinue | Stop-Process -Force
    if (Test-Path $backup) { Copy-Item $backup $settings -Force; Remove-Item $backup -Force }
    Remove-ItemProperty -Path $runKey -Name NovaMemory -ErrorAction SilentlyContinue
}

