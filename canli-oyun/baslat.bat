@echo off
chcp 65001 >nul
cd /d "%~dp0"

rem Zip olarak indirilen (kurulumsuz) Node.js'i bul: bu klasorde "node" ya da "node-v..." adli klasor
if exist "%~dp0node\node.exe" set "PATH=%~dp0node;%PATH%"
for /d %%D in ("%~dp0node-v*") do (
  if exist "%%D\node.exe" set "PATH=%%D;%PATH%"
  if exist "%%D\%%~nxD\node.exe" set "PATH=%%D\%%~nxD;%PATH%"
)

where node >nul 2>nul
if errorlevel 1 (
  echo.
  echo  Node.js bulunamadi.
  echo  - Kurulum dosyasiyla kurduysaniz bilgisayari yeniden baslatip tekrar deneyin.
  echo  - Zip olarak indirdiyseniz zip'i bu klasorun icine cikarin
  echo    ^(icinde node.exe olan "node-v..." klasoru baslat.bat ile yan yana olmali^).
  echo.
  pause
  exit /b 1
)

echo Node.js bulundu:
node -v

if not exist node_modules (
  echo.
  echo Ilk calistirma: paketler kuruluyor, 1-2 dakika surebilir...
  call npm install
  if errorlevel 1 (
    echo.
    echo Paketler kurulamadi. Internet baglantisini kontrol edip tekrar deneyin.
    pause
    exit /b 1
  )
)

echo.
echo Kontrol paneli tarayicida aciliyor. Bu pencereyi KAPATMAYIN; kapatirsaniz oyun durur.
echo.
start "" http://localhost:8080/panel
node server.js %*
pause
