@echo off
title Forklift Impact Flicker Check
powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0.runtime\screen_flicker_20261116\run_probe.ps1" -RunName blood_mesh_preview_20261117 -Script res://tests/h06_forklift_blood_mesh_comparison.gd -Interactive
