@echo off
setlocal ENABLEEXTENSIONS

:: Initialize D:\Dev\tooling-monorepo folder structure
:: Usage: init_monorepo.cmd [D:\Dev\tooling-monorepo]
set "REPO=%~1"
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
  if not exist "%REPO%\%%~D" mkdir "%REPO%\%%~D"
)

> "%REPO%\README.md" echo # Tooling Monorepo&& echo.>>"%REPO%\README.md" && echo Hosts OneMore plugins and standalone tools (PowerShell, Python, CMD, Bash, zsh).>>"%REPO%\README.md"
> "%REPO%\plugins\onemore\ClipTools\README.md" echo ClipTools plugin
> "%REPO%\plugins\onemore\TableTools\README.md" echo TableTools plugin
> "%REPO%\tools\ps\my-ps-tool\README.md" echo PowerShell tool
> "%REPO%\tools\py\my-py-tool\README.md" echo Python tool

echo Initialized monorepo at %REPO%
exit /b 0
