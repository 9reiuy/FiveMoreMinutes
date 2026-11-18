@echo off
title Chapter 1 - H06 Whitebox
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launch_screen_wall.ps1" -Presentation h06chapter %*
if errorlevel 1 pause
