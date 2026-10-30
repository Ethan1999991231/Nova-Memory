# Ad-hoc screenshot probe for the settings pages (regular tab, appearance tab).
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class ProbeUi {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, IntPtr extra);
    public struct RECT { public int Left, Top, Right, Bottom; }
    public struct POINT { public int X, Y; }
}
'@
[ProbeUi]::SetProcessDPIAware() | Out-Null
$exe = (Resolve-Path (Join-Path $PSScriptRoot '..\outputs\NovaMemory-final.exe')).Path
$out = Join-Path $PSScriptRoot '..\assets'
Get-Process NovaMemory* -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 300
$process = Start-Process -FilePath $exe -PassThru
try {
    for ($i = 0; $i -lt 40 -and $process.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $process.Refresh() }
    $handle = $process.MainWindowHandle
    if ($handle -eq 0) { throw 'window did not appear' }
    [ProbeUi]::SetWindowPos($handle, [IntPtr](-1), 40, 40, 1120, 790, 0x0040) | Out-Null
    [ProbeUi]::SetForegroundWindow($handle) | Out-Null
    Start-Sleep -Milliseconds 700
    function Save-Shot([string]$name) {
        $window = New-Object 'ProbeUi+RECT'
        [ProbeUi]::GetWindowRect($handle, [ref]$window) | Out-Null
        [ProbeUi]::SetForegroundWindow($handle) | Out-Null
        Start-Sleep -Milliseconds 150
        $bitmap = New-Object System.Drawing.Bitmap ($window.Right - $window.Left), ($window.Bottom - $window.Top)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($window.Left, $window.Top, 0, 0, $bitmap.Size)
        $bitmap.Save((Join-Path $out $name), [System.Drawing.Imaging.ImageFormat]::Png)
        $graphics.Dispose(); $bitmap.Dispose()
        Write-Output "captured $name"
    }
    function Click-Client([int]$x, [int]$y) {
        $point = New-Object 'ProbeUi+POINT'
        $point.X = $x; $point.Y = $y
        [ProbeUi]::ClientToScreen($handle, [ref]$point) | Out-Null
        [ProbeUi]::SetCursorPos($point.X, $point.Y) | Out-Null
        Start-Sleep -Milliseconds 120
        [ProbeUi]::mouse_event(0x0002, 0, 0, 0, [IntPtr]::Zero)
        Start-Sleep -Milliseconds 60
        [ProbeUi]::mouse_event(0x0004, 0, 0, 0, [IntPtr]::Zero)
        Start-Sleep -Milliseconds 260
    }
    Click-Client 600 20
    Click-Client 100 179
    Save-Shot 'probe-settings-general.png'
    Click-Client 1032 110
    Save-Shot 'probe-settings-appearance.png'
}
finally {
    if (-not $process.HasExited) { $process.Kill() }
    $process.Dispose()
}
