param(
 [switch]$Validation,
 [string]$OutputDirectory='',
 [string]$Godot='E:\Godot\Godot_v4.7.1-stable_win64.exe',
 [string]$Template='C:\Users\Administrator\AppData\Roaming\Godot\export_templates\4.7.1.stable\windows_release_x86_64.exe'
)
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$taskRoot=Join-Path $projectRoot '.runtime\prologue_export_20261111'
if(-not $OutputDirectory){$OutputDirectory=Join-Path $projectRoot $(if($Validation){'.runtime\prologue_export_20261111\validation_build'}else{'build\Prologue_0-1_0-6_Windows'})}
$OutputDirectory=[IO.Path]::GetFullPath($OutputDirectory)
if(-not(Test-Path -LiteralPath $Godot -PathType Leaf)){throw 'The configured Godot editor was not found.'}
if(-not(Test-Path -LiteralPath $Template -PathType Leaf)){throw 'The matching Windows release template was not found.'}
New-Item -ItemType Directory -Force -Path $taskRoot,$OutputDirectory | Out-Null
$env:APPDATA=Join-Path $taskRoot 'build_appdata'
$env:LOCALAPPDATA=Join-Path $taskRoot 'build_localappdata'
$env:TMP=Join-Path $taskRoot 'build_temp'
$env:TEMP=$env:TMP
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA,$env:TMP | Out-Null
$settings=Join-Path $env:APPDATA ('Godot\app_userdata\Five Minutes More'+[char]0x6539+[char]0x7248)
New-Item -ItemType Directory -Force -Path $settings | Out-Null
[IO.File]::WriteAllText((Join-Path $settings 'game_settings.cfg'),"[audio]`nmaster_volume=0`nmusic_volume=0`nsfx_volume=0`n",(New-Object Text.UTF8Encoding $false))
function Invoke-ExportStep([string]$Step,[string[]]$Arguments){
 $log=Join-Path $taskRoot ($Step+'.stdout.log')
 $errors=Join-Path $taskRoot ($Step+'.stderr.log')
 $process=Start-Process -FilePath $Godot -ArgumentList $Arguments -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError $errors -PassThru
 $null=$process.Handle
 $process.Id | Set-Content -LiteralPath (Join-Path $taskRoot ($Step+'.pid.txt'))
 Write-Output "$Step PID $($process.Id)"
 if(-not $process.WaitForExit(300000)){Stop-Process -Id $process.Id -Force;throw "$Step timed out"}
 $process.ExitCode | Set-Content -LiteralPath (Join-Path $taskRoot ($Step+'.exit-code.txt'))
 Get-Content -LiteralPath $log -Tail 8
 if($process.ExitCode -ne 0){Get-Content -LiteralPath $errors -Tail 20;throw "$Step failed: $($process.ExitCode)"}
}
Invoke-ExportStep 'resources' @('--headless','--path',$projectRoot,'--audio-driver','Dummy','--script','res://tools/prologue_resources.gd')
$configuration=@((Join-Path $projectRoot 'tools\configure_prologue_export.py'),'--template',$Template)
if($Validation){$configuration+='--validation'}
& python @configuration
if($LASTEXITCODE -ne 0){throw 'Could not configure the standalone export.'}
$name=if($Validation){'export_validation'}else{'export_release'}
Invoke-ExportStep $name @('--headless','--path',$projectRoot,'--audio-driver','Dummy','--export-release','PrologueWindows',(Join-Path $OutputDirectory 'FiveMinuteMore_Prologue.exe'))
& python (Join-Path $projectRoot 'tools\verify_prologue_pack.py') (Join-Path $OutputDirectory 'FiveMinuteMore_Prologue.pck')
if($LASTEXITCODE -ne 0){throw 'The exported resource archive did not pass its integrity check.'}
Get-ChildItem -LiteralPath $OutputDirectory | Select-Object Name,Length
