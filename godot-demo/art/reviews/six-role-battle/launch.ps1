$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$enginePath = $env:GODOT_BIN
if (-not $enginePath -or -not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    $engineCommand = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($engineCommand) { $enginePath = $engineCommand.Source }
}
if (-not $enginePath -or -not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    $engineFile = Get-ChildItem -LiteralPath 'C:/software' -Directory -Filter 'Godot*' -ErrorAction SilentlyContinue |
        ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -File -Filter '*win64.exe' } |
        Select-Object -First 1
    if ($engineFile) { $enginePath = $engineFile.FullName }
}
if (-not $enginePath -or -not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    throw 'Godot 4.7 was not found. Set GODOT_BIN to the Godot executable path, then try again.'
}
# This is the interactive game window, not a background helper.
Start-Process -FilePath $enginePath -ArgumentList @('--path', ('"' + $projectRoot + '"'), 'res://art/reviews/six-role-battle/battle.tscn') -WindowStyle Normal
