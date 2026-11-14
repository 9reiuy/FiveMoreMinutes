@echo off
title 0-1 to Lower Harbor - Linked Levels
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launch_screen_wall.ps1" -Presentation linked0102 %*
if errorlevel 1 pause
