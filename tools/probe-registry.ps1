# End-to-end probe for the registry tab: seed two dead entries we own, run the
# health scan, clean them, then prove the .reg backup really exists (UTF-16 BOM +
# regedit header) and that the seeded dead entries are gone.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class RegUi {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    public struct RECT { public int Left, Top, Right, Bottom; }
}
'@
[RegUi]::SetProcessDPIAware() | Out-Null
$exe = (Resolve-Path (Join-Path $PSScriptRoot '..\outputs\NovaMemory-final.exe')).Path
$out = Join-Path $PSScriptRoot '..\assets'
$backupDir = Join-Path $env:APPDATA 'NovaMemory'
$runPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$appPathKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\NovaProbeGhost.exe'
$seededValue = 'C:\NovaProbe\missing.exe'

Get-Process NovaMemory* -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 300
Set-ItemProperty -Path $runPath -Name 'NovaProbeDead' -Value $seededValue
New-Item -Path $appPathKey -Force | Out-Null
Set-Item -Path $appPathKey -Value 'C:\NovaProbe\ghost.exe'
$before = @(Get-ChildItem $backupDir -Filter 'RegistryBackup-*.reg' -ErrorAction SilentlyContinue).Count

$process = Start-Process -FilePath $exe -ArgumentList '--no-elevate' -PassThru
try {
    for ($i = 0; $i -lt 40 -and $process.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $process.Refresh() }
    $handle = $process.MainWindowHandle
    if ($handle -eq 0) { throw 'window did not appear' }
    [RegUi]::SetWindowPos($handle, [IntPtr](-2), 40, 40, 1120, 790, 0x0040) | Out-Null
    [RegUi]::SetForegroundWindow($handle) | Out-Null
    Start-Sleep -Milliseconds 700
    function Save-Shot([string]$name) {
        $window = New-Object 'RegUi+RECT'
        [RegUi]::GetWindowRect($handle, [ref]$window) | Out-Null
        [RegUi]::SetForegroundWindow($handle) | Out-Null
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
        [RegUi]::PostMessageW($handle, 0x0201, [IntPtr]1, $lparam) | Out-Null
        Start-Sleep -Milliseconds 60
        [RegUi]::PostMessageW($handle, 0x0202, [IntPtr]0, $lparam) | Out-Null
        Start-Sleep -Milliseconds 260
    }

    Click-Client 600 20
    Click-Client 100 333
    Start-Sleep -Milliseconds 500
    Click-Client 346 183
    Start-Sleep -Milliseconds 600
    Click-Client 337 410
    Start-Sleep -Milliseconds 2500
    Save-Shot 'probe-registry-scan.png'

    Click-Client 529 410
    Start-Sleep -Milliseconds 600
    Save-Shot 'probe-registry-confirm.png'
    Click-Client 638 475
    Start-Sleep -Milliseconds 3000
    Save-Shot 'probe-registry-cleaned.png'

    $backups = @(Get-ChildItem $backupDir -Filter 'RegistryBackup-*.reg' -ErrorAction SilentlyContinue)
    Write-Output ("backup files: {0} (before {1})" -f $backups.Count, $before)
    if ($backups.Count -le $before) { throw 'no new .reg backup was written' }
    $newest = $backups | Sort-Object LastWriteTime | Select-Object -Last 1
    $bytes = [System.IO.File]::ReadAllBytes($newest.FullName)
    Write-Output ("backup: {0} ({1} bytes)" -f $newest.Name, $bytes.Length)
    if ($bytes.Length -lt 4 -or $bytes[0] -ne 0xFF -or $bytes[1] -ne 0xFE) { throw 'backup is not UTF-16LE with a BOM' }
    $text = [System.Text.Encoding]::Unicode.GetString($bytes)
    if ($text -notmatch 'Windows Registry Editor Version 5\.00') { throw 'backup is missing the regedit header' }
    if ($text -notmatch 'NovaProbeDead') { throw 'backup does not contain the seeded startup value' }

    $stillThere = $null -ne (Get-ItemProperty -Path $runPath -Name 'NovaProbeDead' -ErrorAction SilentlyContinue)
    if ($stillThere) { throw 'the seeded dead startup value was not removed' }
    $keyLeft = Test-Path $appPathKey
    if ($keyLeft) { throw 'the seeded dead App Paths key was not removed' }
    Write-Output 'registry backup + cleanup verified'
}
finally {
    if (-not $process.HasExited) { $process.Kill() }
    $process.Dispose()
    Remove-ItemProperty -Path $runPath -Name 'NovaProbeDead' -ErrorAction SilentlyContinue
    if (Test-Path $appPathKey) { Remove-Item -Path $appPathKey -Recurse -Force -ErrorAction SilentlyContinue }
}
