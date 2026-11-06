@echo off
chcp 65001 >nul
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
  echo Node.js bulunamadi. https://nodejs.org adresinden LTS surumunu kurun, sonra tekrar deneyin.
  pause
  exit /b 1
)
if not exist node_modules (
  echo Paketler kuruluyor, biraz bekleyin...
  call npm install
)
start "" http://localhost:8080/panel
node server.js %*
pause
