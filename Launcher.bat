@echo off
setlocal EnableExtensions

REM ============================================
REM SebitAssistan - Launcher
REM ============================================

REM Obtener el directorio donde se encuentra el .bat
set "SCRIPT_DIR=%~dp0"
set "MAIN_PS1=%SCRIPT_DIR%Main.ps1"

REM Comprobar que Main.ps1 existe
if not exist "%MAIN_PS1%" (
    echo ERROR: No se encontro Main.ps1 en "%SCRIPT_DIR%"
    echo.
    pause
    exit /b 1
)

REM --- Comprobar privilegios administrativos ---
REM fltmc requiere elevacion real; es fiable incluso en administradores no elevados (UAC).
fltmc >nul 2>&1
if errorlevel 1 (
    echo Solicitando permisos administrativos...
    REM Pasar la ruta del .bat por variable de entorno para evitar problemas de comillas
    set "SEBIT_BAT=%~f0"
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath $env:SEBIT_BAT -Verb RunAs"
    if errorlevel 1 (
        echo.
        echo ERROR: No se pudieron obtener permisos administrativos.
        echo.
        pause
    )
    exit /b
)

REM --- Ejecutar Main.ps1 con politica de ejecucion solo para este proceso ---
powershell -NoProfile -ExecutionPolicy Bypass -File "%MAIN_PS1%"

REM Mantener la consola abierta si hay error
if errorlevel 1 (
    echo.
    echo ERROR: La aplicacion finalizo con errores. Codigo: %errorlevel%
    echo.
    pause
)

endlocal
