@echo off
title Medieval Dynasty - More Players
set /p N=How many players (2-64)? 
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0MorePlayers.ps1" -Players %N% -Pause
