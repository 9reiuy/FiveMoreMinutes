@echo off
title H06 Boss Attack Test
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launch_screen_wall.ps1" -Presentation h06boss %*
if errorlevel 1 pause
