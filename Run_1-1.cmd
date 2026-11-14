@echo off
title 1-1 - Research Atrium
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launch_screen_wall.ps1" -Presentation level11 %*
if errorlevel 1 pause
