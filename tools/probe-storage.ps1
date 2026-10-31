# Captures the storage and assistant pages after their background scans settle.
Add-Type -AssemblyName System.Drawing

Add-Type -Namespace PageUi -Name Native -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
[DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
[DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
public struct RECT { public int Left, Top, Right, Bottom; }
'@

$root = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $root 'outputs\NovaMemory-final.exe'
$assets = Join-Path $root 'assets'
Get-Process NovaMemory* -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500
[PageUi.Native]::SetProcessDPIAware() | Out-Null
$proc = Start-Process -FilePath $exe -ArgumentList '--no-elevate' -PassThru
for ($i = 0; $i -lt 60 -and $proc.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $proc.Refresh() }
$handle = $proc.MainWindowHandle
[PageUi.Native]::ShowWindow($handle, 9) | Out-Null
[PageUi.Native]::SetWindowPos($handle, [IntPtr](-2), 40, 40, 1120, 790, 0x0040) | Out-Null
Start-Sleep -Milliseconds 600

function Click-Client([int]$x, [int]$y) {
    $lp = [IntPtr](($y -shl 16) -bor ($x -band 0xFFFF))
    [PageUi.Native]::PostMessageW($handle, 0x0201, [IntPtr]1, $lp) | Out-Null
    Start-Sleep -Milliseconds 40
    [PageUi.Native]::PostMessageW($handle, 0x0202, [IntPtr]0, $lp) | Out-Null
    Start-Sleep -Milliseconds 260
}

function Save-Shot([string]$name) {
    [PageUi.Native]::ShowWindow($handle, 9) | Out-Null
    [PageUi.Native]::SetWindowPos($handle, [IntPtr](-2), 40, 40, 1120, 790, 0x0040) | Out-Null
    [PageUi.Native]::SetForegroundWindow($handle) | Out-Null
    Start-Sleep -Milliseconds 350
    $rect = New-Object 'PageUi.Native+RECT'
    [PageUi.Native]::GetWindowRect($handle, [ref]$rect) | Out-Null
    $w = $rect.Right - $rect.Left; $h = $rect.Bottom - $rect.Top
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $graphics = [System.Drawing.Graphics]::FromImage($bmp)
    $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bmp.Size)
    $path = Join-Path $assets $name
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose(); $bmp.Dispose()
    Write-Output "captured $name"
}

try {
    Click-Client 600 20
    Click-Client 100 245
    Start-Sleep -Seconds 6
    Save-Shot 'page-storage-early.png'
    Start-Sleep -Seconds 22
    Save-Shot 'page-storage.png'
    Click-Client 100 405
    Start-Sleep -Milliseconds 1200
    Save-Shot 'page-assistant.png'
} finally {
    Get-Process NovaMemory* -ErrorAction SilentlyContinue | Stop-Process -Force
}
