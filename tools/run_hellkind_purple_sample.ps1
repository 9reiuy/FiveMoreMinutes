param([string]$Godot = '', [switch]$CheckOnly, [switch]$VolumeShadow)
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if (-not $Godot) {
    $candidates = @('E:\Godot\Godot_v4.7.1-stable_win64.exe', 'E:\Godot\Godot_v4.7.1-stable_win64_console.exe')
    $Godot = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}
if (-not $Godot) { throw 'Godot not found. Use -Godot C:\path\Godot.exe.' }
$dataPath = Join-Path $projectPath '.runtime\hellkind_purple_sample_20261103\interactive_data'
$scenePath = if ($VolumeShadow) { 'res://scenes/preview/visibility_light_sample.tscn' } else { 'res://scenes/preview/hellkind_purple_sample.tscn' }
if ($CheckOnly) { Write-Output "Godot: $Godot`nProject: $projectPath`nRenderer: Forward+ (sample only)`nScene: $scenePath`nIsolated data: $dataPath"; exit 0 }
New-Item -ItemType Directory -Force -Path (Join-Path $dataPath 'appdata'), (Join-Path $dataPath 'localappdata') | Out-Null
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $dataPath 'appdata'
    $env:LOCALAPPDATA = Join-Path $dataPath 'localappdata'
    # This launcher is explicitly for the user's interactive sample window.
    Start-Process -FilePath $Godot -WorkingDirectory $projectPath -ArgumentList @('--path', ('"' + $projectPath + '"'), '--rendering-method', 'forward_plus', '--resolution', '1280x720', $scenePath)
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
