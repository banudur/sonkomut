@echo off
chcp 65001 >nul
title Sakli Nesne - Oyun Sunucusu
cd /d "%~dp0"

rem Python'u bul: once "py" (Windows Python baslaticisi), sonra "python"
set PY=
where py >nul 2>nul && set PY=py
if "%PY%"=="" (
    where python >nul 2>nul && set PY=python
)
if "%PY%"=="" (
    echo.
    echo [HATA] Python bulunamadi.
    echo  1. https://www.python.org/downloads/ adresinden Python 3.11 veya ustunu indirin.
    echo  2. Kurulumun ilk ekraninda "Add python.exe to PATH" kutusunu ISARETLEYIN.
    echo  3. Kurulum bitince bu dosyaya tekrar cift tiklayin.
    echo.
    pause
    exit /b 1
)

echo Python bulundu:
%PY% --version
echo.
echo Gerekli paketler kontrol ediliyor (ilk seferde birkac dakika surebilir)...
%PY% -m pip install --disable-pip-version-check -q -r requirements.txt
if errorlevel 1 (
    echo.
    echo [HATA] Paketler kurulamadi. Internet baglantinizi kontrol edin.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  Sunucu baslatiliyor. Bu pencereyi oyun boyunca ACIK birakin.
echo  Ayni bilgisayardan:  ws://127.0.0.1:8000/ws
echo  Telefondan: ws://BILGISAYARIN-IP-ADRESI:8000/ws
echo  (IP adresi icin baska bir pencerede "ipconfig" yazin, IPv4 Address satiri)
echo  Kapatmak icin: Ctrl+C
echo ============================================================
echo.
%PY% -m uvicorn app.main:app --host 0.0.0.0 --port 8000
pause
