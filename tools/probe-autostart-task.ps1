$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -Namespace AutoUi -Name Native -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
[DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
[DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint m, IntPtr w, IntPtr l);
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
'@
[AutoUi.Native]::SetProcessDPIAware() | Out-Null

$exe = (Join-Path $PSScriptRoot '..\outputs\NovaMemory-final.exe')
$assets = (Join-Path $PSScriptRoot '..\assets')

function Click-Client([IntPtr]$handle, [int]$x, [int]$y) {
    $lparam = [IntPtr](($y -shl 16) -bor ($x -band 0xFFFF))
    [AutoUi.Native]::PostMessageW($handle, 0x0201, [IntPtr]1, $lparam) | Out-Null
    Start-Sleep -Milliseconds 80
    [AutoUi.Native]::PostMessageW($handle, 0x0202, [IntPtr]0, $lparam) | Out-Null
    Start-Sleep -Milliseconds 320
}

function RunValue() {
    (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name NovaMemory -ErrorAction SilentlyContinue).NovaMemory
}

function TaskState() {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $null = schtasks /query /tn NovaMemoryAutostart 2>&1
    $present = ($LASTEXITCODE -eq 0)
    $ErrorActionPreference = $previous
    if ($present) { 'present' } else { 'absent' }
}

Write-Output ('before: run=' + (RunValue) + ' task=' + (TaskState))

Get-Process NovaMemory* -ErrorAction SilentlyContinue | ForEach-Object { $_.Kill() }
Start-Sleep -Milliseconds 500
$process = Start-Process -FilePath $exe -ArgumentList '--no-elevate' -PassThru
Start-Sleep -Seconds 2
$handle = $process.MainWindowHandle
for ($i = 0; $i -lt 20 -and $handle -eq [IntPtr]::Zero; $i++) { Start-Sleep -Milliseconds 250; $process.Refresh(); $handle = $process.MainWindowHandle }
[AutoUi.Native]::ShowWindow($handle, 9) | Out-Null
[AutoUi.Native]::SetWindowPos($handle, [IntPtr](-2), 40, 40, 1120, 790, 0x0040) | Out-Null
[AutoUi.Native]::SetWindowPos($handle, [IntPtr]0, 40, 40, 1120, 790, 0x0040) | Out-Null
[AutoUi.Native]::SetWindowPos($handle, [IntPtr](-1), 0, 0, 0, 0, 0x0003) | Out-Null
[AutoUi.Native]::SetForegroundWindow($handle) | Out-Null
Start-Sleep -Milliseconds 400

Click-Client $handle 600 20
Click-Client $handle 100 421
Start-Sleep -Milliseconds 400

# toggle off, save
Click-Client $handle 603 392
Click-Client $handle 347 700
Start-Sleep -Milliseconds 900
Write-Output ('after disable: run=' + (RunValue) + ' task=' + (TaskState))

# toggle on, save
Click-Client $handle 603 392
Click-Client $handle 347 700
Start-Sleep -Milliseconds 1500
Write-Output ('after enable: run=' + (RunValue) + ' task=' + (TaskState))

$rect = New-Object AutoUi.Native+RECT
[AutoUi.Native]::GetWindowRect($handle, [ref]$rect) | Out-Null
$bitmap = New-Object System.Drawing.Bitmap ($rect.Right - $rect.Left), ($rect.Bottom - $rect.Top)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)
$bitmap.Save((Join-Path $assets 'probe-autostart-task.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose(); $bitmap.Dispose()
Write-Output 'captured probe-autostart-task.png'

Get-Process NovaMemory* -ErrorAction SilentlyContinue | ForEach-Object { $_.Kill() }
