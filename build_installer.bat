@echo off
echo ========================================================
echo  Membangun Installer Kopi Kita POS (Windows)
echo ========================================================

echo [1/3] Menjalankan flutter build windows --release...
call flutter build windows --release
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Gagal melakukan build flutter!
    pause
    exit /b %ERRORLEVEL%
)

echo [2/3] Membungkus file dengan Inno Setup...
"%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" "%~dp0windows_installer.iss"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Gagal mengompilasi installer!
    pause
    exit /b %ERRORLEVEL%
)

echo ========================================================
echo [SELESAI] Installer siap di:
echo %~dp0installer_output\KopiKita_POS_Setup.exe
echo ========================================================
pause
