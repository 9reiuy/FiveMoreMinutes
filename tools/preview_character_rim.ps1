param([string]$Godot='E:\Godot\Godot_v4.7.1-stable_win64.exe',[switch]$CheckOnly)
$ErrorActionPreference='Stop'
$rimProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$rimProfile=Join-Path $rimProject '.runtime\character_rim_20261113\play_profile'
if(-not(Test-Path -LiteralPath $Godot -PathType Leaf)){throw 'Godot was not found.'}
if($CheckOnly){Write-Output "Project: $rimProject`nEntry: CharacterRimLab.tscn`nProfile: $rimProfile";exit 0}
New-Item -ItemType Directory -Force -Path $rimProfile | Out-Null
$env:APPDATA=$rimProfile; $env:LOCALAPPDATA=$rimProfile
# This is the explicit playable entry. Automated captures use another private,
# pre-muted profile and never change this one or the player's normal settings.
Start-Process -FilePath $Godot -WorkingDirectory $rimProject -ArgumentList @('--path',('"'+$rimProject+'"'),'--resolution','1280x720','res://scenes/testing/CharacterRimLab.tscn')
