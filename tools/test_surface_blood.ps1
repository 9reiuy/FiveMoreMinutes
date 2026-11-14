param([string]$Tag='validation',[string]$Script='res://scripts/testing/validate_surface_blood.gd',[switch]$CheckOnly)
$ErrorActionPreference='Stop'
function Initialize-SurfaceBloodQuietProfile {
    param([string]$Project,[string]$TestAppData)
    $settings=Get-Content -LiteralPath (Join-Path $Project 'project.godot') -Raw -Encoding UTF8
    $custom=$settings -match '(?m)^config/use_custom_user_dir=true\s*$'
    $key=if($custom){'config/custom_user_dir_name'}else{'config/name'}
    $directory=[regex]::Match($settings,'(?m)^'+$key+'="([^"\\/:]+)"\s*$')
    if(-not $directory.Success -or $directory.Groups[1].Value -in '.', '..'){throw 'Cannot resolve the private Godot user directory.'}
    $parent=if($custom){$TestAppData}else{Join-Path $TestAppData 'Godot/app_userdata'}
    $bloodPrivatePath=Join-Path $parent $directory.Groups[1].Value
    New-Item -ItemType Directory -Force -Path $bloodPrivatePath | Out-Null
    # Applied before SFX starts; native audio processing stays enabled.
    Set-Content -LiteralPath (Join-Path $bloodPrivatePath 'game_settings.cfg') -Value @('[audio]','master_volume=0') -Encoding ascii
}
$bloodProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$bloodOut=Join-Path $bloodProject '.runtime\surface_blood_20261113'
$bloodProfile=Join-Path $bloodOut 'profile'
New-Item -ItemType Directory -Force -Path $bloodOut | Out-Null
$env:APPDATA=$bloodProfile; $env:LOCALAPPDATA=$bloodProfile
Initialize-SurfaceBloodQuietProfile -Project $bloodProject -TestAppData $bloodProfile | Out-Null
if($CheckOnly){Write-Output "Private muted profile ready: $bloodProfile";exit 0}
$bloodRun=Start-Process -FilePath 'E:\Godot\Godot_v4.7.1-stable_win64.exe' -WorkingDirectory $bloodProject -ArgumentList @('--path',$bloodProject,'--resolution','640x360','--position','-3000,-3000','--script',$Script) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $bloodOut ($Tag+'.log')) -RedirectStandardError (Join-Path $bloodOut ($Tag+'.stderr.log'))
@{pid=$bloodRun.Id;entry=$Script;started=(Get-Date).ToString('o');profile=$bloodProfile;audio='private master muted; native audio driver'} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $bloodOut ($Tag+'.process.json'))
$bloodHandle=$bloodRun.Handle
$bloodRun.WaitForExit()
$bloodRun.Refresh()
if($null -eq $bloodRun.ExitCode){throw 'Godot exit status was unavailable; this run cannot be accepted.'}
@{pid=$bloodRun.Id;exit_code=$bloodRun.ExitCode;finished=(Get-Date).ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $bloodOut ($Tag+'.result.json'))
Write-Output "PID=$($bloodRun.Id) Exit=$($bloodRun.ExitCode)"
Get-Content -LiteralPath (Join-Path $bloodOut ($Tag+'.stderr.log')) -Tail 20
Get-Content -LiteralPath (Join-Path $bloodOut ($Tag+'.log')) -Tail 6
exit $bloodRun.ExitCode
