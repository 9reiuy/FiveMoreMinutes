@echo off
title 1-1 - Chronon Research Unit Atrium Loop
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launch_atrium_loop_1_1.ps1" %*
if errorlevel 1 pause
