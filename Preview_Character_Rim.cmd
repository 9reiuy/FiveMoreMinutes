@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\preview_character_rim.ps1"
if errorlevel 1 pause
