@echo off
setlocal ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

:: -----------------------------------------------------------------------------
:: dev-list-tools.cmd
::
:: Lists all developed tools in the tools folder, presenting them as columns:
:: Family | App (App column width is dynamic)
::
:: Usage:
::   dev-list-tools.cmd [<RepoRoot|defrepo>]
::
:: Parameters:
::   [RepoRoot|defrepo] - Optional root path of the repo, or 'defrepo' to auto-select D: or C:.
::
:: Example:
::   dev-list-tools.cmd
::   dev-list-tools.cmd defrepo
::   dev-list-tools.cmd D:\Dev\tooling-monorepo
:: -----------------------------------------------------------------------------

set "REPO=%~1"
if /I "%REPO%"=="defrepo" (
    if exist "D:\" (
        set "REPO=D:\Dev\tooling-monorepo"
    ) else (
        set "REPO=C:\Dev\tooling-monorepo"
    )
)
if "%REPO%"=="" set "REPO=D:\Dev\tooling-monorepo"

set "TOOLROOT=%REPO%\tools"

if not exist "%TOOLROOT%" (
    echo Tools folder not found: %TOOLROOT%
    exit /b 1
)

:: First pass: find max app name length
set "MAXLEN=3"
for /d %%F in ("%TOOLROOT%\*") do (
    for /d %%A in ("%%F\*") do (
        if exist "%%A\src" (
            set "APP=%%~nxA"
            call :strlen "%%~nxA"
            if !LEN! gtr !MAXLEN! set "MAXLEN=!LEN!"
        )
    )
)

:: Print header
set /a APPW=%MAXLEN%+2
set "FAMHDR=Family"
set "APPHDR=App"
call :pad "%FAMHDR%" 13 FAMPAD
call :pad "%APPHDR%" %APPW% APPPAD
echo   !FAMPAD! !APPPAD!
call :pad " " 13 FAMPAD
call :pad " " %APPW% APPPAD
echo   ------------- !APPPAD: =-!

:: Second pass: print rows
for /d %%F in ("%TOOLROOT%\*") do (
    set "FAMILY=%%~nxF"
    for /d %%A in ("%%F\*") do (
        if exist "%%A\src" (
            set "APP=%%~nxA"
            call :pad "!FAMILY!" 13 FAMPAD
            call :pad "!APP!" %APPW% APPPAD
            echo   !FAMPAD! !APPPAD!
        )
    )
)
exit /b 0

:strlen
setlocal
set "STR=%~1"
set LEN=0
:strlen_loop
if not "!STR:~%LEN%,1!"=="" (
    set /a LEN+=1
    goto :strlen_loop
)
endlocal & set "LEN=%LEN%"
goto :eof

:pad
setlocal
set "STR=%~1"
set "LEN=%~2"
set "OUT=%STR%"
:pad_loop
if not defined OUT set "OUT="
REM Only pad if OUT is shorter than LEN
set /a OUTLEN=0
:count_loop
if not "!OUT:~%OUTLEN%,1!"=="" (
    set /a OUTLEN+=1
    goto count_loop
)
if %OUTLEN% GEQ %LEN% goto pad_done
set "OUT=!OUT!               "
goto pad_loop
:pad_done
set "OUT=!OUT:~0,%LEN%!"
endlocal & set "%3=%OUT%"
goto :eof
