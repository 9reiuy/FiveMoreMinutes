param(
    [ValidateSet('Functional', 'Performance')][string]$Mode = 'Functional',
    [ValidateSet('gl_compatibility', 'forward_plus', 'mobile')][string]$Renderer = 'gl_compatibility',
    [string]$Godot = 'E:\Godot\Godot_v4.7.1-stable_win64.exe',
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$outputPath = Join-Path $projectPath '.runtime\hellkind_purple_sample_20261103\revision_woo_polygon'
if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) { throw "Godot not found: $Godot" }
$processes = @()
if ($Mode -eq 'Performance') { $processes = @(Get-CimInstance Win32_Process | Where-Object {
    $_.Name -match '^(Endfield|MaaEnd)\.exe$' -or
    ($_.Name -match '^Godot.*\.exe$' -and $_.CommandLine -notmatch '(?:^|\s)--editor(?:\s|$)')
}) }
if ($Mode -eq 'Performance' -and $processes.Count -gt 0) {
    throw ('Performance run deferred: ' + (($processes | ForEach-Object { "$($_.Name) [$($_.ProcessId)]" }) -join ', ') + '. No process was stopped.')
}
$scriptPath = if ($Mode -eq 'Functional') { 'res://tests/woo_visibility_sample_test.gd' } else { 'res://tests/woo_polygon_performance_test.gd' }
if ($CheckOnly) {
    Write-Output "Mode: $Mode`nRenderer: $Renderer`nProject: $projectPath`nGodot: $Godot`nScript: $scriptPath`nOutput: $outputPath"
    exit 0
}
New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$stdoutPath = Join-Path $outputPath "$Mode-$stamp.stdout.txt"
$stderrPath = Join-Path $outputPath "$Mode-$stamp.stderr.txt"
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $outputPath 'appdata'
    $env:LOCALAPPDATA = Join-Path $outputPath 'localappdata'
    $position = if ($Mode -eq 'Performance') { '50,50' } else { '-2000,-2000' }
    $arguments = @('--path', ('"' + $projectPath + '"'), '--rendering-method', $Renderer, '--audio-driver', 'Dummy', '--position', $position, '--resolution', '1280x720', '--script', $scriptPath)
    $process = Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $null = $process.Handle
    $process.WaitForExit()
    $code = $process.ExitCode
    if ($null -eq $code) { throw "Process exit code unavailable. Inspect $stdoutPath and $stderrPath; this is not a passing result." }
    Write-Output "Exit: $code`nOutput: $stdoutPath`nErrors: $stderrPath"
    exit $code
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
