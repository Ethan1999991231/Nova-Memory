# Walks every left-nav page, the maintenance tabs, and the settings tabs, and
# captures a screenshot of each so the new surfaces can be eyeballed in one pass.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class PageUi {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    public struct RECT { public int Left, Top, Right, Bottom; }
}
'@
[PageUi]::SetProcessDPIAware() | Out-Null
$exe = (Resolve-Path (Join-Path $PSScriptRoot '..\outputs\NovaMemory-final.exe')).Path
$out = Join-Path $PSScriptRoot '..\assets'
Get-Process NovaMemory* -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 300
$process = Start-Process -FilePath $exe -PassThru
try {
    for ($i = 0; $i -lt 40 -and $process.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $process.Refresh() }
    $handle = $process.MainWindowHandle
    if ($handle -eq 0) { throw 'window did not appear' }
    [PageUi]::ShowWindow($handle, 9) | Out-Null
    [PageUi]::SetWindowPos($handle, [IntPtr](-1), 40, 40, 1120, 790, 0x0040) | Out-Null
    [PageUi]::SetForegroundWindow($handle) | Out-Null
    Start-Sleep -Milliseconds 700
    function Save-Shot([string]$name) {
        $window = New-Object 'PageUi+RECT'
        [PageUi]::GetWindowRect($handle, [ref]$window) | Out-Null
        [PageUi]::SetForegroundWindow($handle) | Out-Null
        Start-Sleep -Milliseconds 150
        $bitmap = New-Object System.Drawing.Bitmap ($window.Right - $window.Left), ($window.Bottom - $window.Top)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($window.Left, $window.Top, 0, 0, $bitmap.Size)
        $bitmap.Save((Join-Path $out $name), [System.Drawing.Imaging.ImageFormat]::Png)
        $graphics.Dispose(); $bitmap.Dispose()
        Write-Output "captured $name"
    }
    function Click-Client([int]$x, [int]$y) {
        $lparam = [IntPtr](($y -shl 16) -bor ($x -band 0xFFFF))
        [PageUi]::PostMessageW($handle, 0x0201, [IntPtr]1, $lparam) | Out-Null
        Start-Sleep -Milliseconds 60
        [PageUi]::PostMessageW($handle, 0x0202, [IntPtr]0, $lparam) | Out-Null
        Start-Sleep -Milliseconds 260
    }

    $client = New-Object 'PageUi+RECT'
    [PageUi]::GetClientRect($handle, [ref]$client) | Out-Null
    Write-Output ("client {0}x{1}" -f $client.Right, $client.Bottom)

    Click-Client 600 20
    Click-Client 100 157
    Start-Sleep -Milliseconds 1500
    Save-Shot 'page-monitor.png'

    Click-Client 100 201
    Start-Sleep -Milliseconds 3500
    Save-Shot 'page-app-cleanup.png'

    Click-Client 100 245
    Start-Sleep -Milliseconds 4500
    Save-Shot 'page-storage.png'

    Click-Client 100 289
    Start-Sleep -Milliseconds 1200
    Save-Shot 'page-risk.png'

    Click-Client 100 377
    Start-Sleep -Milliseconds 1200
    Save-Shot 'page-assistant.png'

    Click-Client 100 333
    Start-Sleep -Milliseconds 2600
    Save-Shot 'page-registry.png'

    Click-Client 100 421
    Start-Sleep -Milliseconds 600
    Save-Shot 'page-settings-general.png'

    Click-Client 516 664
    Start-Sleep -Milliseconds 900
    Save-Shot 'page-settings-registered.png'

    Click-Client 847 664
    Start-Sleep -Milliseconds 6000
    Save-Shot 'page-settings-update.png'

    Click-Client 1032 110
    Start-Sleep -Milliseconds 600
    Save-Shot 'page-settings-appearance.png'

    # The register button writes a real Start Menu shortcut; prove it exists and
    # then remove it so the probe leaves the machine the way it found it.
    $link = Join-Path ([Environment]::GetFolderPath('Programs')) 'NovaMemory\NovaMemory.lnk'
    if (Test-Path $link) {
        Write-Output "shortcut registered: $link -> $((New-Object -ComObject WScript.Shell).CreateShortcut($link).TargetPath)"
        Remove-Item $link -Force
        Write-Output 'shortcut removed again'
    } else {
        throw "register button did not create $link"
    }
}
finally {
    if (-not $process.HasExited) { $process.Kill() }
    $process.Dispose()
}
