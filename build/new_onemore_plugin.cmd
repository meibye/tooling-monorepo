@echo off
setlocal ENABLEEXTENSIONS

:: -----------------------------------------------------------------------------
:: new_onemore_plugin.cmd
::
:: Scaffolds a new OneMore plugin source tree.
::
:: Usage:
::   new_onemore_plugin.cmd <RepoRoot|defrepo> <PluginName>
::
:: Parameters:
::   RepoRoot    - Root path of the repo, or 'defrepo' to auto-select D: or C:.
::   PluginName  - Name of the new plugin.
::
:: Behavior:
::   - Creates plugins\onemore\<PluginName>\src structure.
::   - Adds a README.md and example.ps1 in the src folder.
::   - Handles errors for directory and file creation.
::
:: Example:
::   new_onemore_plugin.cmd defrepo myplugin
::   new_onemore_plugin.cmd D:\Dev\tooling-monorepo testplugin
:: -----------------------------------------------------------------------------

set "REPO=%~1"
set "NAME=%~2"

:: Handle default repo if 'defrepo' is given
if /I "%REPO%"=="defrepo" (
    if exist "D:\" (
        set "REPO=D:\Dev\tooling-monorepo"
    ) else (
        set "REPO=C:\Dev\tooling-monorepo"
    )
)

if "%REPO%"=="" goto :usage
if "%NAME%"=="" goto :usage

set "ROOT=%REPO%\plugins\onemore\%NAME%"
set "SRC=%ROOT%\src"

if not exist "%SRC%" (
    mkdir "%SRC%" || (
        echo Failed to create directory: %SRC%
        exit /b 1
    )
)

> "%ROOT%\README.md" (
    echo ## %NAME% (OneMore plugin)
) || (
    echo Failed to create README.md in %ROOT%
    exit /b 1
)

> "%SRC%\example.ps1" (
    echo param()
    echo Write-Output "Hello from %NAME%"
) || (
    echo Failed to create example.ps1 in %SRC%
    exit /b 1
)

echo Created OneMore plugin skeleton at %ROOT%
exit /b 0

:usage
echo Usage: %~nx0 ^<RepoRoot^|defrepo^> ^<PluginName^>
exit /b 2
