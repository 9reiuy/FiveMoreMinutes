param(
    [ValidateSet('Functional', 'Performance')][string]$Mode = 'Functional',
    [ValidateSet('Volume', 'Combined', 'Surface')][string]$Profile = 'Volume',
    [switch]$Baseline,
    [string]$Godot = 'E:\Godot\Godot_v4.7.1-stable_win64.exe',
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
if ($Baseline -and ($Profile -ne 'Surface' -or $Mode -ne 'Functional')) { throw 'Baseline is supported only by the Surface functional profile.' }
$projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$outputPath = Join-Path $projectPath '.runtime\hellkind_purple_sample_20261103\volume_shadow_revision'
if ($Profile -eq 'Combined') { $outputPath = Join-Path $projectPath '.runtime\hellkind_purple_sample_20261103\combined_art_visibility' }
if ($Profile -eq 'Surface') { $outputPath = Join-Path $projectPath '.runtime\hellkind_purple_sample_20261103\visibility_surface_revision' }
if ($Mode -eq 'Performance') {
    # The ordinary process list suffices when no matching application is
    # running. Query command lines only to distinguish an open Godot editor.
    $runningGames = @(Get-Process Godot*, Endfield, MaaEnd -ErrorAction SilentlyContinue)
    if ($runningGames.Count -gt 0) {
        $runningGames = @(Get-CimInstance Win32_Process | Where-Object {
            $_.Name -match '^(Endfield|MaaEnd)\.exe$' -or
            ($_.Name -match '^Godot.*\.exe$' -and $_.CommandLine -notmatch '(?:^|\s)--editor(?:\s|$)')
        })
    }
    if ($runningGames.Count -gt 0) { throw 'Other games or Godot tests are running. No process was stopped.' }
}
$scriptPath = if ($Mode -eq 'Functional') { 'res://tests/woo_volume_shadow_test.gd' } else { 'res://tests/woo_volume_shadow_performance_test.gd' }
if ($Profile -eq 'Combined') {
    $scriptPath = if ($Mode -eq 'Functional') { 'res://tests/combined_art_visibility_test.gd' } else { 'res://tests/combined_art_visibility_performance_test.gd' }
}
if ($Profile -eq 'Surface') {
    $scriptPath = if ($Mode -eq 'Functional') { 'res://tests/visibility_surface_stability_test.gd' } else { 'res://tests/combined_art_visibility_performance_test.gd' }
}
if ($CheckOnly) { Write-Output "Project: $projectPath`nScript: $scriptPath`nOutput: $outputPath"; exit 0 }
New-Item -ItemType Directory -Force -Path $outputPath, (Join-Path $outputPath 'appdata'), (Join-Path $outputPath 'localappdata') | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$sourceFiles = @(Get-ChildItem -LiteralPath (Join-Path $projectPath 'scripts\preview'), (Join-Path $projectPath 'scripts\dream'), (Join-Path $projectPath 'scripts\entities'), (Join-Path $projectPath 'shaders\preview\hellkind_sample'), (Join-Path $projectPath 'shaders\dream3d'), (Join-Path $projectPath 'scripts\testing') -Recurse -File | Where-Object { $_.Extension -in '.gd', '.gdshader', '.gdshaderinc' })
$beforeHashes = @{}
foreach ($sourceFile in $sourceFiles) { $beforeHashes[$sourceFile.FullName] = (Get-FileHash -LiteralPath $sourceFile.FullName).Hash }
$originalAppData = $env:APPDATA
$originalLocalData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $outputPath 'appdata'
    $env:LOCALAPPDATA = Join-Path $outputPath 'localappdata'
    $arguments = @('--path', ('"' + $projectPath + '"'), '--rendering-method', 'forward_plus', '--audio-driver', 'Dummy', '--position', '50,50', '--resolution', '1280x720', '--script', $scriptPath)
    if ($Baseline) { $arguments += @('--', '--baseline') }
    if ($Profile -eq 'Surface' -and $Mode -eq 'Performance') { $arguments += @('--', '--surface-check') }
    $process = Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $outputPath "$Mode-$stamp.stdout.txt") -RedirectStandardError (Join-Path $outputPath "$Mode-$stamp.stderr.txt")
    $null = $process.Handle
    Write-Output "Test: $Mode / $stamp"
    $process.WaitForExit()
    if ($null -eq $process.ExitCode) { throw 'Exit code unavailable; inspect the test logs.' }
    $changedSources = @($beforeHashes.Keys | Where-Object { (Get-FileHash -LiteralPath $_).Hash -ne $beforeHashes[$_] })
    $cleanLog = (Get-Item -LiteralPath (Join-Path $outputPath "$Mode-$stamp.stderr.txt")).Length -eq 0
    @{ mode=$Mode; stamp=$stamp; source_files=$beforeHashes.Count; changed_sources=$changedSources; runtime_log_clean=$cleanLog; engine_exit_code=$process.ExitCode; hashes_before=$beforeHashes } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $outputPath "$Mode-$stamp.audit.json")
    if ($changedSources.Count -gt 0) { Write-Output 'Shared source changed during the run; this is diagnostic evidence only.'; exit 3 }
    if (-not $cleanLog) { Write-Output 'Runtime diagnostic log is nonempty; this is not a clean acceptance.'; exit 2 }
    Write-Output "Exit: $($process.ExitCode)"
    exit $process.ExitCode
} finally {
    $env:APPDATA = $originalAppData
    $env:LOCALAPPDATA = $originalLocalData
}
