# Captures the startup-items page so the custom startup button can be reviewed.
Add-Type -AssemblyName System.Drawing
Add-Type -Namespace StartupUi -Name Native -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
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
$proc = Start-Process -FilePath $exe -ArgumentList '--no-elevate' -PassThru
for ($i = 0; $i -lt 60 -and $proc.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $proc.Refresh() }
$handle = $proc.MainWindowHandle

function Click-Client([int]$x, [int]$y) {
    $lp = [IntPtr](($y -shl 16) -bor ($x -band 0xFFFF))
    [StartupUi.Native]::PostMessageW($handle, 0x0201, [IntPtr]1, $lp) | Out-Null
    Start-Sleep -Milliseconds 40
    [StartupUi.Native]::PostMessageW($handle, 0x0202, [IntPtr]0, $lp) | Out-Null
    Start-Sleep -Milliseconds 300
}

function Save-Shot([string]$name) {
    [StartupUi.Native]::ShowWindow($handle, 9) | Out-Null
    [StartupUi.Native]::SetWindowPos($handle, [IntPtr](-2), 40, 40, 1120, 790, 0x0040) | Out-Null
    [StartupUi.Native]::SetForegroundWindow($handle) | Out-Null
    Start-Sleep -Milliseconds 400
    $rect = New-Object 'StartupUi.Native+RECT'
    [StartupUi.Native]::GetWindowRect($handle, [ref]$rect) | Out-Null
    $w = $rect.Right - $rect.Left; $h = $rect.Bottom - $rect.Top
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $graphics = [System.Drawing.Graphics]::FromImage($bmp)
    $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bmp.Size)
    $bmp.Save((Join-Path $assets $name), [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose(); $bmp.Dispose()
    Write-Output "captured $name"
}

try {
    Click-Client 600 20
    Click-Client 100 333
    Start-Sleep -Milliseconds 400
    Click-Client 742 183
    Start-Sleep -Milliseconds 900
    Save-Shot 'page-startup.png'
    Click-Client 814 239
    Start-Sleep -Milliseconds 1500
    Add-Type -Namespace StartupUi -Name Dialog -MemberDefinition @'
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowW(string cls, string title);
[DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
'@
    $dialog = [StartupUi.Dialog]::FindWindowW($null, '閫夋嫨瑕佸紑鏈哄惎鍔ㄧ殑绋嬪簭')
    Write-Output ("dialog handle: " + $dialog)
    Save-Shot 'page-startup-dialog.png'
    if ($dialog -ne [IntPtr]::Zero) { [StartupUi.Dialog]::PostMessageW($dialog, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null }
    Start-Sleep -Milliseconds 600
    Write-Output "startup dialog opened: $($dialog -ne [IntPtr]::Zero)"
} finally {
    Get-Process NovaMemory* -ErrorAction SilentlyContinue | Stop-Process -Force
}
