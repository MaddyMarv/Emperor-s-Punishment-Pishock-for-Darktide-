@echo off
title PiShock Darktide Companion Server
echo Starting PiShock Companion Server...
echo Installing required modules...

where py >nul 2>nul
if %errorlevel% equ 0 (
    py -m pip install websocket-client requests
    echo.
    py server.py
) else (
    pip install websocket-client requests
    echo.
    python server.py
)
pause
