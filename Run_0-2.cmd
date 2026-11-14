@echo off
title 0-2 - Parking Garage
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launch_screen_wall.ps1" -Presentation level02 %*
if errorlevel 1 pause
