param(
    [string]$GodotExecutable = 'E:\Godot\Godot_v4.7.1-stable_win64_console.exe',
    [string]$ProjectPath = (Split-Path $PSScriptRoot -Parent),
    [switch]$Quick,
    [switch]$SkipCombat
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath $ProjectPath).Path
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'project.godot'))) { throw 'Select the FiveMinuteMore project directory.' }
if (-not (Test-Path -LiteralPath $GodotExecutable)) { throw 'Pass -GodotExecutable with Godot 4.7.1 console executable.' }
$runRoot = Join-Path $projectRoot ('.runtime/perf_delivery_20261013/machine_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '_' + [Guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null
# Redirect user data so test-only Main entry never changes the player's saves.
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
$env:APPDATA = Join-Path $runRoot 'appdata'
$env:LOCALAPPDATA = Join-Path $runRoot 'localappdata'
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
New-Item -ItemType Directory -Force -Path $env:LOCALAPPDATA | Out-Null
$results = [System.Collections.Generic.List[object]]::new()
try {
    $hardwareErrors = [System.Collections.Generic.List[string]]::new()
    $cpu = $null; $gpu = $null; $ram = $null; $disks = $null
    try { $cpu = @(Get-CimInstance Win32_Processor | Select-Object -ExpandProperty Name) } catch {
        $hardwareErrors.Add('CPU CIM: ' + $_.Exception.Message)
        try { $cpu = (Get-ItemProperty -LiteralPath 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0').ProcessorNameString } catch { $hardwareErrors.Add('CPU registry: ' + $_.Exception.Message) }
    }
    try { $gpu = @(Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion) } catch {
        $hardwareErrors.Add('GPU CIM: ' + $_.Exception.Message)
        try {
            $nvidiaCommand = Get-Command nvidia-smi.exe -ErrorAction Stop
            $gpu = @(& $nvidiaCommand.Source --query-gpu=name,driver_version --format=csv,noheader)
        } catch { $hardwareErrors.Add('GPU fallback: ' + $_.Exception.Message) }
    }
    try { $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1) } catch { $hardwareErrors.Add('RAM unavailable: ' + $_.Exception.Message) }
    try { $disks = @(Get-PhysicalDisk | Select-Object FriendlyName, MediaType, Size) } catch { $hardwareErrors.Add('Disks unavailable: ' + $_.Exception.Message) }
    $machine = [ordered]@{
        cpu = $cpu
        gpu = $gpu
        ram_gib = $ram
        disks = $disks
        hardware_collection_errors = @($hardwareErrors)
        date_utc = [DateTime]::UtcNow.ToString('o')
        godot = $GodotExecutable
        project = $projectRoot
        scope = $(if ($Quick) { 'smoke only; no full acceptance claim' } else { 'full requested acceptance' })
        presentation = 'minimized native window, explicit real-GPU rendering; not foreground presentation'
    }
    $machine | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $runRoot 'machine.json') -Encoding utf8
    $script:acceptanceFailures = 0
    function Invoke-AcceptanceTest([string]$name, [string]$scriptPath, [string[]]$userArgs) {
        Write-Host "Running $name"
        $log = Join-Path $runRoot ($name + '.log')
        $testArtifacts = Join-Path $runRoot $name
        New-Item -ItemType Directory -Force -Path $testArtifacts | Out-Null
        $effectiveArgs = @($userArgs) + '--background-gpu' + "--artifact-dir=$testArtifacts"
        & $GodotExecutable --path $projectRoot --windowed --resolution 32x32 --position '-30000,-30000' --audio-driver Dummy --script $scriptPath -- @effectiveArgs *> $log
        $code = $LASTEXITCODE
        $results.Add([ordered]@{ name=$name; exit_code=$code; log=$log; artifacts=$testArtifacts; passed=($code -eq 0) })
        if ($code -ne 0) { $script:acceptanceFailures++ }
        Write-Host "$name exit code $code"
    }
    if (-not $SkipCombat) {
        foreach ($skeleton in @('A1','B2','C3','V3')) {
            $combatArgs = @('--output-1080','--acceptance','--controlled-start','--bounded-route','--stable-identities','--canonical-identities','--prepare-firearm-rendering','--aim-wall',"--skeleton=$skeleton",'--seed=41001')
            if ($Quick) { $combatArgs += '--preflight' }
            Invoke-AcceptanceTest "combat_$skeleton" 'res://tests/random_combat_perf.gd' $combatArgs
        }
    }
    $soakArgs = @()
    if ($Quick) { $soakArgs += '--duration=15' }
    Invoke-AcceptanceTest 'formal_soak' 'res://tests/formal_performance_acceptance.gd' $soakArgs
    foreach ($test in @('character_projection_world_test','character_weapon_projection_test')) {
        Invoke-AcceptanceTest $test "res://tests/$test.gd" @()
    }
    $results | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $runRoot 'results.json') -Encoding utf8
    Compress-Archive -Path (Join-Path $runRoot '*') -DestinationPath ($runRoot + '.zip')
    Write-Host "Results: $runRoot.zip"
    if ($script:acceptanceFailures -gt 0) { exit 1 }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
