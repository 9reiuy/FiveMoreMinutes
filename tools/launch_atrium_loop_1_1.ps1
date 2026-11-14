param(
    [switch]$Diagnostic,
    [string]$DiagOutDir = '',
    [string]$Godot = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$enginePath = if ($Godot) { $Godot } else { 'E:\Godot\Godot_v4.7.1-stable_win64.exe' }
if ($Diagnostic -and ($enginePath -match '(?i)(?<!_console)\.exe$')) {
    $consoleEngine = $enginePath -replace '(?i)\.exe$', '_console.exe'
    if (Test-Path -LiteralPath $consoleEngine -PathType Leaf) { $enginePath = $consoleEngine }
}
if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    throw "Godot executable not found: $enginePath"
}

$runtimeDir = Join-Path $projectRoot '.runtime\atrium_loop11'
$profileRoot = Join-Path $runtimeDir 'user_data'
$appdata = Join-Path $profileRoot 'appdata'
$localappdata = Join-Path $profileRoot 'localappdata'
New-Item -ItemType Directory -Force -Path $runtimeDir, $profileRoot, $appdata, $localappdata | Out-Null

$env:APPDATA = $appdata
$env:LOCALAPPDATA = $localappdata

$engineArgs = @(
    '--path', ('"' + $projectRoot + '"'),
    '--max-fps', '60',
    '--disable-vsync',
    '--windowed',
    '--resolution', '1280x720'
)

$diagTarget = if ($DiagOutDir) { $DiagOutDir } else { Join-Path $runtimeDir 'diag_captures' }
if ($Diagnostic) {
    $appDataName = 'Five Minutes More' + [char]0x6539 + [char]0x7248
    $settingsDir = Join-Path $appdata ('Godot\app_userdata\' + $appDataName)
    New-Item -ItemType Directory -Force -Path $settingsDir, $diagTarget | Out-Null
    [IO.File]::WriteAllText((Join-Path $settingsDir 'game_settings.cfg'), "[audio]`nmaster_volume=0`nmusic_volume=0`nsfx_volume=0`n", (New-Object Text.UTF8Encoding $false))
    $diagNorm = $diagTarget.Replace('\', '/')
    $engineArgs += @(
        '--audio-driver', 'Dummy',
        '--position', '-30000,-30000',
        '--quit-after', '600',
        '--log-file', ('"' + (Join-Path $runtimeDir 'engine.log') + '"'),
        'res://scenes/testing/AtriumLoop11TestLab.tscn',
        '--',
        ('--atrium-diag=' + $diagNorm)
    )
} else {
    $engineArgs += @('res://scenes/testing/AtriumLoop11TestLab.tscn')
}

$windowStyle = if ($Diagnostic) { 'Hidden' } else { 'Normal' }
$game = Start-Process -FilePath $enginePath -ArgumentList $engineArgs -WorkingDirectory $projectRoot -WindowStyle $windowStyle -PassThru
try {
    while (-not $game.HasExited) {
        $game.Refresh()
        try {
            if ([string]$game.PriorityClass -ne 'BelowNormal') {
                $game.PriorityClass = [Diagnostics.ProcessPriorityClass]::BelowNormal
            }
        } catch {
            if (-not $game.HasExited) { throw }
        }
        if ($game.WaitForExit(200)) { break }
    }
    $game.WaitForExit()
    exit $game.ExitCode
} finally {
    $game.Dispose()
}
