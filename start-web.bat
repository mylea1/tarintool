@echo off
cd /d "%~dp0"
node scripts\agent-launcher.mjs %*
if errorlevel 1 pause
