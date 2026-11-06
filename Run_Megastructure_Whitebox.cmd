@echo off
title Megastructure Whitebox (Forward+ Renderer)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\run_megastructure_whitebox.ps1"
if errorlevel 1 pause
