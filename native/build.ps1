$ErrorActionPreference = "Stop"
cmd /c "`"$PSScriptRoot\build-native.cmd`""
if ($LASTEXITCODE -ne 0) { throw "native build failed" }
Write-Host "Built outputs\NovaMemory.exe"
