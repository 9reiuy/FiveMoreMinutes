@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\run_test_lab.ps1"
if errorlevel 1 pause
