@echo off
title Tutorial - Maintenance Training
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0tools\run_tutorial.ps1" %*
if errorlevel 1 pause
