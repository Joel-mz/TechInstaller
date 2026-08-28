@echo off
%~d0
CD %~dp0
mode con: cols=43 lines=25
echo. ***************************************
echo                  Harmony 
echo.****************************************
echo.****************************************
echo Instalando Psiphon... 

copy "Psiphon.exe" "%USERPROFILE%\Desktop\Psiphon.exe"
echo.
echo Operacion Completa
echo.****************************************
echo Esta ventana se cerrara en:
set /a contador=3
:conteo
echo %contador%
set /a contador-=1
timeout /t 1 >nul
if %contador% gtr 0 goto conteo
exit