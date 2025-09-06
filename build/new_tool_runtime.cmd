@echo off
setlocal ENABLEEXTENSIONS

:: Create Family\App\Version under C:\Tools and set 'current' symlink
:: Usage: new_tool_runtime.cmd <Family> <App> <Version> [C:\Tools]
:: Family: onemore|ps-tools|py-tools|bash-tools|zsh-tools|cmd-tools
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

if not exist "%TARGET%" mkdir "%TARGET%"
if /I "%FAMILY%"=="onemore" (
  if not exist "%TARGET%\plugins" mkdir "%TARGET%\plugins"
)

if exist "%CURRENT%" rmdir "%CURRENT%" /S /Q
mklink /D "%CURRENT%" "%TARGET%" >nul
if errorlevel 1 (
  echo mklink failed. Run as Administrator or enable Developer Mode for symlinks.
  exit /b 1
)

echo Created %TARGET% and set 'current' -> %VER%
exit /b 0

:usage
echo Usage: %~nx0 ^<Family^> ^<App^> ^<Version^> [C:\Tools]
exit /b 2
