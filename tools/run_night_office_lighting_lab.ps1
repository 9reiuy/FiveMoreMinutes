param([string]$Godot = '', [switch]$CheckOnly, [string]$ValidationScript = '', [switch]$CheckScript, [switch]$Import)
$ErrorActionPreference = 'Stop'
$source = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$lab = Join-Path $source '.runtime\visual004_roles_20261104\main'
$projectPath = Join-Path $lab 'project'
if (-not $Godot) { $Godot = 'E:\Godot\Godot_v4.7.1-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $Godot)) { throw 'Godot 4.7.1 is required.' }
if (-not (Test-Path -LiteralPath (Join-Path $projectPath 'project.godot'))) { throw 'Independent project missing.' }
if ($CheckOnly) { Write-Output "Project: $projectPath. N2 is the default. 7 selects N2, 8 selects experimental persistent lighting. F6 changes room."; exit 0 }
$data = Join-Path $lab 'user_data'
New-Item -ItemType Directory -Force -Path (Join-Path $data 'appdata'), (Join-Path $data 'localappdata') | Out-Null
$savedApp = $env:APPDATA
$savedLocal = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $data 'appdata'
    $env:LOCALAPPDATA = Join-Path $data 'localappdata'
    $arguments = @('--path', $projectPath, '--rendering-method', 'gl_compatibility')
    if ($ValidationScript) { $arguments += @('--script', $ValidationScript) }
    if ($CheckScript) { $arguments += @('--headless', '--check-only') }
    if ($Import) { $arguments += @('--headless', '--editor', '--import', '--quit') }
    & $Godot @arguments
    exit $LASTEXITCODE
} finally {
    $env:APPDATA = $savedApp
    $env:LOCALAPPDATA = $savedLocal
}
