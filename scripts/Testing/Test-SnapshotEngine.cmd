@echo off
title romanOS - Test Suite: Snapshot and Rollback Engine
cd /d "%~dp0"
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "Test-SnapshotEngine.ps1" %*
