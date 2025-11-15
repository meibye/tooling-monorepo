@echo off
setlocal ENABLEEXTENSIONS

:: -----------------------------------------------------------------------------
:: dev-new-plugin.cmd
::
:: Scaffolds a new OneMore plugin source tree.
::
:: Usage:
::   dev-new-plugin.cmd <RepoRoot|defrepo> <PluginName>
::
:: Parameters:
::   RepoRoot    - Root path of the repo, or 'defrepo' to auto-select D: or C:.
::   PluginName  - Name of the new plugin.
::
:: Behavior:
::   - Creates plugins\onemore\<PluginName>\src directory structure.
::   - Adds a README.md in the plugin root folder.
::   - Adds a <PluginName>.ps1 PowerShell script in the src folder.
::   - Handles errors for directory and file creation.
::   - Prevents overwriting existing files.
::
:: Example:
::   dev-new-plugin.cmd defrepo myplugin
::   dev-new-plugin.cmd D:\Dev\tooling-monorepo testplugin
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
    mkdir "%SRC%" || (echo Failed to create directory: %SRC% & exit /b 1)
)

:: Checks if README.md exists in the specified %ROOT% directory.
if exist "%ROOT%\README.md" (
    echo README.md already exists in %ROOT%
    exit /b 1
) else (
    > "%ROOT%\README.md" echo ## %NAME% (OneMore plugin^)
    echo Created README.md in %ROOT%
)

:: Create %NAME%.ps1 in the src folder.
if exist "%SRC%\%NAME%.ps1" (
    echo %NAME%.ps1 already exists in %SRC%
    exit /b 1
) else (
    > "%SRC%\%NAME%.ps1" (
        echo param(^)
        echo Write-Output "Hello from %NAME%"
    ) || (
        echo Failed to create %NAME%.ps1 in %SRC%
        exit /b 1
    )
    echo Created %NAME%.ps1 in %SRC%
)   

echo Created OneMore plugin skeleton at %ROOT%
exit /b 0

:usage
echo Usage: %~nx0 ^<RepoRoot^|defrepo^> ^<PluginName^>
exit /b 2
