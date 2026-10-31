$ErrorActionPreference = 'Stop'

$rc = Join-Path $PSScriptRoot '..\native\app.rc'
$outputs = (Join-Path $PSScriptRoot '..\outputs')
$text = [System.IO.File]::ReadAllText((Resolve-Path $rc), [System.Text.Encoding]::UTF8)
$match = [regex]::Match($text, 'FILEVERSION\s+(\d+),(\d+),(\d+),(\d+)')
if (-not $match.Success) { throw 'app.rc 缺少 FILEVERSION，无法确定当前版本' }
$version = '{0}.{1}.{2}' -f $match.Groups[1].Value, $match.Groups[2].Value, $match.Groups[3].Value

$keep = @('NovaMemory-final.exe', "NovaMemory-$version.exe")
$backup = Join-Path $outputs 'backup'
New-Item -ItemType Directory -Force -Path $backup | Out-Null

$moved = 0
Get-ChildItem -Path $outputs -Filter 'NovaMemory*.exe' -File | Where-Object { $keep -notcontains $_.Name } | ForEach-Object {
    Move-Item -LiteralPath $_.FullName -Destination (Join-Path $backup $_.Name) -Force
    Write-Output ("archived {0}" -f $_.Name)
    $moved++
}

if ($moved -eq 0) {
    Write-Output 'outputs 目录里没有需要归档的旧构建'
} else {
    Write-Output ("archived {0} stale build(s) into outputs\backup" -f $moved)
}
Write-Output ("keeping NovaMemory-final.exe and NovaMemory-{0}.exe" -f $version)
