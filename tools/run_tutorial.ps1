param(
    [string]$Godot = '',
    [switch]$CheckOnly,
    [switch]$Validate,
    [switch]$Capture,
    [switch]$ColourCheck
)
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path

if (-not $Godot) {
    $candidates = @(
        'E:\Godot\Godot_v4.7.1-stable_win64.exe',
        'E:\Godot\Godot_v4.7.1-stable_win64_console.exe'
    )
    $Godot = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}
if (-not $Godot -or -not (Test-Path -LiteralPath $Godot -PathType Leaf)) {
    throw "Godot 4.7.1 executable not found. Pass -Godot with full path."
}

$labData = Join-Path $projectPath '.runtime\tutorial_maintenance\user_data'
New-Item -ItemType Directory -Force -Path (Join-Path $labData 'appdata'), (Join-Path $labData 'localappdata') | Out-Null

if ($CheckOnly) {
	Write-Output "Level: Tutorial (standalone)"
    Write-Output "Project: $projectPath"
    Write-Output "Renderer: shared Forward+ / Vulkan from project.godot"
    Write-Output "Pacing: foreground 60 / background 30; game VSync disabled; BelowNormal process priority"
    Write-Output "Scene: res://scenes/testing/TutorialMaintenanceDisplay.tscn"
    Write-Output "World: 640x360; Window: 1280x720; production player, AI, combat and HUD"
    exit 0
}

$oldApp = $env:APPDATA
$oldLocal = $env:LOCALAPPDATA
$gpuLease = $null
try {
    $env:APPDATA = Join-Path $labData 'appdata'
    $env:LOCALAPPDATA = Join-Path $labData 'localappdata'
    $argsList = @(
        '--path', ('"' + $projectPath + '"'),
        '--resolution', '1280x720',
        'res://scenes/testing/TutorialMaintenanceDisplay.tscn'
    )
    if ($Validate -or $Capture -or $ColourCheck) {
        if ($Capture -or $ColourCheck) {
            $sharedGpu = Join-Path $projectPath '.runtime\visual004_roles_20261104\performance_r2\rendering_path_v1\options_research_20261105\playable.lock'
            $gpuLease = [IO.File]::Open($sharedGpu,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
        }
        $testRoot = Join-Path $projectPath ('.runtime\tutorial_revision_20261108\run_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
        $env:APPDATA = Join-Path $testRoot 'appdata'
        $env:LOCALAPPDATA = Join-Path $testRoot 'localappdata'
        $dataName = 'Five Minutes More' + [char]0x6539 + [char]0x7248
        $userSettings = Join-Path $env:APPDATA ('Godot\app_userdata\' + $dataName)
        New-Item -ItemType Directory -Force -Path $userSettings, $env:LOCALAPPDATA | Out-Null
        [IO.File]::WriteAllText((Join-Path $userSettings 'game_settings.cfg'), "[audio]`nmaster_volume=0`nmusic_volume=0`nsfx_volume=0`n", (New-Object System.Text.UTF8Encoding($false)))
        $entry = if ($ColourCheck) { 'res://tests/native_colour_render_test.gd' } elseif ($Capture) { 'res://tests/tutorial_revision_route.gd' } else { 'res://tests/tutorial_revision_test.gd' }
        $argsList = @('--path', ('"' + $projectPath + '"'), '--audio-driver', 'Dummy', '--resolution', '1280x720', '--script', $entry, '--', ('--artifact-dir=' + $testRoot))
        if ($Validate -and -not $Capture -and -not $ColourCheck) { $argsList = @('--headless', '--fixed-fps', '60') + $argsList }
        $process = Start-Process -FilePath $Godot -WorkingDirectory $projectPath -ArgumentList $argsList -WindowStyle Hidden -RedirectStandardOutput (Join-Path $testRoot 'stdout.log') -RedirectStandardError (Join-Path $testRoot 'stderr.log') -PassThru
        $processHandle = $process.Handle
        Write-Output "Test PID: $($process.Id); artifacts: $testRoot; audio: Dummy + private Master=0"
        $process.Id | Set-Content -LiteralPath (Join-Path $testRoot 'pid.txt')
        if (-not $process.WaitForExit(180000)) {
            Stop-Process -Id $process.Id -Force
            throw "Tutorial validation timed out. See $testRoot"
        }
        $exitCode = $process.ExitCode
        if ($null -eq $exitCode) { $exitCode = 1 }
        $exitCode | Set-Content -LiteralPath (Join-Path $testRoot 'exit-code.txt')
        Get-Content -LiteralPath (Join-Path $testRoot 'stdout.log') -Encoding UTF8
        Get-Content -LiteralPath (Join-Path $testRoot 'stderr.log') -Encoding UTF8
        $errorsText = Get-Content -LiteralPath (Join-Path $testRoot 'stderr.log') -Encoding UTF8 -Raw
        if ($errorsText -match 'SCRIPT ERROR:|Parse Error|Compilation failed') { exit 1 }
        exit $exitCode
    }
    Write-Host "[LAUNCH] Tutorial - standalone maintenance training" -ForegroundColor Cyan
    & (Join-Path $PSScriptRoot 'launch_screen_wall.ps1') -Presentation tutorial -Godot $Godot
} finally {
    if ($null -ne $gpuLease) { $gpuLease.Dispose() }
    $env:APPDATA = $oldApp
    $env:LOCALAPPDATA = $oldLocal
}
