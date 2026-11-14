param(
 [string]$Name='release_native',
 [string]$Executable='.runtime\prologue_export_20261111\validation_build\FiveMinuteMore_Prologue.exe',
 [switch]$Headless,
 [switch]$Smoke,
 [int]$TimeoutSeconds=300
)
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if(-not [IO.Path]::IsPathRooted($Executable)){$Executable=Join-Path $projectRoot $Executable}
$out=Join-Path $projectRoot ('.runtime\prologue_export_20261111\'+$Name)
if(Test-Path -LiteralPath $out){throw 'This evidence directory already exists.'}
$lease=$null
try {
 if(-not $Headless){
  if(Get-Process -Name 'Godot*','FiveMinuteMore*' -ErrorAction SilentlyContinue){throw 'Another game or editor is active; leave it untouched.'}
  $lease=[IO.File]::Open((Join-Path $projectRoot '.runtime\visual004_roles_20261104\performance_r2\rendering_path_v1\options_research_20261105\playable.lock'),[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
 }
 $env:APPDATA=Join-Path $out 'appdata'
 $env:LOCALAPPDATA=Join-Path $out 'localappdata'
 New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
 # Prepare the feature-specific user directory before any audio device starts.
 foreach($relative in @('FiveMinuteMorePrologue','Godot\app_userdata\FiveMinuteMore Prologue',('Godot\app_userdata\Five Minutes More'+[char]0x6539+[char]0x7248))){
  $settings=Join-Path $env:APPDATA $relative
  New-Item -ItemType Directory -Force -Path $settings | Out-Null
  [IO.File]::WriteAllText((Join-Path $settings 'game_settings.cfg'),"[audio]`nmaster_volume=0`nmusic_volume=0`nsfx_volume=0`n",(New-Object Text.UTF8Encoding $false))
 }
 $audio=if($Headless){'Dummy'}else{'WASAPI'}
 $arguments=@('--audio-driver',$audio,'--resolution','1280x720')
 if($Headless){$arguments=@('--headless')+$arguments}
 if($Smoke){
  $arguments+=@('--quit-after','100')
  if(-not $Headless){$arguments+=@('--write-movie',(Join-Path $out 'entry.avi'))}
 }
 $arguments+='--'
 if(-not $Smoke){$arguments+='--prologue-validation'}
 $arguments+=@('--background-gpu',('--artifact-dir='+$out))
 $quoted=$arguments | ForEach-Object {'"'+$_.Replace('"','\"')+'"'}
 $process=Start-Process -FilePath $Executable -WorkingDirectory (Split-Path -Parent $Executable) -ArgumentList $quoted -WindowStyle Hidden -RedirectStandardOutput (Join-Path $out 'stdout.log') -RedirectStandardError (Join-Path $out 'stderr.log') -PassThru
 $null=$process.Handle
 $process.Id | Set-Content -LiteralPath (Join-Path $out 'pid.txt')
 Write-Output "Standalone validation PID $($process.Id), $out, private Master=0 + $audio"
 if(-not $process.WaitForExit($TimeoutSeconds*1000)){
  Stop-Process -Id $process.Id -Force
  'timeout' | Set-Content -LiteralPath (Join-Path $out 'exit-code.txt')
  throw 'Owned package validation timed out.'
 }
 $code=$process.ExitCode
 $code | Set-Content -LiteralPath (Join-Path $out 'exit-code.txt')
 Get-Content -LiteralPath (Join-Path $out 'stdout.log') -Tail 24
 Get-Content -LiteralPath (Join-Path $out 'stderr.log') -First 24
 exit $code
} finally {if($null -ne $lease){$lease.Dispose()}}
