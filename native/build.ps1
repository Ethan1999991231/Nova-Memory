$ErrorActionPreference = "Stop"

# Stop any running copy first: a live instance keeps a write lock on the exe and
# the linker then fails with LNK1104.
$binary = Join-Path $PSScriptRoot "..\outputs\NovaMemory-final.exe"
Get-Process NovaMemory* -ErrorAction SilentlyContinue | ForEach-Object { $_.Kill(); $_.WaitForExit(3000) }
for ($i = 0; $i -lt 20 -and (Get-Process NovaMemory* -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Milliseconds 200 }
Start-Sleep -Milliseconds 300

# A scanner or a lingering handle can still hold the exe for a moment, so retry
# the link instead of failing the whole build on one transient LNK1104.
$cmd = "`"$PSScriptRoot\build-native.cmd`""
$exit = 0
for ($attempt = 1; $attempt -le 3; $attempt++) {
    cmd /c $cmd 2>&1 | ForEach-Object { Write-Host $_ }
    $exit = $LASTEXITCODE
    if ($exit -eq 0) { break }
    Start-Sleep -Milliseconds 1200
    Get-Process NovaMemory* -ErrorAction SilentlyContinue | ForEach-Object { $_.Kill() }
}
if ($exit -ne 0) { throw "native build failed" }

# Park a version-stamped copy next to the rolling build so past releases stay
# reproducible; the version comes straight out of app.rc, never from a guess.
$outputs = Join-Path $PSScriptRoot "..\outputs"
if (-not (Test-Path $binary)) { throw "missing $binary" }
$rc = Get-Content (Join-Path $PSScriptRoot "app.rc") -Raw
if ($rc -notmatch 'FILEVERSION\s+(\d+),(\d+),(\d+),(\d+)') { throw "app.rc has no FILEVERSION" }
$version = "$($Matches[1]).$($Matches[2]).$($Matches[3])"
$stamped = Join-Path $outputs "NovaMemory-$version.exe"
Copy-Item $binary $stamped -Force
Write-Host "Built outputs\NovaMemory-final.exe"
Write-Host "Archived outputs\NovaMemory-$version.exe"
