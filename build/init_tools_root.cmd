@echo off
setlocal ENABLEEXTENSIONS

:: -----------------------------------------------------------------------------
:: init_tools_root.cmd
::
:: Initializes C:\Tools base directories for various tool families.
::
:: Usage:
::   init_tools_root.cmd [C:\Tools]
::
:: Parameters:
::   [C:\Tools]  - Optional root path for tools (default: C:\Tools)
::
:: Behavior:
::   - Creates apps\onemore, apps\ps, apps\py, apps\bash, apps\zsh, apps\cmd under the root.
::   - Handles errors for directory creation.
::
:: Example:
::   init_tools_root.cmd
::   init_tools_root.cmd D:\Tools
:: -----------------------------------------------------------------------------

set "ROOT=%~1"
if "%ROOT%"=="" set "ROOT=C:\Tools"

for %%D in (
  "apps\onemore"
  "apps\ps"
  "apps\py"
  "apps\bash"
  "apps\zsh"
  "apps\cmd"
) do (
  if not exist "%ROOT%\%%~D" (
    mkdir "%ROOT%\%%~D" || (
      echo Failed to create directory: %ROOT%\%%~D
      exit /b 1
    )
  )
)

echo Initialized %ROOT% structure.
exit /b 0
