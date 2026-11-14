param(
    [switch]$Diagnostic,
    [string]$DiagnosticProfile='',
    [ValidateSet('main','tutorial','level01','level02','level02vehicles','linked0102','level06','level11')][string]$Presentation='main',
    [string]$Godot=''
)
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$normalProfiles=@((Join-Path $projectRoot '.runtime\screen_wall_play'),(Join-Path $projectRoot '.runtime\tutorial_maintenance\user_data'),(Join-Path $projectRoot '.runtime\megastructure_whitebox\user_data'),(Join-Path $projectRoot '.runtime\parking_garage\user_data'),(Join-Path $projectRoot '.runtime\parking_vehicle_preview\user_data'),(Join-Path $projectRoot '.runtime\linked_0102\user_data'),(Join-Path $projectRoot '.runtime\train_06\user_data'))
$normalProfiles+=Join-Path $projectRoot '.runtime\research_atrium11\user_data'
$profileRoot=$normalProfiles[@{main=0;tutorial=1;level01=2;level02=3;level02vehicles=4;linked0102=5;level06=6;level11=7}[$Presentation]]
if($Diagnostic){
    if([string]::IsNullOrWhiteSpace($DiagnosticProfile)){throw 'A private diagnostic profile is required.'}
    $profileRoot=[IO.Path]::GetFullPath($DiagnosticProfile).TrimEnd([char[]]'\/')
    $runtimeRoot=[IO.Path]::GetFullPath((Join-Path $projectRoot '.runtime'))+[IO.Path]::DirectorySeparatorChar
    $isPlayerProfile=@($normalProfiles | Where-Object {$profileRoot -eq $_ -or $profileRoot.StartsWith($_+'\',[StringComparison]::OrdinalIgnoreCase)}).Count -gt 0
    if(-not $profileRoot.StartsWith($runtimeRoot,[StringComparison]::OrdinalIgnoreCase) -or $isPlayerProfile){
        throw 'Diagnostics must use a separate profile inside this project runtime directory.'
    }
}
New-Item -ItemType Directory -Force -Path $profileRoot | Out-Null
$identity=$projectRoot.ToLowerInvariant()+'|'+$profileRoot.ToLowerInvariant()
$sha=[Security.Cryptography.SHA256]::Create()
try{$identityHash=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($identity)))).Replace('-','')}finally{$sha.Dispose()}
$mutex=New-Object Threading.Mutex($false,('Local\FiveMinuteMoreScreenWall_'+$identityHash))
$ownsMutex=$false
$game=$null
$record=[ordered]@{launcher_pid=$PID;game_pid=$null;presentation=$Presentation;expected_priority='BelowNormal';vsync='disabled';rendering_policy='project.godot';rendering_method='forward_plus';rendering_driver='vulkan';foreground_cap=60;background_cap=30;profile=$profileRoot;diagnostic=[bool]$Diagnostic;changes=@();exit=$null}
$statusPath=Join-Path $profileRoot 'launcher_status.json'
function Write-LaunchStatus {
    [IO.File]::WriteAllText($statusPath,($record | ConvertTo-Json -Depth 5),(New-Object Text.UTF8Encoding $false))
}
try{
    try{$ownsMutex=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$ownsMutex=$true}
    if(-not $ownsMutex){
        Write-Output 'The television menu is already running.'
        return
    }
    $enginePath=if($Godot){$Godot}else{'E:\Godot\Godot_v4.7.1-stable_win64.exe'}
    if($enginePath -match '(?i)_console\.exe$'){
        $nativeEngine=$enginePath -replace '(?i)_console\.exe$','.exe'
        if(Test-Path -LiteralPath $nativeEngine -PathType Leaf){$enginePath=$nativeEngine}
    }
    if(-not (Test-Path -LiteralPath $enginePath -PathType Leaf)){throw 'Godot executable was not found.'}
    $env:APPDATA=Join-Path $profileRoot 'appdata'
    $env:LOCALAPPDATA=Join-Path $profileRoot 'localappdata'
    New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
    # One frame limiter drives pacing; avoid an additional driver swap wait in
    # the windowed preview. Keep this local to the playable launchers.
    $engineArgs=@('--path',('"'+$projectRoot+'"'),'--max-fps','60','--disable-vsync','--windowed','--resolution','1280x720')
    # All levels inherit the user-required Forward+ backend from project.godot.
    if($Diagnostic){
        $appDataName='Five Minutes More'+[char]0x6539+[char]0x7248
        $settingsDir=Join-Path $env:APPDATA ('Godot\app_userdata\'+$appDataName)
        New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null
        [IO.File]::WriteAllText((Join-Path $settingsDir 'game_settings.cfg'),"[audio]`nmaster_volume=0`nmusic_volume=0`nsfx_volume=0`n",(New-Object Text.UTF8Encoding $false))
        $engineArgs+=@('--audio-driver','Dummy','--position','-30000,-30000','--quit-after','360','--print-fps','--log-file',('"'+(Join-Path $profileRoot 'engine.log')+'"'))
    }
    $engineArgs+=@{main='res://scenes/app/main.tscn';tutorial='res://scenes/testing/TutorialMaintenanceDisplay.tscn';level01='res://scenes/testing/MegastructureWhiteboxDisplay.tscn';level02='res://scenes/testing/ParkingGarageDisplay.tscn';level02vehicles='res://scenes/testing/ParkingVehiclePreview.tscn';linked0102='res://scenes/testing/LinkedMaintenanceGarageDisplay.tscn';level06='res://scenes/testing/LinkedMaintenanceGarageDisplay.tscn';level11='res://scenes/testing/ResearchAtriumTestLab.tscn'}[$Presentation]
    if($Presentation -eq 'level06'){$engineArgs+=@('--','--train-only')}
    $windowStyle=if($Diagnostic){'Hidden'}else{'Normal'}
    $game=Start-Process -FilePath $enginePath -ArgumentList $engineArgs -WorkingDirectory $projectRoot -WindowStyle $windowStyle -PassThru
    $record.game_pid=$game.Id
    $clock=[Diagnostics.Stopwatch]::StartNew()
    $lastWrittenChanges=-1
    # The native game may acquire a higher priority after creation. Recheck the
    # exact process handle we created; never search for or alter other games.
    while(-not $game.HasExited){
        $game.Refresh()
        try{
            $before=[string]$game.PriorityClass
            if($before -ne 'BelowNormal'){
                $game.PriorityClass=[Diagnostics.ProcessPriorityClass]::BelowNormal
                if($record.changes.Count -lt 32){$record.changes+=@{elapsed_ms=$clock.ElapsedMilliseconds;from=$before;to=[string]$game.PriorityClass}}
            }
            if(-not (Test-Path -LiteralPath $statusPath) -or $record.changes.Count -ne $lastWrittenChanges){
                $record.actual_priority=[string]$game.PriorityClass
                Write-LaunchStatus
                $lastWrittenChanges=$record.changes.Count
            }
        }catch{
            if(-not $game.HasExited){throw}
        }
        if($game.WaitForExit(250)){break}
    }
    $game.WaitForExit()
    $record.exit=$game.ExitCode
    $record.elapsed_ms=$clock.ElapsedMilliseconds
    Write-LaunchStatus
}catch{
    $record.error=$_.Exception.Message
    Write-LaunchStatus
    throw
}finally{
    if($null -ne $game){$game.Dispose()}
    if($ownsMutex){$mutex.ReleaseMutex()}
    $mutex.Dispose()
}
