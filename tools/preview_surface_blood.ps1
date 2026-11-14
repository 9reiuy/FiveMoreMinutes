param([string]$Godot='E:\Godot\Godot_v4.7.1-stable_win64.exe',[switch]$CheckOnly)
$ErrorActionPreference='Stop'
$bloodProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$bloodProfile=Join-Path $bloodProject '.runtime\surface_blood_20261113\play_profile'
if(-not(Test-Path -LiteralPath $Godot -PathType Leaf)){throw 'Godot was not found.'}
if($CheckOnly){Write-Output "Project: $bloodProject`nEntry: BloodSurfaceLab.tscn`nProfile: $bloodProfile";exit 0}
New-Item -ItemType Directory -Force -Path $bloodProfile | Out-Null
$env:APPDATA=$bloodProfile; $env:LOCALAPPDATA=$bloodProfile
Start-Process -FilePath $Godot -WorkingDirectory $bloodProject -ArgumentList @('--path',('"'+$bloodProject+'"'),'--resolution','1280x720','res://scenes/testing/BloodSurfaceLab.tscn')
