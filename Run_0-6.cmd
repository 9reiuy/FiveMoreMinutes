@echo off
title 0-6 - Train and Terminal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launch_screen_wall.ps1" -Presentation level06 %*
if errorlevel 1 pause
