@echo off
setlocal ENABLEEXTENSIONS

:: Flip 'current' to a specific version
:: Usage: promote_app.cmd <Family> <App> <ToVersion> [C:\Tools]
set "FAMILY=%~1"
set "APP=%~2"
set "VER=%~3"
set "ROOT=%~4"
if "%ROOT%"=="" set "ROOT=C:\Tools"

if "%FAMILY%"=="" goto :usage
if "%APP%"=="" goto :usage
if "%VER%"=="" goto :usage

set "BASE=%ROOT%\apps\%FAMILY%\%APP%"
set "TARGET=%BASE%\%VER%"
set "CURRENT=%BASE%\current"

if not exist "%TARGET%" (
  echo Version path not found: %TARGET%
  exit /b 1
)

if exist "%CURRENT%" rmdir "%CURRENT%" /S /Q
mklink /D "%CURRENT%" "%TARGET%" >nul
if errorlevel 1 (
  echo mklink failed. Run as Administrator or enable Developer Mode for symlinks.
  exit /b 1
)

echo Promoted %FAMILY%\%APP% -> %VER%
exit /b 0

:usage
echo Usage: %~nx0 ^<Family^> ^<App^> ^<ToVersion^> [C:\Tools]
exit /b 2
