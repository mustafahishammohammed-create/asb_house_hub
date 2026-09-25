@echo off
title ASB House Hub - Flutter Windows
set "PATH=C:\src\flutter\bin;%PATH%"
cd /d "%~dp0"
echo ========================================================
echo   Launching ASB House Hub on Windows Desktop...
echo ========================================================
call flutter run -d windows
pause
