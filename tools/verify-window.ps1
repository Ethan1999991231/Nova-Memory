# Visual smoke check for the NovaMemory window.
# Launches the built EXE, captures the window as-is, clicks the bottom-left status
# card, captures the computer-configuration popover, and extracts the embedded EXE
# icon so the taskbar/explorer icon can be eyeballed too.
param(
    [string]$Exe = (Join-Path $PSScriptRoot '..\outputs\NovaMemory-final.exe'),
    [string]$OutDir = (Join-Path $PSScriptRoot '..\assets')
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class NativeUi {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, IntPtr extra);
    public struct RECT { public int Left, Top, Right, Bottom; }
    public struct POINT { public int X, Y; }
}
'@
[NativeUi]::SetProcessDPIAware() | Out-Null
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$exePath = if (Test-Path $Exe) { (Resolve-Path $Exe).Path } else {
    $newest = Get-ChildItem (Join-Path $PSScriptRoot '..\outputs') -Filter '*.exe' |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($null -eq $newest) { throw "no NovaMemory executable found in outputs" }
    Write-Output ("falling back to newest build: {0}" -f $newest.Name)
    $newest.FullName
}
# A leftover instance would render at the same screen position and pollute the
# captures, so verification always starts from a clean slate.
Get-Process NovaMemory* -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 300

$process = Start-Process -FilePath $exePath -PassThru

try {
    for ($i = 0; $i -lt 40 -and $process.MainWindowHandle -eq 0; $i++) {
        Start-Sleep -Milliseconds 100
        $process.Refresh()
    }
    $handle = $process.MainWindowHandle
    if ($handle -eq 0) { throw 'NovaMemory window did not appear' }
    # Force the window to a known on-screen position and above other windows so the
    # screen capture and the synthetic click both land on NovaMemory itself.
    # Restore first: a maximized window would silently break the fixed-size contract.
    [NativeUi]::ShowWindow($handle, 9) | Out-Null
    [NativeUi]::SetWindowPos($handle, [IntPtr](-1), 40, 40, 1120, 790, 0x0040) | Out-Null
    [NativeUi]::SetForegroundWindow($handle) | Out-Null
    Start-Sleep -Milliseconds 700

    $window = New-Object 'NativeUi+RECT'
    [NativeUi]::GetWindowRect($handle, [ref]$window) | Out-Null
    $client = New-Object 'NativeUi+RECT'
    [NativeUi]::GetClientRect($handle, [ref]$client) | Out-Null

    function Save-Shot([string]$path) {
        [NativeUi]::GetWindowRect($handle, [ref]$window) | Out-Null
        [NativeUi]::SetForegroundWindow($handle) | Out-Null
        Start-Sleep -Milliseconds 120
        $width = $window.Right - $window.Left
        $height = $window.Bottom - $window.Top
        $bitmap = New-Object System.Drawing.Bitmap $width, $height
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($window.Left, $window.Top, 0, 0, $bitmap.Size)
        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        $graphics.Dispose()
        $bitmap.Dispose()
        Write-Output ("captured {0} ({1}x{2})" -f $path, $width, $height)
    }

    Save-Shot (Join-Path $OutDir 'verify-idle.png')

    # Client-relative clicks posted straight to the window: independent of DPI,
    # focus and z-order, so the probe drives the app deterministically.
    function Click-Client([int]$x, [int]$y) {
        $lparam = [IntPtr](($y -shl 16) -bor ($x -band 0xFFFF))
        [NativeUi]::PostMessageW($handle, 0x0201, [IntPtr]1, $lparam) | Out-Null
        Start-Sleep -Milliseconds 60
        [NativeUi]::PostMessageW($handle, 0x0202, [IntPtr]0, $lparam) | Out-Null
        Start-Sleep -Milliseconds 220
    }

    # The first synthetic click can be consumed as the window-activation click, so a
    # harmless header click warms the window up before the card click that matters.
    Click-Client 600 20
    # Centre of the bottom-left status card: 192x78 at (14, clientHeight-106).
    Click-Client 110 ($client.Bottom - 106 + 39)
    Start-Sleep -Milliseconds 500
    Save-Shot (Join-Path $OutDir 'verify-popover.png')

    # Panel geometry mirrors ComputerPanelRect(): 420x432 at (14, clientHeight-118), clamped to y>=74.
    $panelHeight = 432
    $panelTop = $client.Bottom - 118 - $panelHeight
    if ($panelTop -lt 74) { $panelTop = 74 }
    # 复制配置 button: 150x36 at (panel.X+22, panel.bottom-46).
    Click-Client (14 + 22 + 75) ($panelTop + $panelHeight - 46 + 18)
    Start-Sleep -Milliseconds 250
    Save-Shot (Join-Path $OutDir 'verify-copy.png')
    Add-Type -AssemblyName System.Windows.Forms
    $clipboard = [System.Windows.Forms.Clipboard]::GetText()
    if ([string]::IsNullOrWhiteSpace($clipboard)) { $clipboard = Get-Clipboard -Raw }
    if ([string]::IsNullOrWhiteSpace($clipboard) -or $clipboard -notmatch 'NovaMemory' -or $clipboard -notmatch 'ETHAN-COMPUTER') {
        throw "copy button did not reach the clipboard: '$clipboard'"
    }
    Write-Output ("clipboard {0} chars, first line: {1}" -f $clipboard.Length, ($clipboard -split "`r?`n")[0])

    # WM_CLOSE must hide to the tray instead of quitting while the tray icon exists.
    [NativeUi]::PostMessageW($handle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
    Start-Sleep -Milliseconds 600
    $process.Refresh()
    if ($process.HasExited) { throw 'WM_CLOSE quit the app instead of hiding it to the tray' }
    if ([NativeUi]::IsWindowVisible($handle)) { throw 'WM_CLOSE left the window visible' }
    Write-Output 'tray: WM_CLOSE hid the window and the process is still alive'

    # TRAY_SHOW / TRAY_EXIT prove the tray menu commands are wired to the same window.
    [NativeUi]::PostMessageW($handle, 0x0111, [IntPtr]40001, [IntPtr]::Zero) | Out-Null
    Start-Sleep -Milliseconds 500
    if (-not [NativeUi]::IsWindowVisible($handle)) { throw 'TRAY_SHOW did not restore the window' }
    Write-Output 'tray: TRAY_SHOW restored the window'

    $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($exePath)
    if ($null -eq $icon) { throw 'embedded EXE icon is missing' }
    $iconBitmap = $icon.ToBitmap()
    $iconBitmap.Save((Join-Path $OutDir 'verify-exe-icon.png'), [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output ("icon {0}x{1}" -f $iconBitmap.Width, $iconBitmap.Height)
    $iconBitmap.Dispose()
    $icon.Dispose()

    [NativeUi]::PostMessageW($handle, 0x0111, [IntPtr]40003, [IntPtr]::Zero) | Out-Null
    if (-not $process.WaitForExit(4000)) { throw 'TRAY_EXIT did not end the process' }
    Write-Output 'tray: TRAY_EXIT ended the process'
}
finally {
    if (-not $process.HasExited) { $process.Kill() }
    $process.Dispose()
}
