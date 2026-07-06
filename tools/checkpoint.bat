@echo off
rem OGDK - double-click panic save. Runs checkpoint.ps1 and stays open so you
rem can read the result. Safe to mash: it never force-pushes, never merges,
rem and a failed push still leaves your work committed locally.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0checkpoint.ps1"
echo.
pause
