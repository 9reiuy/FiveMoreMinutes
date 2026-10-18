@echo off
setlocal
cd /d "%~dp0"
set "APPDATA=%~dp0.runtime\phone_settings_sample_playable\profile"
set "LOCALAPPDATA=%APPDATA%"
if not exist "%APPDATA%" mkdir "%APPDATA%"
"E:\Godot\Godot_v4.7.1-stable_win64.exe" --path "%~dp0." res://scenes/ui/preview/PhoneSettingsSample.tscn
endlocal
