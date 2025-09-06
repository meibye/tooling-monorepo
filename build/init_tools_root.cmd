@echo off
setlocal ENABLEEXTENSIONS

:: Initialize C:\Tools base directories
:: Usage: init_tools_root.cmd [C:\Tools]
set "ROOT=%~1"
if "%ROOT%"=="" set "ROOT=C:\Tools"

for %%D in (
  "apps\onemore"
  "apps\ps-tools"
  "apps\py-tools"
  "apps\bash-tools"
  "apps\zsh-tools"
  "apps\cmd-tools"
) do (
  if not exist "%ROOT%\%%~D" mkdir "%ROOT%\%%~D"
)

echo Initialized %ROOT% structure.
exit /b 0
