$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot '..'
$exe = Join-Path $root 'outputs\NovaMemory-final.exe'
$out = Join-Path $root 'assets'
$settings = Join-Path $env:APPDATA 'NovaMemory\settings.json'
$backup = Join-Path $env:TEMP 'novamemory-settings-backup.json'
if (Test-Path $settings) { Copy-Item $settings $backup -Force }

Add-Type -Namespace FeatUi -Name Win -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
[DllImport("user32.dll")] public static extern IntPtr SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
[DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
[DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
[StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
'@
Add-Type -AssemblyName System.Drawing

function Save-Shot([IntPtr]$handle, [string]$name) {
    [FeatUi.Win]::ShowWindow($handle, 9) | Out-Null
    [FeatUi.Win]::SetWindowPos($handle, [IntPtr](-2), 40, 40, 1120, 790, 0x0040) | Out-Null
    [FeatUi.Win]::SetForegroundWindow($handle) | Out-Null
    Start-Sleep -Milliseconds 350
    $rect = New-Object FeatUi.Win+RECT
    [FeatUi.Win]::GetWindowRect($handle, [ref]$rect) | Out-Null
    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top
    $bitmap = New-Object System.Drawing.Bitmap $width, $height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)
    $path = Join-Path $out $name
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose(); $bitmap.Dispose()
    Write-Output ("captured " + $name)
}

function Click-Client([IntPtr]$handle, [int]$x, [int]$y) {
    $lparam = [IntPtr](($y -shl 16) -bor ($x -band 0xFFFF))
    [FeatUi.Win]::PostMessageW($handle, 0x0201, [IntPtr]1, $lparam) | Out-Null
    Start-Sleep -Milliseconds 60
    [FeatUi.Win]::PostMessageW($handle, 0x0202, [IntPtr]0, $lparam) | Out-Null
    Start-Sleep -Milliseconds 220
}

[FeatUi.Win]::SetProcessDPIAware() | Out-Null
Get-Process NovaMemory* -ErrorAction SilentlyContinue | ForEach-Object { $_.Kill() }
Start-Sleep -Milliseconds 300
$process = Start-Process -FilePath $exe -ArgumentList '--no-elevate' -PassThru
try {
    for ($i = 0; $i -lt 40; $i++) {
        Start-Sleep -Milliseconds 250
        $process.Refresh()
        if ($process.MainWindowHandle -ne [IntPtr]::Zero) { break }
    }
    $handle = $process.MainWindowHandle
    if ($handle -eq [IntPtr]::Zero) { throw 'window did not appear' }
    [FeatUi.Win]::ShowWindow($handle, 9) | Out-Null
    [FeatUi.Win]::SetWindowPos($handle, [IntPtr](-2), 40, 40, 1120, 790, 0x0040) | Out-Null
    Start-Sleep -Milliseconds 500

    # Home page: run one optimisation so the history report has a record to show.
    Click-Client $handle 600 20
    Click-Client $handle 506 679
    Start-Sleep -Milliseconds 4000
    Save-Shot $handle 'feature-home-report.png'

    # Storage page: big-file finder.
    Click-Client $handle 100 245
    Start-Sleep -Milliseconds 1200
    Click-Client $handle 496 209
    for ($i = 0; $i -lt 9; $i++) {
        Start-Sleep -Seconds 10
        Save-Shot $handle 'feature-bigfiles.png'
    }

    # Appearance page: global tint swatch (second one, 冷蓝).
    Click-Client $handle 100 421
    Start-Sleep -Milliseconds 800
    Click-Client $handle 1023 105
    Start-Sleep -Milliseconds 800
    Save-Shot $handle 'feature-appearance-tint.png'

    # Single instance: a second launch must exit immediately and reuse the window.
    $second = Start-Process -FilePath $exe -ArgumentList '--no-elevate' -PassThru
    $exited = $second.WaitForExit(4000)
    $process.Refresh()
    Write-Output ("second instance exited: $exited, first alive: $(-not $process.HasExited)")
    if (-not $exited) { $second.Kill() }
}
finally {
    Get-Process NovaMemory* -ErrorAction SilentlyContinue | ForEach-Object { $_.Kill() }
    if (Test-Path $backup) { Copy-Item $backup $settings -Force; Remove-Item $backup -Force }
}
Write-Output 'new feature probe finished'
