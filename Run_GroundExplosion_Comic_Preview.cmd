@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0.runtime\explosion_ground_cartoon_20261113\launch_comic_preview.ps1" %*
if errorlevel 1 pause
