@echo off
setlocal
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0..\.runtime\material_response_20261108\launch.ps1" %*
endlocal
