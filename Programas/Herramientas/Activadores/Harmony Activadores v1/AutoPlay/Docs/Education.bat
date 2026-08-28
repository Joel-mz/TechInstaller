@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
cls
color 0A
mode con: cols=60 lines=30
echo. ********************************************************
echo                       Harmony
echo.*********************************************************
echo.*********************************************************
echo Activador Windows Education
echo.*********************************************************
echo.


echo  Instalando clave para Windows Education...
slmgr /ipk NW6C2-QMPVW-D7KKK-3GKT6-VCFB2

echo  Configurando servidor KMS ...
slmgr /skms kms.loli.best

echo  Intentando activar Windows...
slmgr /ato


color 0A
echo ✅ Windows Education activado correctamente.
echo.
echo ✅ Proceso completado, revisa el estado de activación.
echo.*********************************************************
echo ✅ La activación ha finalizado correctamente.           
echo 🔄 Desarrollado por Adrian Urbano.                   
echo.*********************************************************

for /l %%i in (7,-1,1) do (
    <nul set /p=" %%i segundos restantes... "
    timeout /t 1 >nul
    echo(

)

exit

)