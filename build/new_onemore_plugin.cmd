@echo off
setlocal ENABLEEXTENSIONS

:: Scaffold a new OneMore plugin source tree
:: Usage: new_onemore_plugin.cmd <RepoRoot> <PluginName>
set "REPO=%~1"
set "NAME=%~2"

if "%REPO%"=="" goto :usage
if "%NAME%"=="" goto :usage

set "ROOT=%REPO%\plugins\onemore\%NAME%"
if not exist "%ROOT%\src" mkdir "%ROOT%\src"

> "%ROOT%\README.md" echo ## %NAME% (OneMore plugin)
> "%ROOT%\src\example.ps1" echo param() && echo Write-Output "Hello from %NAME%"

echo Created OneMore plugin skeleton at %ROOT%
exit /b 0

:usage
echo Usage: %~nx0 ^<RepoRoot^> ^<PluginName^>
exit /b 2
