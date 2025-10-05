@echo off
setlocal ENABLEEXTENSIONS

:: -----------------------------------------------------------------------------
:: init_monorepo.cmd
::
:: Initializes the D:\Dev\tooling-monorepo folder structure for plugins and tools.
::
:: Usage:
::   init_monorepo.cmd [D:\Dev\tooling-monorepo|defrepo]
::
:: Parameters:
::   [D:\Dev\tooling-monorepo|defrepo] - Optional repo root, or 'defrepo' to auto-select D: or C:.
::
:: Behavior:
::   - Creates plugin and tool folders with src subfolders.
::   - Adds README.md files for root, plugins, and tools.
::   - Handles errors for directory and file creation.
::
:: Example:
::   init_monorepo.cmd
::   init_monorepo.cmd defrepo
::   init_monorepo.cmd C:\Dev\tooling-monorepo
:: -----------------------------------------------------------------------------

:: Handle default repo if 'defrepo' is given
set "REPO=%~1"
if /I "%REPO%"=="defrepo" (
    if exist "D:\" (
        set "REPO=D:\Dev\tooling-monorepo"
    ) else (
        set "REPO=C:\Dev\tooling-monorepo"
    )
)

:: Initialize D:\Dev\tooling-monorepo folder structure
:: Usage: init_monorepo.cmd [D:\Dev\tooling-monorepo]
if "%REPO%"=="" set "REPO=D:\Dev\tooling-monorepo"

for %%D in (
  "plugins\onemore\ClipTools\src"
  "plugins\onemore\TableTools\src"
  "tools\ps\my-ps-tool\src"
  "tools\py\my-py-tool\src"
  "tools\cmd\my-cmd-tool\src"
  "tools\bash\my-bash-tool\src"
  "tools\zsh\my-zsh-tool\src"
  "shared"
  "build"
  "out\artifacts"
) do (
  if not exist "%REPO%\%%~D" (
    mkdir "%REPO%\%%~D" || (
      echo Failed to create directory: %REPO%\%%~D
      exit /b 1
    )
  )
)

> "%REPO%\README.md" (
  echo # Tooling Monorepo
  echo.
  echo Hosts OneMore plugins and standalone tools (PowerShell, Python, CMD, Bash, zsh).
) || (
  echo Failed to create README.md in %REPO%
  exit /b 1
)

> "%REPO%\plugins\onemore\ClipTools\README.md" (
  echo ClipTools plugin
) || (
  echo Failed to create README.md in plugins\onemore\ClipTools
  exit /b 1
)

> "%REPO%\plugins\onemore\TableTools\README.md" (
  echo TableTools plugin
) || (
  echo Failed to create README.md in plugins\onemore\TableTools
  exit /b 1
)

> "%REPO%\tools\ps\my-ps-tool\README.md" (
  echo PowerShell tool
) || (
  echo Failed to create README.md in tools\ps\my-ps-tool
  exit /b 1
)

> "%REPO%\tools\py\my-py-tool\README.md" (
  echo Python tool
) || (
  echo Failed to create README.md in tools\py\my-py-tool
  exit /b 1
)

echo Initialized monorepo at %REPO%
exit /b 0
