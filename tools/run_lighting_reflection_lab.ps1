param([string]$Godot = '', [switch]$CheckOnly, [string]$ValidationScript = '', [switch]$CheckScript)
$ErrorActionPreference = 'Stop'
$source = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$lab = Join-Path $source '.runtime\lighting_reflection_lab_20261104'
$projectPath = Join-Path $lab 'project'
if (-not $Godot) { $Godot = 'E:\Godot\Godot_v4.7.1-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $Godot)) { throw 'Godot 4.7.1 is required.' }
if (-not (Test-Path -LiteralPath (Join-Path $projectPath 'lighting_lab\lab.tscn'))) { throw 'Independent experiment snapshot is missing.' }
if ($CheckOnly) {
    Write-Output "Isolated project: $projectPath`nRenderer: Compatibility`nA: current sparse lights; B: clear reflection; C: softer reflection; B/C: one window source`nKeys: 1 / 2 / 3; F1 panel; F6 room; F10 rebuild"
    exit 0
}
$dataPath = Join-Path $lab 'user_data'
New-Item -ItemType Directory -Force -Path (Join-Path $dataPath 'appdata'), (Join-Path $dataPath 'localappdata') | Out-Null
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $dataPath 'appdata'
    $env:LOCALAPPDATA = Join-Path $dataPath 'localappdata'
    $arguments = @('--path', $projectPath, '--rendering-method', 'gl_compatibility')
    if ($ValidationScript) { $arguments += @('--script', $ValidationScript) }
    if ($CheckScript) { $arguments += @('--headless', '--check-only') }
    & $Godot @arguments
    exit $LASTEXITCODE
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
