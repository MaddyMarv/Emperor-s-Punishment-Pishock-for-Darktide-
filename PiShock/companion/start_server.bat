@echo off
title PiShock Darktide Companion Server
echo Starting PiShock Companion Server...
echo Installing required modules...
pip install flask websocket-client requests
echo.
python server.py
pause
