param([switch]$Diagnostic,[switch]$Perf,[switch]$Baseline,[switch]$Capture,[switch]$LightProbe,[string]$Context='bedroom',[string]$Stem='review',[string]$ScriptFile='')
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$evidence=Join-Path $projectRoot '.runtime\phone_polish_20261108'
$profileRoot=if($Diagnostic){Join-Path $evidence ($Stem+'_phone_private')}else{Join-Path $evidence 'player'}
$mutex=New-Object Threading.Mutex($false,'Local\FiveMinuteMorePhonePolish')
$ownsMutex=$false
$ownedGame=$null
$gpuLease=$null
try {
    try{$ownsMutex=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$ownsMutex=$true}
    if(-not $ownsMutex){Write-Output 'The phone preview is already running.';return}
    $gpuLock=Join-Path $projectRoot '.runtime\visual004_roles_20261104\performance_r2\rendering_path_v1\options_research_20261105\playable.lock'
    if(Test-Path -LiteralPath $gpuLock){
        $leaseWatch=[Diagnostics.Stopwatch]::StartNew()
        do {
            try{$gpuLease=[IO.File]::Open($gpuLock,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}
            catch {
                if(-not $Diagnostic -or $leaseWatch.ElapsedMilliseconds -gt 45000){Write-Output 'The shared GPU validation slot is occupied.';return}
                Start-Sleep -Milliseconds 1500
            }
        }while($null -eq $gpuLease)
    }
    $env:APPDATA=Join-Path $profileRoot 'appdata'
    $env:LOCALAPPDATA=Join-Path $profileRoot 'localappdata'
    New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
    $engineArgs=@('--path',('"'+$projectRoot+'"'),'--max-fps','60','--disable-vsync','--windowed','--resolution','1280x720')
    if($Diagnostic){
        $settings=Join-Path $env:APPDATA ('Godot\app_userdata\Five Minutes More'+[char]0x6539+[char]0x7248)
        New-Item -ItemType Directory -Force -Path $settings | Out-Null
        [IO.File]::WriteAllText((Join-Path $settings 'game_settings.cfg'),"[audio]`nmaster_volume=0`nmusic_volume=0`nsfx_volume=0`n",(New-Object Text.UTF8Encoding $false))
        $audio=if($Perf){'WASAPI'}else{'Dummy'}
        $engineArgs+=@('--audio-driver',$audio,'--position','-30000,-30000','--quit-after','5000','--log-file',('"'+(Join-Path $evidence ($Stem+'_engine.log'))+'"'))
    }
    if($ScriptFile){$engineArgs+=@('--script',$ScriptFile)}else{$engineArgs+='res://.runtime/phone_polish_20261108/candidate/phone_lab.tscn'}
    $engineArgs+=@('--','--enforce-frame-budget',('--output-dir=res://.runtime/phone_polish_20261108/evidence/'+$Stem))
    if($Baseline){$engineArgs+='--baseline-phone'}
    if($Perf){$engineArgs+='--perf-phone'}
    if($Capture){$engineArgs+='--capture-phone'}
    if($LightProbe){$engineArgs+='--light-probe'}
    if($Context -eq '3d'){$engineArgs+='--phone-context=3d'}
    $windowStyle=if($Diagnostic){'Hidden'}else{'Normal'}
    $ownedGame=Start-Process -FilePath 'E:\Godot\Godot_v4.7.1-stable_win64.exe' -ArgumentList $engineArgs -WorkingDirectory $projectRoot -WindowStyle $windowStyle -PassThru
    if($Diagnostic){[IO.File]::WriteAllText((Join-Path $evidence ($Stem+'_started.json')),(@{pid=$ownedGame.Id;script=$ScriptFile}|ConvertTo-Json),(New-Object Text.UTF8Encoding $false))}
    $watch=[Diagnostics.Stopwatch]::StartNew()
    while(-not $ownedGame.HasExited){
        $ownedGame.Refresh()
        if(-not $ownedGame.HasExited -and $ownedGame.PriorityClass -ne 'BelowNormal'){$ownedGame.PriorityClass='BelowNormal'}
        if($Diagnostic -and $watch.ElapsedMilliseconds -gt 120000){$ownedGame.Kill();throw 'Owned phone check timed out.'}
        $ownedGame.WaitForExit(250) | Out-Null
    }
    $ownedGame.WaitForExit()
    if($Diagnostic){
        $record=@{pid=$ownedGame.Id;exit=$ownedGame.ExitCode;elapsed_ms=$watch.ElapsedMilliseconds;audio=$audio;priority='BelowNormal';renderer='project.godot';baseline=[bool]$Baseline}
        [IO.File]::WriteAllText((Join-Path $evidence ($Stem+'_process.json')),($record|ConvertTo-Json),(New-Object Text.UTF8Encoding $false))
        $record|ConvertTo-Json -Compress
        Get-Content -LiteralPath (Join-Path $evidence ($Stem+'_engine.log')) -Tail 16
        $engineErrors=Select-String -LiteralPath (Join-Path $evidence ($Stem+'_engine.log')) -Pattern 'SCRIPT ERROR|SHADER ERROR|^ERROR:'
        if($engineErrors){throw 'The owned phone check reported engine script or shader errors.'}
    }
}finally{
    if($null -ne $ownedGame){$ownedGame.Dispose()}
    if($null -ne $gpuLease){$gpuLease.Dispose()}
    if($ownsMutex){$mutex.ReleaseMutex()}
    $mutex.Dispose()
}
