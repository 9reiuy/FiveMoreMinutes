@echo off
setlocal
cd /d "%~dp0.."
set "APPDATA=%CD%\.runtime\screen_wall_play\appdata"
set "LOCALAPPDATA=%CD%\.runtime\screen_wall_play\localappdata"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"
start "Screen wall preview" "E:\Godot\Godot_v4.7.1-stable_win64.exe" --path "%CD%" --rendering-method gl_compatibility --windowed --resolution 1280x720 res://scenes/preview/screen_wall_review.tscn
endlocal
