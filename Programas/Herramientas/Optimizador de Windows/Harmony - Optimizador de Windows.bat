@echo off
title Harmony - Optimizador de Windows
color 1F

:: Verificar permisos de administrador
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ---------------------------------------------------------
    echo     Por favor, ejecuta Harmony como administrador
    echo ---------------------------------------------------------
    pause
    exit /b
)

cls
echo =============================================================
echo                 Harmony - Optimizador de Windows
echo =============================================================
echo       Este proceso mejorara el rendimiento del sistema.
echo       Por favor, espera mientras se realiza la limpieza.
echo =============================================================
timeout /t 3 >nul

:: Limpiar archivos temporales
echo.
echo [1/6] Limpiando archivos temporales...
del /s /f /q %temp%\*.* >nul 2>&1
del /s /f /q C:\Windows\Temp\*.* >nul 2>&1
echo Archivos temporales eliminados.
timeout /t 1 >nul

:: Vaciar papelera de reciclaje
echo.
echo [2/6] Vaciando papelera de reciclaje...
PowerShell -Command "Clear-RecycleBin -Force" >nul 2>&1
echo Papelera vaciada.
timeout /t 1 >nul

:: Liberador de espacio en disco
echo.
echo [3/6] Ejecutando liberador de espacio en disco...
cleanmgr /sagerun:1
timeout /t 2 >nul

:: Comprobar y reparar archivos del sistema
echo.
echo [4/6] Verificando integridad del sistema (SFC)...
sfc /scannow
timeout /t 2 >nul

:: Verificar tipo de unidad (SSD o HDD) y desfragmentar solo si es HDD
echo.
echo [5/6] Detectando tipo de unidad...

for /f "tokens=*" %%a in ('PowerShell -Command "Get-PhysicalDisk | Where-Object { $_.DeviceID -eq 0 } | Select-Object MediaType"') do (
    echo %%a | find /i "HDD" >nul
    if not errorlevel 1 (
        echo Unidad HDD detectada. Ejecutando desfragmentacion...
        defrag C: /U /V
    ) else (
        echo Unidad SSD detectada. Saltando desfragmentacion.
    )
)

timeout /t 2 >nul

:: CHKDSK (opcional - puede requerir reinicio)
echo.
echo [6/6] Analizando disco en busca de errores...
chkdsk C: /f
echo Análisis completo.
timeout /t 1 >nul

echo.
echo =============================================================
echo 		Se ha terminado de optimizar el sistema
echo =============================================================
echo     Es recomendable reiniciar el equipo para aplicar todo.
echo.
pause
exit
