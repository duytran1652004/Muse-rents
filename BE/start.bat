@echo off
title MUSE Rents Backend Server
echo ========================================
echo   MUSE RENTS - Backend Server
echo   Local: http://localhost:3001
echo ========================================
echo.
echo Freeing port 3001...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":3001 "') do (
    taskkill /PID %%a /F >nul 2>&1
)
timeout /t 1 /nobreak >nul
echo Starting server...
echo.
npm run dev
pause
