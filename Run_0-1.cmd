@echo off
title 0-1 - Standalone Level
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\run_megastructure_whitebox.ps1" %*
if errorlevel 1 pause
