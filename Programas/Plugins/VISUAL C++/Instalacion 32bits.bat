@echo off
%~d0
CD %~dp0
mode con: cols=47 lines=25
echo. ***************************************
echo                  Harmony 
echo.****************************************
echo Instalando Visual C++ Todas las versiones... 
echo.****************************************
echo Instalando Visual C++ 2005...
start /wait vcredist2005_x86.exe /q
echo.
echo Instalando Visual C++ 2008...
start /wait vcredist2008_x86.exe /qb
echo.
echo Instalando Visual C++ 2010...
start /wait vcredist2010_x86.exe /passive /norestart
echo.
echo Instalando Visual C++ 2012...
start /wait vcredist2012_x86.exe /passive /norestart
echo.
echo Instalando Visual C++ 2013...
start /wait vcredist2013_x86.exe /passive /norestart
echo.
echo Instalando Visual C++ 2015, 2017, 2019 ^& 2022...
start /wait vcredist2015_2017_2019_2022_x86.exe /passive /norestart
echo.
echo Instalacion Completa
echo.****************************************
echo Esta ventana se cerrara en:
set /a contador=3
:conteo
echo %contador%
set /a contador-=1
timeout /t 1 >nul
if %contador% gtr 0 goto conteo
exit