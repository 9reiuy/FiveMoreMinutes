param([string]$Godot = '', [switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if (-not $Godot) {
    $onPath = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($onPath) { $Godot = $onPath.Source }
    else {
        $candidates = @('E:\Godot\Godot_v4.7.1-stable_win64_console.exe', (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Godot_v4.7.1-stable_win64.exe'))
        $Godot = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    }
}
if (-not $Godot -or -not (Test-Path -LiteralPath $Godot -PathType Leaf)) { throw 'Godot not found. Run tools\run_test_lab.ps1 -Godot C:\path\Godot.exe' }
$labData = Join-Path $projectPath '.runtime\test_lab\appdata'
if ($CheckOnly) { Write-Output "Godot: $Godot`nProject: $projectPath`nIsolated APPDATA: $labData"; exit 0 }
New-Item -ItemType Directory -Force -Path $labData | Out-Null
$oldAppData = $env:APPDATA
try {
    $env:APPDATA = $labData
    # The requested interactive playground is intentionally visible.
    Start-Process -FilePath $Godot -WorkingDirectory $projectPath -ArgumentList @('--path', ('"' + $projectPath + '"'), '--resolution', '1280x720', 'res://scenes/testing/GameTestLab.tscn')
} finally { $env:APPDATA = $oldAppData }
