# End-to-end probe for the cache tab: open it, let the scan finish, then clean and
# prove files really disappeared by counting %TEMP% both before and after.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class CacheUi {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, IntPtr extra);
    public struct RECT { public int Left, Top, Right, Bottom; }
    public struct POINT { public int X, Y; }
}
'@
[CacheUi]::SetProcessDPIAware() | Out-Null
$exe = (Resolve-Path (Join-Path $PSScriptRoot '..\outputs\NovaMemory-final.exe')).Path
$out = Join-Path $PSScriptRoot '..\assets'
Get-Process NovaMemory* -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 300
$process = Start-Process -FilePath $exe -PassThru
try {
    for ($i = 0; $i -lt 40 -and $process.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $process.Refresh() }
    $handle = $process.MainWindowHandle
    if ($handle -eq 0) { throw 'window did not appear' }
    [CacheUi]::SetWindowPos($handle, [IntPtr](-1), 40, 40, 1120, 790, 0x0040) | Out-Null
    [CacheUi]::SetForegroundWindow($handle) | Out-Null
    Start-Sleep -Milliseconds 700
    function Save-Shot([string]$name) {
        $window = New-Object 'CacheUi+RECT'
        [CacheUi]::GetWindowRect($handle, [ref]$window) | Out-Null
        [CacheUi]::SetForegroundWindow($handle) | Out-Null
        Start-Sleep -Milliseconds 150
        $bitmap = New-Object System.Drawing.Bitmap ($window.Right - $window.Left), ($window.Bottom - $window.Top)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($window.Left, $window.Top, 0, 0, $bitmap.Size)
        $bitmap.Save((Join-Path $out $name), [System.Drawing.Imaging.ImageFormat]::Png)
        $graphics.Dispose(); $bitmap.Dispose()
        Write-Output "captured $name"
    }
    # Post client-relative clicks straight to the window: no focus, DPI or z-order
    # dependency, so the probe drives the app deterministically.
    function Click-Client([int]$x, [int]$y) {
        $lparam = [IntPtr](($y -shl 16) -bor ($x -band 0xFFFF))
        [CacheUi]::PostMessageW($handle, 0x0201, [IntPtr]1, $lparam) | Out-Null
        Start-Sleep -Milliseconds 60
        [CacheUi]::PostMessageW($handle, 0x0202, [IntPtr]0, $lparam) | Out-Null
        Start-Sleep -Milliseconds 260
    }
    function Count-TempFiles { (Get-ChildItem $env:TEMP -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count }

    # Seed files we own so the clean assertion does not depend on system temp state.
    $seed = Join-Path $env:TEMP ('nova-probe-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $seed -Force | Out-Null
    1..3 | ForEach-Object { Set-Content -Path (Join-Path $seed "seed$_.tmp") -Value ('x' * 4096) }
    Write-Output ("seeded {0} files in {1}" -f (Get-ChildItem $seed -File).Count, $seed)

    Click-Client 600 20
    Click-Client 100 233
    Start-Sleep -Milliseconds 400
    $clientSize = New-Object 'CacheUi+RECT'
    [CacheUi]::GetClientRect($handle, [ref]$clientSize) | Out-Null
    Write-Output ("client {0}x{1}" -f $clientSize.Right, $clientSize.Bottom)
    Click-Client 742 183
    Start-Sleep -Milliseconds 1800
    Save-Shot 'probe-cache-scan.png'

    Click-Client 521 346
    Start-Sleep -Milliseconds 400
    Save-Shot 'probe-cache-confirm.png'
    Click-Client 638 487
    Start-Sleep -Milliseconds 2500
    Save-Shot 'probe-cache-cleaned.png'
    $remaining = (Get-ChildItem $seed -File -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Output "seed files remaining after clean: $remaining"
    if ($remaining -ne 0) { throw "cleaning left $remaining seeded files behind" }
}
finally {
    if (-not $process.HasExited) { $process.Kill() }
    $process.Dispose()
}
