@echo off
setlocal ENABLEEXTENSIONS

:: Deploy a built artifact into C:\Tools and set 'current'
:: Usage: deploy_to_tools.cmd <Family> <App> <Version> <ZipPath> [C:\Tools]
set "FAMILY=%~1"
set "APP=%~2"
set "VER=%~3"
set "ZIP=%~4"
set "ROOT=%~5"
if "%ROOT%"=="" set "ROOT=C:\Tools"

if "%FAMILY%"=="" goto :usage
if "%APP%"=="" goto :usage
if "%VER%"=="" goto :usage
if "%ZIP%"=="" goto :usage

set "DEST=%ROOT%\apps\%FAMILY%\%APP%\%VER%"

if not exist "%DEST%" mkdir "%DEST%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Path '%ZIP%' -DestinationPath '%DEST%' -Force" || (
  echo Expand-Archive failed
  exit /b 1
)

set "CURRENT=%ROOT%\apps\%FAMILY%\%APP%\current"
if exist "%CURRENT%" rmdir "%CURRENT%" /S /Q
mklink /D "%CURRENT%" "%DEST%" >nul
if errorlevel 1 (
  echo mklink failed. Run as Administrator or enable Developer Mode for symlinks.
  exit /b 1
)

echo Deployed %ZIP% to %DEST% and set 'current'.
exit /b 0

:usage
echo Usage: %~nx0 ^<Family^> ^<App^> ^<Version^> ^<ZipPath^> [C:\Tools]
exit /b 2
