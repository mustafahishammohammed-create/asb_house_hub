@echo off
title ASB House Hub - Flutter Windows
set "PATH=C:\src\flutter\bin;%PATH%"
set "GRPC_DNS_RESOLVER=native"
cd /d "%~dp0"
echo ========================================================
echo   Launching ASB House Hub on Windows Desktop...
call flutter run -d windows --no-enable-impeller
pause

