param(
    [string]$Godot = '',
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path

if (-not $Godot) {
    $candidates = @(
        'E:\Godot\Godot_v4.7.1-stable_win64_console.exe',
        'E:\Godot\Godot_v4.7.1-stable_win64.exe'
    )
    $Godot = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}
if (-not $Godot -or -not (Test-Path -LiteralPath $Godot -PathType Leaf)) {
    throw "Godot 4.7.1 executable not found. Pass -Godot with full path."
}

$labData = Join-Path $projectPath '.runtime\megastructure_whitebox\user_data'
New-Item -ItemType Directory -Force -Path (Join-Path $labData 'appdata'), (Join-Path $labData 'localappdata') | Out-Null

if ($CheckOnly) {
    Write-Output "Project: $projectPath"
    Write-Output "Renderer: forward_plus"
    Write-Output "Scene: res://scenes/testing/MegastructureWhitebox.tscn"
    exit 0
}

$oldApp = $env:APPDATA
$oldLocal = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $labData 'appdata'
    $env:LOCALAPPDATA = Join-Path $labData 'localappdata'
    $argsList = @(
        '--path', ('"' + $projectPath + '"'),
        '--rendering-method', 'forward_plus',
        '--resolution', '1280x720',
        'res://scenes/testing/MegastructureWhitebox.tscn'
    )
    Write-Host "[LAUNCH] Starting Megastructure Whitebox with Forward+ Rendering..." -ForegroundColor Cyan
    Start-Process -FilePath $Godot -WorkingDirectory $projectPath -ArgumentList $argsList
} finally {
    $env:APPDATA = $oldApp
    $env:LOCALAPPDATA = $oldLocal
}
