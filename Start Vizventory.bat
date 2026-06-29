@echo off
cd /d "%~dp0"
set PORT=4174
echo Starting Vizventory Local Inventory...
echo.
echo Folder: %cd%
echo Address: http://localhost:%PORT%
echo.
echo Keep this window open while using the app.
echo Open http://localhost:%PORT% in your browser.
echo.
start "" http://localhost:%PORT%
node server.js
pause
