# Verifies the "寮€鏈鸿嚜鍚姩" switch writes HKCU Run on save and removes it again.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class StartUi {
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
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'

Get-Process NovaMemory* -ErrorAction SilentlyContinue | Stop-Process -Force
Remove-ItemProperty -Path $runKey -Name NovaMemory -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 300

function Save-Shot([IntPtr]$handle, [string]$name) {
    $window = New-Object 'StartUi+RECT'
    [StartUi]::GetWindowRect($handle, [ref]$window) | Out-Null
    [StartUi]::SetForegroundWindow($handle) | Out-Null
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
    [StartUi]::PostMessageW($handle, 0x0201, [IntPtr]1, $lparam) | Out-Null
    Start-Sleep -Milliseconds 70
    [StartUi]::PostMessageW($handle, 0x0202, [IntPtr]0, $lparam) | Out-Null
    Start-Sleep -Milliseconds 350
}

function Get-RunValue { (Get-ItemProperty -Path $runKey -Name NovaMemory -ErrorAction SilentlyContinue).NovaMemory }

$process = Start-Process -FilePath $exe -ArgumentList '--no-elevate' -PassThru
try {
    for ($i = 0; $i -lt 60 -and $process.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $process.Refresh() }
    $handle = $process.MainWindowHandle
    if ($handle -eq 0) { throw 'window did not appear' }
    [StartUi]::ShowWindow($handle, 9) | Out-Null
    [StartUi]::SetWindowPos($handle, [IntPtr](-2), 40, 40, 1120, 790, 0x0040) | Out-Null
    [StartUi]::SetForegroundWindow($handle) | Out-Null
    Start-Sleep -Milliseconds 700

    Click-Client $handle 600 20
    Click-Client $handle 100 421
    Save-Shot $handle 'verify-autostart-before.png'
    Write-Output "run key before toggle: '$(Get-RunValue)'"

    Click-Client $handle 610 392
    Save-Shot $handle 'verify-autostart-toggled.png'
    $afterToggle = Get-RunValue
    Write-Output "run key after toggle only: '$afterToggle'"
    if ($afterToggle) { throw 'toggle should not touch the registry before saving' }

    Click-Client $handle 340 700
    Start-Sleep -Milliseconds 1200
    Save-Shot $handle 'verify-autostart-enabled.png'
    $enabled = Get-RunValue
    Write-Output "run key after first save: '$enabled'"
    if (-not $enabled) { throw 'saving with the switch on did not write HKCU Run' }

    Click-Client $handle 610 392
    Click-Client $handle 340 700
    Start-Sleep -Milliseconds 1200
    Save-Shot $handle 'verify-autostart-disabled.png'
    $disabled = Get-RunValue
    Write-Output "run key after second save: '$disabled'"
    if ($disabled) { throw 'saving with the switch off did not remove HKCU Run' }
    Write-Output 'auto start switch verified'
}
finally {
    Get-Process NovaMemory* -ErrorAction SilentlyContinue | Stop-Process -Force
    Remove-ItemProperty -Path $runKey -Name NovaMemory -ErrorAction SilentlyContinue
}
