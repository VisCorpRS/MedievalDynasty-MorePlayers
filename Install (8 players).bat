@echo off
title Medieval Dynasty - More Players
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0MorePlayers.ps1" -Players 8 -Pause
