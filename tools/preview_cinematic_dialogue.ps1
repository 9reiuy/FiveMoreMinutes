param([string]$Godot = '', [switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if (-not $Godot) {
    $candidates = @('E:\Godot\Godot_v4.7.1-stable_win64.exe', 'E:\Godot\Godot_v4.7.1-stable_win64_console.exe')
    $Godot = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}
if (-not $Godot -or -not (Test-Path -LiteralPath $Godot -PathType Leaf)) { throw 'Godot 4.7 was not found. Supply -Godot with its executable path.' }
$caseRoot = Join-Path $projectPath '.runtime\cinematic_dialogue_20261117\play'
$scene = 'res://scenes/testing/CinematicDialogueLab.tscn'
if ($CheckOnly) { Write-Output "Godot: $Godot`nScene: $scene`nPrivate user data: $caseRoot"; exit 0 }
New-Item -ItemType Directory -Force -Path $caseRoot | Out-Null
$oldAppData = $env:APPDATA
$oldLocalAppData = $env:LOCALAPPDATA
$lease = $null
$game = $null
try {
    # Keep this preview separate from the player's save/settings, and prevent
    # accidental repeated launches from filling the graphics queue.
    $lockPath = Join-Path $caseRoot 'preview.lock'
    try { $lease = [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
    catch { Write-Host 'The dialogue preview is already running.'; exit 0 }
    $env:APPDATA = Join-Path $caseRoot 'appdata'
    $env:LOCALAPPDATA = Join-Path $caseRoot 'localappdata'
    New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
    $engineArgs = @('--path', ('"' + $projectPath + '"'), '--windowed', '--resolution', '1280x720', '--max-fps', '60', '--log-file', ('"' + (Join-Path $caseRoot 'engine.log') + '"'), $scene)
    # This is the user-opened interactive preview, so its window is visible.
    $game = Start-Process -FilePath $Godot -WorkingDirectory $projectPath -ArgumentList $engineArgs -PassThru
    @{pid=$game.Id;started=(Get-Date -Format o);scene=$scene}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $caseRoot 'started.json')
    while (-not $game.HasExited) {
        $game.Refresh()
        if (-not $game.HasExited -and $game.PriorityClass -ne 'BelowNormal') { $game.PriorityClass = 'BelowNormal' }
        $game.WaitForExit(750) | Out-Null
    }
    @{pid=$game.Id;exit=$game.ExitCode;ended=(Get-Date -Format o)}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $caseRoot 'process.json')
} finally {
    if ($null -ne $game) { $game.Dispose() }
    if ($null -ne $lease) { $lease.Dispose() }
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalAppData
}
