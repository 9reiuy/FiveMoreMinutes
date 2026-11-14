param(
    [string]$Godot = '',
    [switch]$CheckOnly,
    [switch]$Validate,
    [switch]$Capture
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

$labData = Join-Path $projectPath '.runtime\megastructure_whitebox\user_data'
New-Item -ItemType Directory -Force -Path (Join-Path $labData 'appdata'), (Join-Path $labData 'localappdata') | Out-Null

if ($CheckOnly) {
	Write-Output "Level: 0-1 (standalone)"
    Write-Output "Project: $projectPath"
    Write-Output "Renderer: shared Forward+ / Vulkan from project.godot"
    Write-Output "Scene: res://scenes/testing/MegastructureWhiteboxDisplay.tscn"
    Write-Output "World: 640x360; Window: 1280x720; production player, AI, combat and HUD"
    exit 0
}

$oldApp = $env:APPDATA
$oldLocal = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $labData 'appdata'
    $env:LOCALAPPDATA = Join-Path $labData 'localappdata'
    $argsList = @(
        '--path', ('"' + $projectPath + '"'),
        '--resolution', '1280x720',
        'res://scenes/testing/MegastructureWhiteboxDisplay.tscn'
    )
    if ($Validate -or $Capture) {
        $testRoot = Join-Path $projectPath ('.runtime\megastructure_basement_20261107\run_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
        $env:APPDATA = Join-Path $testRoot 'appdata'
        $env:LOCALAPPDATA = Join-Path $testRoot 'localappdata'
        $dataName = 'Five Minutes More' + [char]0x6539 + [char]0x7248
        $userSettings = Join-Path $env:APPDATA ('Godot\app_userdata\' + $dataName)
        New-Item -ItemType Directory -Force -Path $userSettings, $env:LOCALAPPDATA | Out-Null
        [IO.File]::WriteAllText((Join-Path $userSettings 'game_settings.cfg'), "[audio]`nmaster_volume=0`nmusic_volume=0`nsfx_volume=0`n", (New-Object System.Text.UTF8Encoding($false)))
        $entry = if ($Capture) { 'res://tools/capture_whitebox_preview.gd' } else { 'res://tools/test_whitebox_combat.gd' }
        $argsList = @('--path', ('"' + $projectPath + '"'), '--audio-driver', 'Dummy', '--resolution', '1280x720', '--script', $entry, '--', ('--artifact-dir=' + $testRoot))
        if ($Validate -and -not $Capture) { $argsList = @('--headless', '--fixed-fps', '60') + $argsList }
        $process = Start-Process -FilePath $Godot -WorkingDirectory $projectPath -ArgumentList $argsList -WindowStyle Hidden -RedirectStandardOutput (Join-Path $testRoot 'stdout.log') -RedirectStandardError (Join-Path $testRoot 'stderr.log') -PassThru
        $processHandle = $process.Handle
        Write-Output "Test PID: $($process.Id); artifacts: $testRoot; audio: Dummy + private Master=0"
        $process.Id | Set-Content -LiteralPath (Join-Path $testRoot 'pid.txt')
        if (-not $process.WaitForExit(180000)) {
            Stop-Process -Id $process.Id -Force
            throw "Whitebox validation timed out. See $testRoot"
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
    Write-Host "[LAUNCH] 0-1 - standalone level" -ForegroundColor Cyan
    & (Join-Path $PSScriptRoot 'launch_screen_wall.ps1') -Presentation level01 -Godot $Godot
} finally {
    $env:APPDATA = $oldApp
    $env:LOCALAPPDATA = $oldLocal
}
