@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_performance_acceptance.ps1" %*
echo.
echo Test run finished. Review the results ZIP and raw logs.
pause
