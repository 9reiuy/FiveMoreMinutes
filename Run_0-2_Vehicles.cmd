@echo off
title 0-2 - Vehicle Preview
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launch_screen_wall.ps1" -Presentation level02vehicles %*
if errorlevel 1 pause
