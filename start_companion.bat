@echo off
rem Dragon's Dogma 2 Trainer by RipXic - Claude companion (save backups + "Ask Claude").
rem Keep this window open while you play; close it to stop. Options: see README.md (e.g. -Game "D:\...\Dragons Dogma 2").
title DD2 Trainer - Claude companion
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0companion.ps1" %*
pause
