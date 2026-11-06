param([ValidateSet('canary','render','events','combat')][string]$Batch='canary', [ValidatePattern('^[a-zA-Z0-9_-]*$')][string]$RunTag='', [ValidatePattern('^[a-z_,]*$')][string]$Arms='', [double]$Seconds=0, [switch]$Prewarm)
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if(-not $RunTag){$RunTag='run_'+(Get-Date -Format 'yyyyMMdd_HHmmss')}
$outputPath=Join-Path $projectPath '.runtime\lab_ablation_20261102'
if($RunTag){$outputPath=Join-Path $outputPath $RunTag}
[void](New-Item -ItemType Directory -Path $outputPath -Force)
$otherGames=@(Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot%'" | Where-Object { $_.CommandLine -notmatch '(?:^|\s)--editor(?:\s|$)' })
if($otherGames.Count -gt 0){$otherGames | Select-Object ProcessId,CommandLine | ConvertTo-Json -Compress;throw 'Another game/test is running. No GPU test started.'}
$paths=@('scripts/dream/dream_3d_random_dungeon.gd','scripts/dream/dream_3d_actor_depth_bridge.gd','scripts/dream/fire_extinguisher_system.gd','scripts/entities/black_blood_effect.gd','scripts/entities/basic_projectile.gd','scripts/entities/employee_enemy.gd','scripts/dream/destruction_floor_debris.gd','scripts/dream/office_shadow_manager.gd','scripts/dream/floor_reflections.gd','scripts/dream/office_pixel_materials.gd','scripts/dream/preview/sample_wall_and_desktop_review.gd','art/Dream/dream_chr_32x32.png','art/Dream/enemy/Employee_men_32x32.png','project.godot')
$paths+=@(rg --files scripts scenes shaders -g '*.gd' -g '*.tscn' -g '*.gdshader' -g '*.gdshaderinc')
$paths+=@('tests/lab_ablation_suite.gd','tests/support/lab_probe_sink.gd','scripts/testing/lab_world.gd')
$paths=@($paths | ForEach-Object {$_ -replace '\\','/'} | Sort-Object -Unique)
$before=@{}
foreach($path in $paths){$before[$path]=(Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $projectPath $path)).Hash}
$oldAppData=$env:APPDATA
$env:APPDATA=Join-Path $outputPath 'appdata'
$log=Join-Path $outputPath ($Batch+'.log')
if(Test-Path -LiteralPath $log){$env:APPDATA=$oldAppData;throw 'Run tag already contains this batch. Choose a new run tag; prior evidence is retained.'}
$environmentSamples=[System.Collections.Generic.List[object]]::new()
try {
    $gameArgs=@('--path',$projectPath,'--script','res://tests/lab_ablation_suite.gd','--log-file',$log,'--',('--batch='+$Batch),('--output=res://.runtime/lab_ablation_20261102/'+$RunTag))
    if($Arms){$gameArgs+=('--arms='+$Arms)}
    if($Seconds -gt 0){$gameArgs+=('--seconds='+$Seconds)}
    if($Prewarm){$gameArgs+='--formal-prewarm'}
    $process=Start-Process -FilePath 'C:\Users\Administrator\Desktop\Godot_v4.7.1-stable_win64.exe' -WorkingDirectory $projectPath -ArgumentList $gameArgs -WindowStyle Hidden -PassThru
    while(-not $process.HasExited) {
        $os=Get-CimInstance Win32_OperatingSystem
        $peers=@(Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot%'" | Where-Object { $_.ProcessId -ne $process.Id -and $_.CommandLine -notmatch '(?:^|\s)--editor(?:\s|$)' } | Select-Object ProcessId,CommandLine)
        $environmentSamples.Add(@{utc=[DateTime]::UtcNow.ToString('o');free_physical_kib=[int64]$os.FreePhysicalMemory;peers=$peers;gpu=(& nvidia-smi --query-gpu=utilization.gpu,memory.used,temperature.gpu --format=csv,noheader | Out-String).Trim()})
        [void]$process.WaitForExit(5000)
    }
    $after=@{};$changed=@()
    foreach($path in $paths){$after[$path]=(Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $projectPath $path)).Hash;if($after[$path] -ne $before[$path]){$changed+=$path}}
    $audit=@{batch=$Batch;exit_code=$process.ExitCode;before=$before;after=$after;changed_during_run=$changed;environment=$environmentSamples}
    [System.IO.File]::WriteAllText((Join-Path $outputPath ($Batch+'_environment.json')),($audit | ConvertTo-Json -Depth 8))
    Write-Output ('EXIT='+$process.ExitCode)
    Write-Output ('CHANGED='+($changed -join ', '))
    Get-Content -LiteralPath $log -Tail 12
} finally {$env:APPDATA=$oldAppData}
