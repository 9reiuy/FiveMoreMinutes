@echo off
setlocal
set "APPDATA=%~dp0..\.runtime\terminal_menu_review\appdata"
set "LOCALAPPDATA=%~dp0..\.runtime\terminal_menu_review\localappdata"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"
if exist "E:\Godot\Godot_v4.7.1-stable_win64.exe" (
  start "" "E:\Godot\Godot_v4.7.1-stable_win64.exe" --path "%~dp0.." res://scenes/preview/terminal_menu_review.tscn
) else (
  echo Godot executable was not found at E:\Godot\Godot_v4.7.1-stable_win64.exe
  pause
)
