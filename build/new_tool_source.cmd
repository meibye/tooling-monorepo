@echo off
setlocal ENABLEEXTENSIONS

:: Scaffold a new standalone tool
:: Usage: new_tool_source.cmd <RepoRoot> <Kind> <Name>
:: Kind: ps|py|cmd|bash|zsh
set "REPO=%~1"
set "KIND=%~2"
set "NAME=%~3"

if "%REPO%"=="" goto :usage
if "%KIND%"=="" goto :usage
if "%NAME%"=="" goto :usage

set "BASE=%REPO%\tools\%KIND%\%NAME%\src"
if not exist "%BASE%" mkdir "%BASE%"

if /I "%KIND%"=="ps"  ( > "%BASE%\%NAME%.ps1" echo param() && echo Write-Output "%NAME%" )
if /I "%KIND%"=="py"  ( > "%BASE%\%NAME%.py"  echo print("%NAME%") )
if /I "%KIND%"=="cmd" ( > "%BASE%\%NAME%.cmd" echo @echo off^&^&echo %%~n0 )
if /I "%KIND%"=="bash" ( > "%BASE%\%NAME%.sh"  echo #!/usr/bin/env bash^&^&echo %NAME% )
if /I "%KIND%"=="zsh" ( > "%BASE%\%NAME%.zsh"  echo #!/usr/bin/env zsh^&^&echo %NAME% )

> "%REPO%\tools\%KIND%\%NAME%\README.md" echo ## %NAME% (%KIND% tool)
echo Created %KIND% tool skeleton at %REPO%\tools\%KIND%\%NAME%
exit /b 0

:usage
echo Usage: %~nx0 ^<RepoRoot^> ^<Kind^> ^<Name^>
exit /b 2
